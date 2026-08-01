import AppKit
import SwiftUI

struct ShortcutHUDItem: Identifiable {
    let id: UUID
    let key: String
    let name: String
}

@MainActor
final class ShortcutHUDController {
    private var panel: NSPanel?

    func show(on screen: NSScreen, zones: [SnapZone], message: String? = nil) {
        let items = zones.compactMap { zone -> ShortcutHUDItem? in
            guard let key = zone.shortcutKey else { return nil }
            return ShortcutHUDItem(id: zone.id, key: key.uppercased(), name: zone.name)
        }
        show(on: screen, items: items, message: message)
    }

    func showMessage(_ message: String, on screen: NSScreen) {
        show(on: screen, items: [], message: message)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func show(
        on screen: NSScreen,
        items: [ShortcutHUDItem],
        message: String?
    ) {
        let panel = panel ?? makePanel()
        let rootView = ShortcutHUDView(items: items, message: message)
            .frame(width: 520)
        let hostingView = NSHostingView(rootView: rootView)
        let contentSize = CGSize(width: 520, height: max(hostingView.fittingSize.height, 96))
        panel.contentView = hostingView
        panel.setFrame(
            CGRect(
                x: screen.visibleFrame.midX - contentSize.width / 2,
                y: screen.visibleFrame.maxY - contentSize.height - 28,
                width: contentSize.width,
                height: contentSize.height
            ),
            display: true
        )
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }
}

private struct ShortcutHUDView: View {
    let items: [ShortcutHUDItem]
    let message: String?

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Snappy mode", systemImage: "keyboard")
                    .font(.headline)
                Spacer()
                Text("Esc to cancel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message {
                Text(message)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !items.isEmpty {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            ShortcutKeycap(item.key)
                            Text(item.name)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                ShortcutKeycap("←")
                ShortcutKeycap("↑")
                ShortcutKeycap("↓")
                ShortcutKeycap("→")
                Text("Move to another display")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(16)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct ShortcutKeycap: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(.caption.monospaced().weight(.bold))
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.separator, lineWidth: 1)
            }
    }
}
