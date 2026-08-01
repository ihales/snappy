import CoreGraphics

enum HotspotMatcher {
    static let activationDepth: CGFloat = 64

    static func closestZone(
        to point: CGPoint,
        in displayFrame: CGRect,
        zones: [SnapZone],
        lengthPercent: Double
    ) -> SnapZone? {
        var closest: (zone: SnapZone, squaredDistance: CGFloat)?
        for zone in zones {
            let activationFrames = zone.activationFrames(
                in: displayFrame,
                depth: activationDepth,
                lengthPercent: lengthPercent
            )
            guard activationFrames.contains(where: { $0.containsIncludingBoundary(point) }) else {
                continue
            }

            let trigger = zone.triggerPoint(in: displayFrame)
            let dx = trigger.x - point.x
            let dy = trigger.y - point.y
            let squaredDistance = dx * dx + dy * dy
            if closest == nil || squaredDistance < closest!.squaredDistance {
                closest = (zone, squaredDistance)
            }
        }
        return closest?.zone
    }
}

private extension CGRect {
    func containsIncludingBoundary(_ point: CGPoint) -> Bool {
        let rect = standardized
        return point.x >= rect.minX
            && point.x <= rect.maxX
            && point.y >= rect.minY
            && point.y <= rect.maxY
    }
}
