import CoreGraphics
import Foundation

final class GlobalShortcutMonitor {
    var onInput: ((ShortcutInput) -> Void)?

    var isRunning: Bool { eventTap != nil }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var mode = ShortcutModeState()
    private var suppressedKeyCodes: Set<Int64> = []

    @discardableResult
    func start() -> Bool {
        if eventTap != nil { return true }

        let mask = eventMask(for: .keyDown) | eventMask(for: .keyUp)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: globalShortcutCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        cancel()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
        suppressedKeyCodes.removeAll()
    }

    func cancel() {
        mode.cancel()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp, suppressedKeyCodes.remove(keyCode) != nil {
            return nil
        }
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        if suppressedKeyCodes.contains(keyCode) {
            return nil
        }

        let input: ShortcutInput?
        if mode.isArmed {
            input = armedInput(for: event, keyCode: keyCode)
        } else if isLeader(event: event, keyCode: keyCode) {
            input = .activate
        } else {
            input = nil
        }

        guard let input, mode.handle(input) else {
            return Unmanaged.passUnretained(event)
        }

        suppressedKeyCodes.insert(keyCode)
        onInput?(input)
        return nil
    }

    private func isLeader(event: CGEvent, keyCode: Int64) -> Bool {
        guard keyCode == 14 else { return false } // ANSI E
        let relevantModifiers: CGEventFlags = [
            .maskControl,
            .maskAlternate,
            .maskCommand,
            .maskShift
        ]
        let requiredModifiers: CGEventFlags = [.maskControl, .maskAlternate]
        return event.flags.intersection(relevantModifiers) == requiredModifiers
    }

    private func armedInput(for event: CGEvent, keyCode: Int64) -> ShortcutInput {
        switch keyCode {
        case 53:
            return .cancel
        case 123:
            return .move(.left)
        case 124:
            return .move(.right)
        case 125:
            return .move(.down)
        case 126:
            return .move(.up)
        default:
            guard let key = normalizedKey(from: event) else { return .unknown }
            return .zoneKey(key)
        }
    }

    private func normalizedKey(from event: CGEvent) -> String? {
        guard let event = event.copy() else { return nil }
        event.flags = []
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        event.keyboardGetUnicodeString(
            maxStringLength: characters.count,
            actualStringLength: &length,
            unicodeString: &characters
        )
        guard length > 0 else { return nil }
        return SnapZone.normalizedShortcutKey(
            String(utf16CodeUnits: characters, count: length)
        )
    }

    private func eventMask(for type: CGEventType) -> CGEventMask {
        CGEventMask(1) << type.rawValue
    }
}

private func globalShortcutCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<GlobalShortcutMonitor>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}
