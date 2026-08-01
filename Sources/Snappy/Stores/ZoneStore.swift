import Combine
import Foundation

@MainActor
final class ZoneStore: ObservableObject {
    @Published private(set) var zones: [SnapZone]

    private let defaults: UserDefaults
    private let storageKey = "snapZones"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([SnapZone].self, from: data),
            !decoded.isEmpty
        {
            zones = decoded
        } else {
            zones = SnapZone.defaults
        }
    }

    func zone(withID id: SnapZone.ID) -> SnapZone? {
        zones.first { $0.id == id }
    }

    func add() -> SnapZone.ID {
        var zone = SnapZone.newZone
        zone.name = uniqueName(startingWith: zone.name)
        zones.append(zone)
        persist()
        return zone.id
    }

    func duplicate(id: SnapZone.ID) -> SnapZone.ID? {
        guard var copy = zone(withID: id) else { return nil }
        copy.id = UUID()
        copy.name = uniqueName(startingWith: "\(copy.name) Copy")
        zones.append(copy)
        persist()
        return copy.id
    }

    func replace(_ zone: SnapZone) {
        guard let index = zones.firstIndex(where: { $0.id == zone.id }) else { return }
        var normalized = zone
        normalized.normalize()
        zones[index] = normalized
        persist()
    }

    func remove(id: SnapZone.ID) {
        zones.removeAll { $0.id == id }
        persist()
    }

    func resetToDefaults() {
        zones = SnapZone.defaults
        persist()
    }

    private func uniqueName(startingWith candidate: String) -> String {
        guard zones.contains(where: { $0.name == candidate }) else { return candidate }

        var suffix = 2
        while zones.contains(where: { $0.name == "\(candidate) \(suffix)" }) {
            suffix += 1
        }
        return "\(candidate) \(suffix)"
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(zones) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
