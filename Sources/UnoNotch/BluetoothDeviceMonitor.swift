import AppKit
import Combine
import Foundation
import IOBluetooth

struct ConnectedAccessory: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let subtitle: String
    let symbolName: String
    let isAirPodsFamily: Bool
}

final class BluetoothDeviceMonitor: NSObject, ObservableObject {
    @Published private(set) var lastConnectedAccessory: ConnectedAccessory?

    private var connectNotification: IOBluetoothUserNotification?
    private var seenAddresses = Set<String>()

    override init() {
        super.init()
        seedConnectedDevices()
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
    }

    deinit {
        connectNotification?.unregister()
    }

    private func seedConnectedDevices() {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        for device in pairedDevices where device.isConnected() {
            seenAddresses.insert(device.addressString ?? device.nameOrAddress ?? UUID().uuidString)
        }
    }

    @objc
    private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let deviceName = normalizedName(from: device.nameOrAddress)
        guard let deviceName, shouldPresentAccessory(named: deviceName) else { return }

        let address = device.addressString ?? deviceName
        let isNewConnection = seenAddresses.insert(address).inserted
        guard isNewConnection else { return }

        let accessory = ConnectedAccessory(
            name: deviceName,
            subtitle: subtitle(for: deviceName),
            symbolName: symbolName(for: deviceName),
            isAirPodsFamily: isAirPodsFamily(name: deviceName)
        )

        lastConnectedAccessory = accessory
    }

    private func normalizedName(from rawName: String?) -> String? {
        guard let rawName else { return nil }
        let normalized = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        if normalized.lowercased() == "bluetooth device" {
            return nil
        }
        return normalized
    }

    private func shouldPresentAccessory(named name: String) -> Bool {
        let lowercased = name.lowercased()
        return lowercased.contains("airpods")
            || lowercased.contains("beats")
            || lowercased.contains("headphones")
            || lowercased.contains("headset")
            || lowercased.contains("earbuds")
            || lowercased.contains("speaker")
    }

    private func subtitle(for name: String) -> String {
        if isAirPodsFamily(name: name) {
            return "Connected"
        }
        return "Bluetooth audio connected"
    }

    private func isAirPodsFamily(name: String) -> Bool {
        let lowercased = name.lowercased()
        return lowercased.contains("airpods")
    }

    private func symbolName(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("airpods max") {
            return "airpodsmax"
        }
        if lowercased.contains("airpods pro") {
            return "airpodspro"
        }
        if lowercased.contains("airpods") {
            return "airpods.gen3"
        }
        if lowercased.contains("beats") {
            return "beats.headphones"
        }
        if lowercased.contains("headphones") || lowercased.contains("headset") {
            return "headphones"
        }
        return "dot.radiowaves.left.and.right"
    }
}
