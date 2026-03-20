import AppKit
import Combine
import Foundation

enum MusicSource: String, CaseIterable, Identifiable {
    case appleMusic
    case spotify

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify"
        }
    }

    var symbolName: String {
        switch self {
        case .appleMusic: "music.note"
        case .spotify: "waveform"
        }
    }
}

struct MusicState {
    var source: MusicSource
    var title: String
    var artist: String
    var isPlaying: Bool
    var availabilityNote: String?
    var artworkURL: URL?

    static func placeholder(for source: MusicSource) -> MusicState {
        MusicState(
            source: source,
            title: "Open your flow soundtrack",
            artist: "Control \(source.displayName) from the notch",
            isPlaying: false,
            availabilityNote: nil,
            artworkURL: nil
        )
    }
}

final class MusicController: ObservableObject, @unchecked Sendable {
    @Published private(set) var currentState: MusicState = .placeholder(for: .appleMusic)

    func refresh(for source: MusicSource) {
        DispatchQueue.global(qos: .userInitiated).async {
            let state = Self.executeStateScript(for: source) ?? MusicState(
                source: source,
                title: source.displayName,
                artist: "Launch the app to start controlling playback",
                isPlaying: false,
                availabilityNote: "If playback controls don’t respond, macOS may ask for Apple Events access.",
                artworkURL: nil
            )
            DispatchQueue.main.async {
                self.currentState = state
            }
        }
    }

    func togglePlayPause(for source: MusicSource) {
        _ = Self.run(Self.script(for: source, action: .togglePlayPause))
    }

    func nextTrack(for source: MusicSource) {
        _ = Self.run(Self.script(for: source, action: .nextTrack))
    }

    func previousTrack(for source: MusicSource) {
        _ = Self.run(Self.script(for: source, action: .previousTrack))
    }

    func openFocusPlaylist(for source: MusicSource) {
        _ = Self.run(Self.script(for: source, action: .openFocusMix))
    }

    private static func executeStateScript(for source: MusicSource) -> MusicState? {
        guard let output = run(script(for: source, action: .readState)) else { return nil }
        let parts = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "||")
        guard parts.count >= 3 else { return nil }
        let artworkURL = parts.count > 3 ? artworkURL(from: parts[3], source: source) : nil
        return MusicState(
            source: source,
            title: parts[0].isEmpty ? "No track loaded" : parts[0],
            artist: parts[1].isEmpty ? "Waiting for playback" : parts[1],
            isPlaying: parts[2] == "playing",
            availabilityNote: nil,
            artworkURL: artworkURL
        )
    }

    private static func run(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        return result.stringValue
    }

    private static func script(for source: MusicSource, action: ScriptAction) -> String {
        switch (source, action) {
        case (.appleMusic, .togglePlayPause):
            """
            tell application "Music"
                if running then playpause
            end tell
            """
        case (.appleMusic, .nextTrack):
            """
            tell application "Music"
                if running then next track
            end tell
            """
        case (.appleMusic, .previousTrack):
            """
            tell application "Music"
                if running then previous track
            end tell
            """
        case (.appleMusic, .openFocusMix):
            """
            tell application "Music"
                activate
                search for "lofi focus"
            end tell
            """
        case (.appleMusic, .readState):
            """
            tell application "Music"
                if not running then return ""
                set trackName to ""
                set artistName to ""
                set artworkPath to ""
                try
                    set trackName to name of current track
                    set artistName to artist of current track
                end try
                try
                    if (count of artworks of current track) > 0 then
                        set rawData to raw data of artwork 1 of current track
                        set outPath to "/tmp/unonotch-apple-music-artwork.tiff"
                        set fileRef to open for access (POSIX file outPath) with write permission
                        set eof fileRef to 0
                        write rawData to fileRef
                        close access fileRef
                        set artworkPath to outPath
                    end if
                on error
                    try
                        close access (POSIX file "/tmp/unonotch-apple-music-artwork.tiff")
                    end try
                end try
                set currentPlayerState to (player state as text)
                return trackName & "||" & artistName & "||" & currentPlayerState & "||" & artworkPath
            end tell
            """
        case (.spotify, .togglePlayPause):
            """
            tell application "Spotify"
                if running then playpause
            end tell
            """
        case (.spotify, .nextTrack):
            """
            tell application "Spotify"
                if running then next track
            end tell
            """
        case (.spotify, .previousTrack):
            """
            tell application "Spotify"
                if running then previous track
            end tell
            """
        case (.spotify, .openFocusMix):
            """
            tell application "Spotify"
                activate
            end tell
            open location "spotify:search:deep%20focus"
            """
        case (.spotify, .readState):
            """
            tell application "Spotify"
                if not running then return ""
                set trackName to ""
                set artistName to ""
                set trackArtwork to ""
                try
                    set trackName to name of current track
                    set artistName to artist of current track
                    set trackArtwork to artwork url of current track
                end try
                set currentPlayerState to (player state as text)
                return trackName & "||" & artistName & "||" & currentPlayerState & "||" & trackArtwork
            end tell
            """
        }
    }

    private static func artworkURL(from rawValue: String, source: MusicSource) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        switch source {
        case .appleMusic:
            return URL(fileURLWithPath: trimmed)
        case .spotify:
            return URL(string: trimmed)
        }
    }
}

private enum ScriptAction {
    case togglePlayPause
    case nextTrack
    case previousTrack
    case openFocusMix
    case readState
}
