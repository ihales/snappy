import AppKit
import CoreGraphics

enum ScreenCoordinates {
    /// AppKit uses a bottom-left origin. Accessibility uses the primary display's top-left.
    static var accessibilityDesktopTop: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    static func accessibilityPoint(fromAppKit point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: accessibilityDesktopTop - point.y)
    }

    static func accessibilityRect(fromAppKit rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: accessibilityDesktopTop - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func screen(containing point: CGPoint) -> NSScreen? {
        if let exact = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            return exact
        }

        return NSScreen.screens.min { lhs, rhs in
            lhs.frame.distance(to: point) < rhs.frame.distance(to: point)
        }
    }
}

private extension CGRect {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = max(minX - point.x, 0, point.x - maxX)
        let dy = max(minY - point.y, 0, point.y - maxY)
        return hypot(dx, dy)
    }
}
