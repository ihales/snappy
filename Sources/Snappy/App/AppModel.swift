import Foundation

@MainActor
final class AppModel: ObservableObject {
    let zoneStore: ZoneStore
    let snapEngine: SnapEngine

    init(defaults: UserDefaults = .standard) {
        let zoneStore = ZoneStore(defaults: defaults)
        self.zoneStore = zoneStore
        snapEngine = SnapEngine(zoneStore: zoneStore, defaults: defaults)
    }
}
