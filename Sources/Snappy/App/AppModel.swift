import Foundation

@MainActor
final class AppModel: ObservableObject {
    let zoneStore: ZoneStore
    let snapEngine: SnapEngine
    let loginItemManager: LoginItemManager

    init(defaults: UserDefaults = .standard) {
        let zoneStore = ZoneStore(defaults: defaults)
        self.zoneStore = zoneStore
        snapEngine = SnapEngine(zoneStore: zoneStore, defaults: defaults)
        loginItemManager = LoginItemManager()
    }
}
