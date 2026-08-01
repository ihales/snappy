import Combine
import Foundation

@MainActor
final class ZoneStore: ObservableObject {
    @Published private(set) var zones: [SnapZone]

    private let defaults: UserDefaults
    private let storageKey = "snapZones"
    private let shortcutMigrationKey = "zoneShortcutKeysMigratedV1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([SnapZone].self, from: data),
            !decoded.isEmpty
        {
            let normalized = decoded.map { zone in
                var normalized = zone
                normalized.normalize()
                return normalized
            }
            zones = SnapZone.repairingDuplicateIdentifiers(in: normalized)

            if zones.map(\.id) != normalized.map(\.id) {
                persist()
            }
        } else {
            zones = SnapZone.defaults
        }

        migrateShortcutKeysIfNeeded()
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
        copy.shortcutKey = nil
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

    func hasShortcutConflict(for id: SnapZone.ID) -> Bool {
        guard
            let zone = zone(withID: id),
            let key = zone.shortcutKey
        else {
            return false
        }
        return zones.contains {
            $0.id != id
                && $0.shortcutKey == key
                && $0.displayWidthAvailabilityOverlaps(with: zone)
        }
    }

    func zones(
        matchingShortcutKey key: String,
        forDisplayWidth width: Double
    ) -> [SnapZone] {
        guard let key = SnapZone.normalizedShortcutKey(key) else { return [] }
        return zones.filter {
            $0.shortcutKey == key && $0.isAvailable(forDisplayWidth: width)
        }
    }

    private func uniqueName(startingWith candidate: String) -> String {
        guard zones.contains(where: { $0.name == candidate }) else { return candidate }

        var suffix = 2
        while zones.contains(where: { $0.name == "\(candidate) \(suffix)" }) {
            suffix += 1
        }
        return "\(candidate) \(suffix)"
    }

    private func migrateShortcutKeysIfNeeded() {
        guard !defaults.bool(forKey: shortcutMigrationKey) else { return }

        let digits = (1...9).map { String($0) }
        let letters = "abcdefghijklmnopqrstuvwxyz".map { String($0) }
        let candidates = digits + letters + ["0"]
        var usedKeys = Set(zones.compactMap(\.shortcutKey))

        for index in zones.indices where zones[index].shortcutKey == nil {
            guard let key = candidates.first(where: { !usedKeys.contains($0) }) else { break }
            zones[index].shortcutKey = key
            usedKeys.insert(key)
        }

        defaults.set(true, forKey: shortcutMigrationKey)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(zones) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
