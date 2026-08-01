import SwiftUI

struct ContentView: View {
    @ObservedObject var zoneStore: ZoneStore
    @ObservedObject var snapEngine: SnapEngine
    @AppStorage("snappingEnabled") private var snappingEnabled = true

    @State private var selection: SnapZone.ID?

    var body: some View {
        NavigationSplitView {
            ZoneListView(zoneStore: zoneStore, selection: $selection)
                .navigationSplitViewColumnWidth(min: 210, ideal: 240)
        } detail: {
            Group {
                if
                    let selection,
                    let zone = zoneStore.zone(withID: selection)
                {
                    ZoneEditorView(
                        zone: Binding(
                            get: { zoneStore.zone(withID: selection) ?? zone },
                            set: { zoneStore.replace($0) }
                        ),
                        shortcutHasConflict: zoneStore.hasShortcutConflict(for: selection)
                    )
                } else {
                    ContentUnavailableView(
                        "Select a Hotspot",
                        systemImage: "scope",
                        description: Text("Choose a hotspot to edit its trigger and destination.")
                    )
                }
            }
            .safeAreaInset(edge: .top) {
                EngineStatusView(snapEngine: snapEngine)
            }
        }
        .navigationTitle("Snappy")
        .toolbar {
            ToolbarItemGroup {
                Toggle("Snapping", isOn: $snappingEnabled)
                    .toggleStyle(.switch)
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .onAppear {
            if selection == nil {
                selection = zoneStore.zones.first?.id
            }
        }
        .onChange(of: zoneStore.zones) { _, zones in
            if let selection, zones.contains(where: { $0.id == selection }) {
                return
            }
            selection = zones.first?.id
        }
    }
}
