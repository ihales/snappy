import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var snapEngine: SnapEngine
    @AppStorage("snappingEnabled") private var snappingEnabled = true
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Snappy") {
            showMainWindow()
        }

        Toggle("Snapping", isOn: $snappingEnabled)

        Text("Snappy mode: ⌃⌥E")

        if !snapEngine.accessibilityGranted {
            Divider()
            Button("Grant Accessibility") {
                showMainWindow()
                snapEngine.requestAccessibilityAccess()
            }
        }

        Divider()
        SettingsLink {
            Text("Settings…")
        }
        Button("Quit Snappy") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Snappy" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}
