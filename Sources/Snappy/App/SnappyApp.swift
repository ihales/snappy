import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowLifecycleNotifications: [Notification.Name] = [
        NSWindow.didBecomeKeyNotification,
        NSWindow.didResignKeyNotification,
        NSWindow.willCloseNotification,
        NSWindow.didMiniaturizeNotification,
        NSWindow.didDeminiaturizeNotification,
    ]

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        for name in windowLifecycleNotifications {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowStateDidChange),
                name: name,
                object: nil
            )
        }

        scheduleActivationPolicyUpdate(activateVisibleWindows: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        sender.setActivationPolicy(.regular)
        if !flag, let window = sender.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
        sender.activate(ignoringOtherApps: true)
        scheduleActivationPolicyUpdate()
        return true
    }

    @objc private func windowStateDidChange(_ notification: Notification) {
        scheduleActivationPolicyUpdate()
    }

    private func scheduleActivationPolicyUpdate(activateVisibleWindows: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let hasVisibleConfigurationWindow = self.hasVisibleConfigurationWindow

            NSApp.setActivationPolicy(hasVisibleConfigurationWindow ? .regular : .accessory)

            if activateVisibleWindows, hasVisibleConfigurationWindow {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private var hasVisibleConfigurationWindow: Bool {
        NSApp.windows.contains { window in
            window.isVisible
                && !window.isMiniaturized
                && window.canBecomeMain
                && !(window is NSPanel)
        }
    }
}

@main
struct SnappyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "hotspotLengthPercent") == nil {
            let oldRadius = defaults.object(forKey: "hotspotRadiusPercent") as? Double
            let migratedLength: Double
            if let oldRadius, abs(oldRadius - 8) > 0.001 {
                migratedLength = min(max(oldRadius * 2, 4), 100)
            } else {
                migratedLength = 30
            }
            defaults.set(migratedLength, forKey: "hotspotLengthPercent")
        }
        defaults.register(defaults: [
            "snappingEnabled": true,
            "showMenuBarIcon": true,
            "hotspotLengthPercent": 30.0
        ])
        _model = StateObject(wrappedValue: AppModel())
    }

    var body: some Scene {
        WindowGroup("Snappy", id: "main") {
            ContentView(zoneStore: model.zoneStore, snapEngine: model.snapEngine)
                .frame(minWidth: 760, minHeight: 520)
                .onAppear {
                    model.snapEngine.start()
                }
        }
        .defaultSize(width: 900, height: 620)

        MenuBarExtra(
            "Snappy",
            systemImage: "rectangle.3.group",
            isInserted: $showMenuBarIcon
        ) {
            MenuBarContent(snapEngine: model.snapEngine)
        }

        Settings {
            GeneralSettingsView(
                snapEngine: model.snapEngine,
                loginItemManager: model.loginItemManager
            )
        }

        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Hotspot") {
                    _ = model.zoneStore.add()
                }
                .keyboardShortcut("n")
            }
        }
    }
}
