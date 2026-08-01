import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag, let window = sender.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
        return true
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
            GeneralSettingsView(snapEngine: model.snapEngine)
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
