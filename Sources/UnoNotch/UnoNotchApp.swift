import SwiftUI

@main
struct UnoNotchApp: App {
    @StateObject private var model = UnoNotchModel.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Front Desk AI", systemImage: "menubar.dock.rectangle") {
            MenuBarControlsView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
                .frame(width: 420, height: 320)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Toggle Front Desk AI") {
                    model.toggleExpanded()
                }
                .keyboardShortcut("o")

                Button("Open Lead Inbox") {
                    model.focusInbox()
                    model.isExpanded = true
                }
                .keyboardShortcut("f")
            }
        }
    }
}
