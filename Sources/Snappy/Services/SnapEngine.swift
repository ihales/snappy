import AppKit
import ApplicationServices
import Combine

@MainActor
final class SnapEngine: ObservableObject {
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var lastError: String?

    private let zoneStore: ZoneStore
    private let defaults: UserDefaults
    private let preview = SnapPreviewController()
    private var globalMonitor: Any?
    private var permissionTimer: Timer?
    private var session: DragSession?
    private var activeDestination: Destination?

    init(zoneStore: ZoneStore, defaults: UserDefaults = .standard) {
        self.zoneStore = zoneStore
        self.defaults = defaults
    }

    func start() {
        guard globalMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAccessibilityStatus()
            }
        }
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
            lastError = nil
        }
    }

    private var snappingEnabled: Bool {
        defaults.object(forKey: "snappingEnabled") as? Bool ?? true
    }

    private var hotspotLengthPercent: Double {
        let saved = defaults.double(forKey: "hotspotLengthPercent")
        return saved > 0 ? saved : 30
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
            switch result {
            case .applied, .adjustedToFit:
                self?.lastError = nil
            case .exceedsVisibleFrame:
                self?.lastError = "This window’s minimum size is larger than the usable display area."
            case .failed:
                self?.lastError = "That app did not allow Snappy to resize its window."
            }
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
