import Foundation

enum ScreenDirection: CaseIterable, Equatable {
    case left
    case right
    case up
    case down
}

enum ShortcutInput: Equatable {
    case activate
    case zoneKey(String)
    case move(ScreenDirection)
    case cancel
    case unknown
}

struct ShortcutModeState {
    private(set) var isArmed = false

    /// Returns whether the input belongs to Snappy and should be suppressed.
    mutating func handle(_ input: ShortcutInput) -> Bool {
        if !isArmed {
            guard input == .activate else { return false }
            isArmed = true
            return true
        }

        switch input {
        case .move:
            return true
        case .activate, .zoneKey, .cancel, .unknown:
            isArmed = false
            return true
        }
    }

    mutating func cancel() {
        isArmed = false
    }
}
