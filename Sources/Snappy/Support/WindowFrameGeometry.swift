import CoreGraphics

enum WindowFrameGeometry {
    static func mappedProportionally(
        _ frame: CGRect,
        from sourceBounds: CGRect,
        to destinationBounds: CGRect
    ) -> CGRect {
        guard sourceBounds.width > 0, sourceBounds.height > 0 else {
            return frame
        }

        return CGRect(
            x: destinationBounds.minX
                + (frame.minX - sourceBounds.minX) / sourceBounds.width * destinationBounds.width,
            y: destinationBounds.minY
                + (frame.minY - sourceBounds.minY) / sourceBounds.height * destinationBounds.height,
            width: frame.width / sourceBounds.width * destinationBounds.width,
            height: frame.height / sourceBounds.height * destinationBounds.height
        )
    }

    /// Repositions a frame so it remains inside the supplied bounds whenever its size allows it.
    static func repositionedInside(_ frame: CGRect, bounds: CGRect) -> CGRect {
        var result = frame

        if result.width <= bounds.width {
            result.origin.x = min(max(result.minX, bounds.minX), bounds.maxX - result.width)
        } else {
            result.origin.x = bounds.minX
        }

        if result.height <= bounds.height {
            result.origin.y = min(max(result.minY, bounds.minY), bounds.maxY - result.height)
        } else {
            result.origin.y = bounds.minY
        }

        return result
    }

    static func isInside(_ frame: CGRect, bounds: CGRect, tolerance: CGFloat = 1) -> Bool {
        frame.minX >= bounds.minX - tolerance
            && frame.maxX <= bounds.maxX + tolerance
            && frame.minY >= bounds.minY - tolerance
            && frame.maxY <= bounds.maxY + tolerance
    }
}
