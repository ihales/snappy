import AppKit
import ApplicationServices
import Combine

@MainActor
final class SnapEngine: ObservableObject {
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var shortcutMonitoringAvailable = false
    @Published private(set) var lastError: String?

    private let zoneStore: ZoneStore
    private let defaults: UserDefaults
    private let preview = SnapPreviewController()
    private let shortcutMonitor = GlobalShortcutMonitor()
    private let shortcutHUD = ShortcutHUDController()
    private var globalMonitor: Any?
    private var permissionTimer: Timer?
    private var shortcutTimer: Timer?
    private var session: DragSession?
    private var activeDestination: Destination?
    private var shortcutSession: ShortcutSession?

    init(zoneStore: ZoneStore, defaults: UserDefaults = .standard) {
        self.zoneStore = zoneStore
        self.defaults = defaults
    }

    func start() {
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
            ) { [weak self] event in
                Task { @MainActor in
                    self?.handle(event)
                }
            }
        }

        if permissionTimer == nil {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAccessibilityStatus()
                }
            }
        }

        startShortcutMonitoringIfPossible()
    }

    func requestAccessibilityAccess() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func refreshAccessibilityStatus() {
        accessibilityGranted = AXIsProcessTrusted()
        if accessibilityGranted {
            startShortcutMonitoringIfPossible()
        } else {
            shortcutMonitoringAvailable = false
            shortcutMonitor.stop()
            cancelShortcutMode()
        }
    }

    private var snappingEnabled: Bool {
        defaults.object(forKey: "snappingEnabled") as? Bool ?? true
    }

    private var hotspotLengthPercent: Double {
        let saved = defaults.double(forKey: "hotspotLengthPercent")
        return saved > 0 ? saved : 30
    }

    private func startShortcutMonitoringIfPossible() {
        guard accessibilityGranted, !shortcutMonitor.isRunning else {
            shortcutMonitoringAvailable = shortcutMonitor.isRunning
            return
        }

        shortcutMonitor.onInput = { [weak self] input in
            Task { @MainActor in
                self?.handleShortcut(input)
            }
        }
        shortcutMonitoringAvailable = shortcutMonitor.start()
        if !shortcutMonitoringAvailable {
            lastError = "Snappy couldn’t start its global keyboard shortcut. Check Accessibility access and relaunch Snappy."
        }
    }

    private func handleShortcut(_ input: ShortcutInput) {
        switch input {
        case .activate:
            activateShortcutMode()
        case let .zoneKey(key):
            snapShortcutSession(toKey: key)
        case let .move(direction):
            moveShortcutSession(direction)
        case .cancel:
            cancelShortcutMode()
        case .unknown:
            endShortcutMode(withMessage: "That key is not assigned to a hotspot.")
        }
    }

    private func activateShortcutMode() {
        shortcutTimer?.invalidate()
        guard snappingEnabled, accessibilityGranted else {
            cancelShortcutMode()
            return
        }
        guard
            let window = AccessibleWindow.focused(),
            let windowFrame = window.appKitFrame,
            let screen = ScreenCoordinates.screen(containingMostOf: windowFrame)
        else {
            showTransientShortcutMessage("No movable window is currently selected.")
            return
        }

        shortcutSession = ShortcutSession(window: window, screen: screen)
        showShortcutHUD(for: screen)
        scheduleShortcutTimeout()
    }

    private func snapShortcutSession(toKey key: String) {
        guard let shortcutSession else {
            cancelShortcutMode()
            return
        }
        let matches = zoneStore.zones(
            matchingShortcutKey: key,
            forDisplayWidth: shortcutSession.screen.frame.width
        )
        guard matches.count == 1, let zone = matches.first else {
            let message = matches.isEmpty
                ? "No hotspot is assigned to \(key.uppercased())."
                : "\(key.uppercased()) is assigned to more than one hotspot."
            endShortcutMode(withMessage: message)
            return
        }

        let frame = zone.targetFrame(in: shortcutSession.screen.visibleFrame)
        let result = shortcutSession.window.setFrame(
            appKitRect: frame,
            inside: shortcutSession.screen.visibleFrame
        )
        updateError(for: result)
        cancelShortcutMode()
    }

    private func moveShortcutSession(_ direction: ScreenDirection) {
        guard var shortcutSession else {
            cancelShortcutMode()
            return
        }
        guard let destinationScreen = ScreenCoordinates.neighboringScreen(
            from: shortcutSession.screen,
            direction: direction
        ) else {
            showShortcutHUD(
                for: shortcutSession.screen,
                message: "There is no display to the \(direction.title)."
            )
            scheduleShortcutTimeout()
            return
        }
        guard let currentFrame = shortcutSession.window.appKitFrame else {
            endShortcutMode(withMessage: "Snappy could not read that window’s frame.")
            return
        }

        let mappedFrame = WindowFrameGeometry.mappedProportionally(
            currentFrame,
            from: shortcutSession.screen.visibleFrame,
            to: destinationScreen.visibleFrame
        )
        let fittedFrame = WindowFrameGeometry.repositionedInside(
            mappedFrame,
            bounds: destinationScreen.visibleFrame
        )
        let result = shortcutSession.window.setFrame(
            appKitRect: fittedFrame,
            inside: destinationScreen.visibleFrame
        )
        updateError(for: result)

        switch result {
        case .applied, .adjustedToFit:
            shortcutSession.screen = destinationScreen
            self.shortcutSession = shortcutSession
            showShortcutHUD(for: destinationScreen)
            scheduleShortcutTimeout()
        case .exceedsVisibleFrame, .failed:
            showShortcutHUD(
                for: shortcutSession.screen,
                message: "That window could not be moved to the \(direction.title)."
            )
            scheduleShortcutTimeout()
        }
    }

    private func showShortcutHUD(for screen: NSScreen, message: String? = nil) {
        let eligibleZones = zoneStore.zones.filter {
            $0.isAvailable(forDisplayWidth: screen.frame.width)
        }
        shortcutHUD.show(on: screen, zones: eligibleZones, message: message)
    }

    private func scheduleShortcutTimeout(after delay: TimeInterval = 3) {
        shortcutTimer?.invalidate()
        shortcutTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.cancelShortcutMode()
            }
        }
    }

    private func cancelShortcutMode() {
        shortcutMonitor.cancel()
        shortcutSession = nil
        shortcutTimer?.invalidate()
        shortcutTimer = nil
        shortcutHUD.hide()
    }

    private func endShortcutMode(withMessage message: String) {
        let screen = shortcutSession?.screen ?? NSScreen.main ?? NSScreen.screens.first
        shortcutMonitor.cancel()
        shortcutSession = nil
        shortcutTimer?.invalidate()
        if let screen {
            shortcutHUD.showMessage(message, on: screen)
            scheduleShortcutTimeout(after: 1.4)
        } else {
            shortcutHUD.hide()
        }
    }

    private func showTransientShortcutMessage(_ message: String) {
        let screen = NSScreen.main ?? ScreenCoordinates.screen(containing: NSEvent.mouseLocation)
        shortcutMonitor.cancel()
        shortcutSession = nil
        if let screen {
            shortcutHUD.showMessage(message, on: screen)
            scheduleShortcutTimeout(after: 1.4)
        }
    }

    private func updateError(for result: WindowFrameApplicationResult) {
        switch result {
        case .applied, .adjustedToFit:
            lastError = nil
        case .exceedsVisibleFrame:
            lastError = "This window’s minimum size is larger than the usable display area."
        case .failed:
            lastError = "That app did not allow Snappy to resize its window."
        }
    }

    private func handle(_ event: NSEvent) {
        guard snappingEnabled, accessibilityGranted else {
            resetDrag()
            return
        }

        switch event.type {
        case .leftMouseDown:
            beginDrag(at: NSEvent.mouseLocation)
        case .leftMouseDragged:
            updateDrag(at: NSEvent.mouseLocation)
        case .leftMouseUp:
            finishDrag()
        default:
            break
        }
    }

    private func beginDrag(at point: CGPoint) {
        resetDrag()
        guard let window = AccessibleWindow.at(appKitPoint: point), let frame = window.frame else {
            return
        }
        session = DragSession(window: window, initialAccessibilityFrame: frame, didMove: false)
    }

    private func updateDrag(at point: CGPoint) {
        guard var session, let currentFrame = session.window.frame else { return }

        if !session.didMove {
            let dx = currentFrame.origin.x - session.initialAccessibilityFrame.origin.x
            let dy = currentFrame.origin.y - session.initialAccessibilityFrame.origin.y
            session.didMove = hypot(dx, dy) >= 3
            self.session = session
        }

        guard session.didMove, let screen = ScreenCoordinates.screen(containing: point) else {
            return
        }

        let eligibleZones = zoneStore.zones.filter {
            $0.isAvailable(forDisplayWidth: screen.frame.width)
        }
        let destination = HotspotMatcher.closestZone(
            to: point,
            in: screen.frame,
            zones: eligibleZones,
            lengthPercent: hotspotLengthPercent
        ).map { Destination(zone: $0, screen: screen) }

        activeDestination = destination
        if let destination {
            preview.show(
                frame: destination.zone.targetFrame(in: destination.screen.visibleFrame),
                zoneName: destination.zone.name
            )
        } else {
            preview.hide()
        }
    }

    private func finishDrag() {
        let finishedSession = session
        let destination = activeDestination
        resetDrag()

        guard
            let finishedSession,
            finishedSession.didMove,
            let destination
        else {
            return
        }

        let frame = destination.zone.targetFrame(in: destination.screen.visibleFrame)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            let result = finishedSession.window.setFrame(
                appKitRect: frame,
                inside: destination.screen.visibleFrame
            )
            self?.updateError(for: result)
        }
    }

    private func resetDrag() {
        session = nil
        activeDestination = nil
        preview.hide()
    }
}

private struct DragSession {
    let window: AccessibleWindow
    let initialAccessibilityFrame: CGRect
    var didMove: Bool
}

private struct Destination {
    let zone: SnapZone
    let screen: NSScreen
}

private struct ShortcutSession {
    let window: AccessibleWindow
    var screen: NSScreen
}

private extension ScreenDirection {
    var title: String {
        switch self {
        case .left: "left"
        case .right: "right"
        case .up: "top"
        case .down: "bottom"
        }
    }
}
