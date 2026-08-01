import AppKit
import SwiftUI

@MainActor
final class SnapPreviewController {
    private var panel: NSPanel?

    func show(frame: CGRect, zoneName: String) {
        let panel = panel ?? makePanel()
        panel.contentView = NSHostingView(rootView: SnapPreviewView(zoneName: zoneName))
        panel.setFrame(frame.insetBy(dx: 6, dy: 6), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }
}

private struct SnapPreviewView: View {
    let zoneName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.22))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.accentColor.opacity(0.9), lineWidth: 3)

            Text(zoneName)
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
        }
    }
}
