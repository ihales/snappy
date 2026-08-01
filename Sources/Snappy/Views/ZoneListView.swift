import SwiftUI

struct ZoneListView: View {
    @ObservedObject var zoneStore: ZoneStore
    @Binding var selection: SnapZone.ID?

    var body: some View {
        List(zoneStore.zones, selection: $selection) { zone in
            Label(zone.name, systemImage: "scope")
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
}
