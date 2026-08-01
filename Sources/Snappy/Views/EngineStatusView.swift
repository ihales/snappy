import SwiftUI

struct EngineStatusView: View {
    @ObservedObject var snapEngine: SnapEngine

    var body: some View {
        if !snapEngine.accessibilityGranted {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)
                Text("Accessibility access is required to move other apps’ windows.")
                    .font(.callout)
                Spacer()
                Button("Grant Access") {
                    snapEngine.requestAccessibilityAccess()
                }
                Button("Open Settings") {
                    snapEngine.openAccessibilitySettings()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        } else if !snapEngine.shortcutMonitoringAvailable {
            HStack(spacing: 10) {
                Image(systemName: "keyboard.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("The global ⌃⌥E shortcut is unavailable. Relaunch Snappy after granting Accessibility access.")
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        } else if let error = snapEngine.lastError {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error).font(.callout)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}
