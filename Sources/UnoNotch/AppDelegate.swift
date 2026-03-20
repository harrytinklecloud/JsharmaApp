import AppKit
import Combine
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panelController: FloatingIslandPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        if RuntimeEnvironment.isBundledApp {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
        let controller = FloatingIslandPanelController(model: .shared)
        controller.showWindow(nil)
        panelController = controller
    }
}

enum RuntimeEnvironment {
    static var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }
}

final class FloatingIslandPanelController: NSWindowController {
    private let model: UnoNotchModel
    private let panelSize = NSSize(width: 840, height: 560)
    private var cancellables = Set<AnyCancellable>()

    init(model: UnoNotchModel) {
        self.model = model

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false

        let rootView = FloatingIslandRootView(model: model)
        panel.contentView = NSHostingView(rootView: rootView)

        super.init(window: panel)
        model.$isExpanded
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.setExpanded(false, animated: true)
            }
            .store(in: &cancellables)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionWindow),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.orderFrontRegardless()
        repositionWindow()
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        guard let window else { return }
        let targetFrame = NSRect(origin: centeredOrigin(for: panelSize), size: panelSize)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
    }

    @objc
    private func repositionWindow() {
        setExpanded(model.isExpanded, animated: false)
    }

    private func centeredOrigin(for size: NSSize) -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = frame.midX - (size.width / 2)
        let y = frame.maxY - size.height + 10
        return NSPoint(x: x, y: y)
    }
}
