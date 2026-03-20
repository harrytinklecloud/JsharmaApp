import AppKit
import AVFoundation
import Combine
import CoreAudio
import Foundation

private enum RefreshPolicy {
    static let environmentInterval: TimeInterval = 180
    static let weatherInterval: TimeInterval = 900
    static let deviceInterval: TimeInterval = 180
    static let privacyInterval: TimeInterval = 2
}

struct CalendarEventSummary: Identifiable {
    let id = UUID()
    let title: String
    let timeText: String
    let location: String?
}

struct WeatherSnapshot {
    var location: String
    var temperature: String
    var description: String
    var alertText: String?

    static let placeholder = WeatherSnapshot(
        location: "Weather",
        temperature: "--",
        description: "Loading local conditions",
        alertText: nil
    )
}

struct PrivacyState {
    var cameraActive = false
    var microphoneActive = false
}

struct DeviceStatus: Identifiable {
    let id = UUID()
    let name: String
    let symbolName: String
    let isConnected: Bool
    let batteryPercent: Int?
}

struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let addedAt: Date

    var fileName: String { url.lastPathComponent }
    var symbolName: String {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "heic", "gif": "photo"
        case "pdf": "doc.richtext"
        case "zip": "archivebox"
        case "mp3", "wav", "m4a": "music.note"
        case "mov", "mp4": "film"
        default: "doc"
        }
    }
}

@MainActor
final class CalendarMonitor: ObservableObject {
    @Published private(set) var upcomingEvents: [CalendarEventSummary] = []
    private var lastRefresh = Date.distantPast

    func refresh(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastRefresh) >= RefreshPolicy.environmentInterval else { return }
        lastRefresh = Date()
        let script = """
        set outputText to ""
        tell application "Calendar"
            set nowDate to (current date)
            set laterDate to nowDate + (12 * hours)
            set eventList to {}
            repeat with cal in calendars
                try
                    set eventList to eventList & (every event of cal whose start date ≥ nowDate and start date ≤ laterDate)
                end try
            end repeat
            set sortedEvents to my sortEvents(eventList)
            repeat with idx from 1 to count of sortedEvents
                if idx > 3 then exit repeat
                set currentEvent to item idx of sortedEvents
                set eventTitle to summary of currentEvent
                set eventTime to time string of (start date of currentEvent)
                set eventLocation to ""
                try
                    set eventLocation to location of currentEvent
                end try
                set outputText to outputText & eventTitle & "||" & eventTime & "||" & eventLocation & linefeed
            end repeat
        end tell

        on sortEvents(theEvents)
            tell application "Calendar"
                set sortedEvents to theEvents
                repeat with i from 1 to (count of sortedEvents)
                    repeat with j from i + 1 to (count of sortedEvents)
                        if start date of item j of sortedEvents < start date of item i of sortedEvents then
                            set tempEvent to item i of sortedEvents
                            set item i of sortedEvents to item j of sortedEvents
                            set item j of sortedEvents to tempEvent
                        end if
                    end repeat
                end repeat
                return sortedEvents
            end tell
        end sortEvents

        return outputText
        """

        Task.detached(priority: .utility) { [script] in
            let rows = runAppleScript(script)
                .split(separator: "\n")
                .map { $0.split(separator: "||", omittingEmptySubsequences: false).map(String.init) }
                .filter { $0.count >= 2 }

            let events = rows.map {
                CalendarEventSummary(
                    title: $0[0].isEmpty ? "Untitled Event" : $0[0],
                    timeText: $0[1].isEmpty ? "Soon" : $0[1],
                    location: $0.count > 2 && !$0[2].isEmpty ? $0[2] : nil
                )
            }

            await MainActor.run {
                self.upcomingEvents = events
            }
        }
    }
}

@MainActor
final class WeatherMonitor: ObservableObject {
    @Published private(set) var snapshot: WeatherSnapshot = .placeholder
    private var lastRefresh = Date.distantPast

    func refresh(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastRefresh) >= RefreshPolicy.weatherInterval else { return }
        lastRefresh = Date()
        guard let url = URL(string: "https://wttr.in/?format=j1") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }

            let current = (json["current_condition"] as? [[String: Any]])?.first
            let nearestArea = (json["nearest_area"] as? [[String: Any]])?.first
            let weather = (json["weather"] as? [[String: Any]])?.first
            let location = ((nearestArea?["areaName"] as? [[String: String]])?.first?["value"]) ?? "Local Weather"
            let tempF = current?["temp_F"] as? String ?? "--"
            let description = ((current?["weatherDesc"] as? [[String: String]])?.first?["value"]) ?? "Unavailable"
            let rainChance = ((weather?["hourly"] as? [[String: Any]])?.first?["chanceofrain"] as? String) ?? "0"
            let rainPercent = Int(rainChance) ?? 0
            let alertText: String?
            if rainPercent >= 70 {
                alertText = "Rain likely today"
            } else if description.localizedCaseInsensitiveContains("thunder")
                || description.localizedCaseInsensitiveContains("snow")
                || description.localizedCaseInsensitiveContains("storm") {
                alertText = description
            } else {
                alertText = nil
            }

            Task { @MainActor [weak self] in
                self?.snapshot = WeatherSnapshot(
                    location: location,
                    temperature: "\(tempF)°F",
                    description: description,
                    alertText: alertText
                )
            }
        }.resume()
    }
}

@MainActor
final class PrivacyMonitor: ObservableObject {
    @Published private(set) var state = PrivacyState()
    private var lastRefresh = Date.distantPast

    func refresh(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastRefresh) >= RefreshPolicy.privacyInterval else { return }
        lastRefresh = Date()

        Task.detached(priority: .utility) {
            let cameraActive = processExists(named: "VDCAssistant") || processExists(named: "AppleCameraAssistant")
            let microphoneActive = inputDeviceRunning()
            await MainActor.run {
                self.state = PrivacyState(cameraActive: cameraActive, microphoneActive: microphoneActive)
            }
        }
    }
}

@MainActor
final class DeviceStatusMonitor: ObservableObject {
    @Published private(set) var devices: [DeviceStatus] = []
    private var lastRefresh = Date.distantPast

    func refresh(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastRefresh) >= RefreshPolicy.deviceInterval else { return }
        lastRefresh = Date()

        Task.detached(priority: .utility) {
            let bluetoothJSON = runCommand(path: "/usr/sbin/system_profiler", args: ["SPBluetoothDataType", "-json"])
            let batteryText = runCommand(path: "/usr/bin/pmset", args: ["-g", "batt"])
            var results: [DeviceStatus] = []

            if
                let bluetoothJSON,
                let data = bluetoothJSON.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let bluetoothData = object["SPBluetoothDataType"] as? [[String: Any]]
            {
                for section in bluetoothData {
                    section.forEach { key, value in
                        guard let info = value as? [String: Any] else { return }
                        let connected = (info["device_connected"] as? String) == "attrib_Yes"
                        guard connected else { return }
                        let batteryPercent = parseBattery(from: info)
                        let symbol = symbolName(for: key)
                        results.append(DeviceStatus(name: key, symbolName: symbol, isConnected: true, batteryPercent: batteryPercent))
                    }
                }
            }

            if let batteryText, let macBattery = parseMacBattery(from: batteryText) {
                results.insert(DeviceStatus(name: "This Mac", symbolName: "laptopcomputer", isConnected: true, batteryPercent: macBattery), at: 0)
            }

            await MainActor.run {
                self.devices = results
            }
        }
    }
}

private func processExists(named name: String) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    process.arguments = ["-x", name]
    return (try? runProcess(process))?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
}

private func inputDeviceRunning() -> Bool {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    let defaultStatus = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
    guard defaultStatus == noErr else { return false }

    var running = UInt32(0)
    var runningSize = UInt32(MemoryLayout<UInt32>.size)
    address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    let runningStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &runningSize, &running)
    return runningStatus == noErr && running != 0
}

private func parseBattery(from info: [String: Any]) -> Int? {
    let keys = ["device_batteryLevelMain", "device_batteryPercent", "device_batteryLevelLeft", "device_batteryLevelRight"]
    for key in keys {
        if let raw = info[key] as? String {
            let digits = raw.filter(\.isNumber)
            if let value = Int(digits) {
                return value
            }
        }
    }
    return nil
}

private func parseMacBattery(from text: String) -> Int? {
    let digits = text.split(separator: "%").first?.split(whereSeparator: { !$0.isNumber }).last
    return digits.flatMap { Int($0) }
}

private func symbolName(for name: String) -> String {
    let lowercased = name.lowercased()
    if lowercased.contains("airpods max") { return "airpodsmax" }
    if lowercased.contains("airpods pro") { return "airpodspro" }
    if lowercased.contains("airpods") { return "airpods.gen3" }
    if lowercased.contains("iphone") { return "iphone" }
    if lowercased.contains("beats") { return "beats.headphones" }
    return "dot.radiowaves.left.and.right"
}

private func runAppleScript(_ source: String) -> String {
    guard let script = NSAppleScript(source: source) else { return "" }
    var error: NSDictionary?
    let result = script.executeAndReturnError(&error)
    if error != nil { return "" }
    return result.stringValue ?? ""
}

private func runCommand(path: String, args: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    return try? runProcess(process)
}

private func runProcess(_ process: Process) throws -> String {
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
}
