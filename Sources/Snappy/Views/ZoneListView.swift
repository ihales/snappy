import SwiftUI

struct ZoneListView: View {
    @ObservedObject var zoneStore: ZoneStore
    @Binding var selection: SnapZone.ID?

    var body: some View {
        List(sortedZones, selection: $selection) { zone in
            HStack(spacing: 8) {
                Label(zone.name, systemImage: "scope")
                Spacer()
                if let key = zone.shortcutKey {
                    Text(key.uppercased())
                        .font(.caption.monospaced().weight(.semibold))
                        .frame(minWidth: 18, minHeight: 18)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(
                            zoneStore.hasShortcutConflict(for: zone.id) ? .orange : .secondary
                        )
                }
            }
                .tag(zone.id)
                .contextMenu {
                    Button("Duplicate") {
                        selection = zoneStore.duplicate(id: zone.id)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        zoneStore.remove(id: zone.id)
                    }
                }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button {
                    selection = zoneStore.add()
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add hotspot")

                Button {
                    if let selection {
                        zoneStore.remove(id: selection)
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                .help("Delete hotspot")

                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.bar)
        }
    }

    private var sortedZones: [SnapZone] {
        zoneStore.zones.sorted { lhs, rhs in
            switch lhs.name.localizedStandardCompare(rhs.name) {
            case .orderedAscending:
                return true
            case .orderedDescending:
                return false
            case .orderedSame:
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }
}
