import CoreGraphics

enum ScreenLayoutGeometry {
    static func neighborIndex(
        from sourceIndex: Int,
        direction: ScreenDirection,
        frames: [CGRect]
    ) -> Int? {
        guard frames.indices.contains(sourceIndex) else { return nil }

        let source = frames[sourceIndex]
        let candidates = frames.indices.filter { index in
            guard index != sourceIndex else { return false }
            let candidate = frames[index]
            switch direction {
            case .left:
                return candidate.midX < source.midX
            case .right:
                return candidate.midX > source.midX
            case .up:
                return candidate.midY > source.midY
            case .down:
                return candidate.midY < source.midY
            }
        }

        return candidates.min { lhsIndex, rhsIndex in
            score(frames[lhsIndex], from: source, direction: direction)
                < score(frames[rhsIndex], from: source, direction: direction)
        }
    }

    private static func score(
        _ candidate: CGRect,
        from source: CGRect,
        direction: ScreenDirection
    ) -> CGFloat {
        let primaryDistance: CGFloat
        let crossAxisGap: CGFloat
        let crossAxisCenterDistance: CGFloat

        switch direction {
        case .left, .right:
            primaryDistance = abs(candidate.midX - source.midX)
            crossAxisGap = intervalGap(
                source.minY...source.maxY,
                candidate.minY...candidate.maxY
            )
            crossAxisCenterDistance = abs(candidate.midY - source.midY)
        case .up, .down:
            primaryDistance = abs(candidate.midY - source.midY)
            crossAxisGap = intervalGap(
                source.minX...source.maxX,
                candidate.minX...candidate.maxX
            )
            crossAxisCenterDistance = abs(candidate.midX - source.midX)
        }

        // Prefer displays that overlap on the perpendicular axis, then the
        // nearest display in the requested direction. The small center term
        // gives stable results for equally distant staggered displays.
        return crossAxisGap * 10_000 + primaryDistance + crossAxisCenterDistance * 0.001
    }

    private static func intervalGap(
        _ lhs: ClosedRange<CGFloat>,
        _ rhs: ClosedRange<CGFloat>
    ) -> CGFloat {
        max(lhs.lowerBound - rhs.upperBound, rhs.lowerBound - lhs.upperBound, 0)
    }
}
