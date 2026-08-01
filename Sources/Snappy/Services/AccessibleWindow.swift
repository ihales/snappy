import AppKit
import ApplicationServices

enum WindowFrameApplicationResult {
    case applied
    case adjustedToFit
    case exceedsVisibleFrame
    case failed
}

struct AccessibleWindow {
    let element: AXUIElement

    static func at(appKitPoint point: CGPoint) -> AccessibleWindow? {
        let axPoint = ScreenCoordinates.accessibilityPoint(fromAppKit: point)
        let systemWide = AXUIElementCreateSystemWide()
        var hitElement: AXUIElement?

        guard AXUIElementCopyElementAtPosition(
            systemWide,
            Float(axPoint.x),
            Float(axPoint.y),
            &hitElement
        ) == .success, let hitElement else {
            return nil
        }

        if let window = windowAttribute(of: hitElement), window.belongsToAnotherProcess {
            return window.canMoveAndResize ? window : nil
        }

        var current: AXUIElement? = hitElement
        for _ in 0..<12 {
            guard let element = current else { break }
            if role(of: element) == (kAXWindowRole as String) {
                let window = AccessibleWindow(element: element)
                guard window.belongsToAnotherProcess, window.canMoveAndResize else { return nil }
                return window
            }
            current = parent(of: element)
        }

        return nil
    }

    var frame: CGRect? {
        guard
            let positionReference = attribute(kAXPositionAttribute),
            let sizeReference = attribute(kAXSizeAttribute),
            CFGetTypeID(positionReference) == AXValueGetTypeID(),
            CFGetTypeID(sizeReference) == AXValueGetTypeID()
        else {
            return nil
        }
        let positionValue = unsafeBitCast(positionReference, to: AXValue.self)
        let sizeValue = unsafeBitCast(sizeReference, to: AXValue.self)

        var position = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue, .cgPoint, &position),
            AXValueGetValue(sizeValue, .cgSize, &size)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    @discardableResult
    func setFrame(
        appKitRect: CGRect,
        inside appKitVisibleFrame: CGRect
    ) -> WindowFrameApplicationResult {
        let rect = ScreenCoordinates.accessibilityRect(fromAppKit: appKitRect)
        let visibleFrame = ScreenCoordinates.accessibilityRect(fromAppKit: appKitVisibleFrame)
        var position = rect.origin
        var size = rect.size

        guard
            let positionValue = AXValueCreate(.cgPoint, &position),
            let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            return .failed
        }

        let application = applicationElement
        let enhancedUIWasEnabled = application?.boolAttribute("AXEnhancedUserInterface") == true
        if enhancedUIWasEnabled {
            _ = application?.setBoolAttribute("AXEnhancedUserInterface", value: false)
        }
        defer {
            if enhancedUIWasEnabled {
                _ = application?.setBoolAttribute("AXEnhancedUserInterface", value: true)
            }
        }

        // Size first is important when crossing from a large display to a smaller one.
        // macOS can preserve the old display's larger size if position is written first.
        let firstSizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        let positionResult = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        let finalSizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        guard
            positionResult == .success,
            firstSizeResult == .success || finalSizeResult == .success,
            var appliedFrame = frame
        else {
            return .failed
        }

        let fittedFrame = WindowFrameGeometry.repositionedInside(appliedFrame, bounds: visibleFrame)
        let neededPositionCorrection = abs(fittedFrame.minX - appliedFrame.minX) > 1
            || abs(fittedFrame.minY - appliedFrame.minY) > 1

        if neededPositionCorrection {
            var correctedPosition = fittedFrame.origin
            if let correctedValue = AXValueCreate(.cgPoint, &correctedPosition) {
                _ = AXUIElementSetAttributeValue(
                    element,
                    kAXPositionAttribute as CFString,
                    correctedValue
                )
                appliedFrame = frame ?? fittedFrame
            }
        }

        if !WindowFrameGeometry.isInside(appliedFrame, bounds: visibleFrame) {
            return .exceedsVisibleFrame
        }
        return neededPositionCorrection ? .adjustedToFit : .applied
    }

    private var belongsToAnotherProcess: Bool {
        var processID: pid_t = 0
        guard AXUIElementGetPid(element, &processID) == .success else { return false }
        return processID != ProcessInfo.processInfo.processIdentifier
    }

    private var canMoveAndResize: Bool {
        var positionSettable = DarwinBoolean(false)
        var sizeSettable = DarwinBoolean(false)
        let positionResult = AXUIElementIsAttributeSettable(
            element,
            kAXPositionAttribute as CFString,
            &positionSettable
        )
        let sizeResult = AXUIElementIsAttributeSettable(
            element,
            kAXSizeAttribute as CFString,
            &sizeSettable
        )
        return positionResult == .success && sizeResult == .success
            && positionSettable.boolValue && sizeSettable.boolValue
    }

    private var applicationElement: AXUIElement? {
        var processID: pid_t = 0
        guard AXUIElementGetPid(element, &processID) == .success else { return nil }
        return AXUIElementCreateApplication(processID)
    }

    private func attribute(_ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func windowAttribute(of element: AXUIElement) -> AccessibleWindow? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &value) == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return AccessibleWindow(element: unsafeBitCast(value, to: AXUIElement.self))
    }

    private static func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func parent(of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value) == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }
}

private extension AXUIElement {
    func boolAttribute(_ name: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success else {
            return nil
        }
        return value as? Bool
    }

    @discardableResult
    func setBoolAttribute(_ name: String, value: Bool) -> Bool {
        AXUIElementSetAttributeValue(
            self,
            name as CFString,
            value as CFBoolean
        ) == .success
    }
}
