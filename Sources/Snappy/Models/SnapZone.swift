import CoreGraphics
import Foundation

enum SnapEdge: String, Codable, CaseIterable, Hashable, Identifiable {
    case left
    case top
    case right
    case bottom

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var isVertical: Bool { self == .left || self == .right }
}

struct SnapZone: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String

    /// Drop-zone position as percentages measured from the display's top-left.
    /// Normalization pins the point to its nearest display edge.
    var triggerX: Double
    var triggerY: Double

    /// Destination window frame as percentages measured from the usable display's top-left.
    var targetX: Double
    var targetY: Double
    var targetWidth: Double
    var targetHeight: Double

    /// Zero means unbounded. Widths are macOS logical points, not physical pixels.
    var minimumDisplayWidth: Double
    var maximumDisplayWidth: Double

    init(
        id: UUID = UUID(),
        name: String,
        triggerX: Double,
        triggerY: Double,
        targetX: Double,
        targetY: Double,
        targetWidth: Double,
        targetHeight: Double,
        minimumDisplayWidth: Double = 0,
        maximumDisplayWidth: Double = 0
    ) {
        self.id = id
        self.name = name
        self.triggerX = triggerX
        self.triggerY = triggerY
        self.targetX = targetX
        self.targetY = targetY
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        self.minimumDisplayWidth = minimumDisplayWidth
        self.maximumDisplayWidth = maximumDisplayWidth
        normalize()
    }

    var activationEdge: SnapEdge {
        get {
            let distances: [(edge: SnapEdge, distance: Double)] = [
                (.left, triggerX),
                (.top, triggerY),
                (.right, 100 - triggerX),
                (.bottom, 100 - triggerY)
            ]
            return distances.min { $0.distance < $1.distance }?.edge ?? .left
        }
        set {
            setActivation(edge: newValue, position: activationPosition)
        }
    }

    var activationPosition: Double {
        get { activationEdge.isVertical ? triggerY : triggerX }
        set { setActivation(edge: activationEdge, position: newValue) }
    }

    var activationPerimeterPosition: Double {
        switch activationEdge {
        case .top:
            return activationPosition
        case .right:
            return 100 + activationPosition
        case .bottom:
            return 300 - activationPosition
        case .left:
            return 400 - activationPosition
        }
    }

    mutating func setActivation(edge: SnapEdge, position: Double) {
        let position = position.clamped(to: 0...100)
        switch edge {
        case .left:
            triggerX = 0
            triggerY = position
        case .top:
            triggerX = position
            triggerY = 0
        case .right:
            triggerX = 100
            triggerY = position
        case .bottom:
            triggerX = position
            triggerY = 100
        }
    }

    mutating func normalize() {
        triggerX = triggerX.clamped(to: 0...100)
        triggerY = triggerY.clamped(to: 0...100)
        let edge = activationEdge
        let position = activationPosition
        setActivation(edge: edge, position: position)

        targetX = targetX.clamped(to: 0...100)
        targetY = targetY.clamped(to: 0...100)
        targetWidth = targetWidth.clamped(to: 1...100)
        targetHeight = targetHeight.clamped(to: 1...100)
        targetWidth = min(targetWidth, 100 - targetX)
        targetHeight = min(targetHeight, 100 - targetY)
        minimumDisplayWidth = max(0, minimumDisplayWidth)
        maximumDisplayWidth = max(0, maximumDisplayWidth)
    }

    func isAvailable(forDisplayWidth width: Double) -> Bool {
        let isAboveMinimum = minimumDisplayWidth == 0 || width >= minimumDisplayWidth
        let isBelowMaximum = maximumDisplayWidth == 0 || width <= maximumDisplayWidth
        return isAboveMinimum && isBelowMaximum
    }

    func triggerPoint(in displayFrame: CGRect) -> CGPoint {
        CGPoint(
            x: displayFrame.minX + displayFrame.width * triggerX / 100,
            y: displayFrame.maxY - displayFrame.height * triggerY / 100
        )
    }

    func activationFrames(
        in displayFrame: CGRect,
        depth: CGFloat,
        lengthPercent: Double
    ) -> [CGRect] {
        let lengthPercent = min(max(lengthPercent, 4), 100)
        let center = activationPerimeterPosition.truncatingRemainder(dividingBy: 400)
        let halfLength = lengthPercent / 2
        let start = center - halfLength
        let end = center + halfLength
        let perimeterRanges: [ClosedRange<Double>]

        if start < 0 {
            perimeterRanges = [(start + 400)...400, 0...end]
        } else if end > 400 {
            perimeterRanges = [start...400, 0...(end - 400)]
        } else {
            perimeterRanges = [start...end]
        }

        let edgeRanges: [(edge: SnapEdge, range: ClosedRange<Double>)] = [
            (.top, 0...100),
            (.right, 100...200),
            (.bottom, 200...300),
            (.left, 300...400)
        ]
        let depth = min(max(depth, 1), min(displayFrame.width, displayFrame.height))

        return perimeterRanges.flatMap { perimeterRange in
            edgeRanges.compactMap { edge, edgeRange in
                let lower = max(perimeterRange.lowerBound, edgeRange.lowerBound)
                let upper = min(perimeterRange.upperBound, edgeRange.upperBound)
                guard upper - lower > 0.0001 else { return nil }
                return activationFrame(
                    for: edge,
                    perimeterStart: lower,
                    perimeterEnd: upper,
                    displayFrame: displayFrame,
                    depth: depth
                )
            }
        }
    }

    private func activationFrame(
        for edge: SnapEdge,
        perimeterStart: Double,
        perimeterEnd: Double,
        displayFrame: CGRect,
        depth: CGFloat
    ) -> CGRect {
        switch edge {
        case .top:
            let start = perimeterStart / 100
            let end = perimeterEnd / 100
            return CGRect(
                x: displayFrame.minX + displayFrame.width * start,
                y: displayFrame.maxY - depth,
                width: displayFrame.width * (end - start),
                height: depth
            )
        case .right:
            let start = (perimeterStart - 100) / 100
            let end = (perimeterEnd - 100) / 100
            return CGRect(
                x: displayFrame.maxX - depth,
                y: displayFrame.maxY - displayFrame.height * end,
                width: depth,
                height: displayFrame.height * (end - start)
            )
        case .bottom:
            let start = (perimeterStart - 200) / 100
            let end = (perimeterEnd - 200) / 100
            return CGRect(
                x: displayFrame.maxX - displayFrame.width * end,
                y: displayFrame.minY,
                width: displayFrame.width * (end - start),
                height: depth
            )
        case .left:
            let start = (perimeterStart - 300) / 100
            let end = (perimeterEnd - 300) / 100
            return CGRect(
                x: displayFrame.minX,
                y: displayFrame.minY + displayFrame.height * start,
                width: depth,
                height: displayFrame.height * (end - start)
            )
        }
    }

    func targetFrame(in visibleFrame: CGRect) -> CGRect {
        let width = visibleFrame.width * targetWidth / 100
        let height = visibleFrame.height * targetHeight / 100
        let top = visibleFrame.maxY - visibleFrame.height * targetY / 100

        return CGRect(
            x: visibleFrame.minX + visibleFrame.width * targetX / 100,
            y: top - height,
            width: width,
            height: height
        )
    }

    static let defaults: [SnapZone] = [
        SnapZone(
            name: "Left Half",
            triggerX: 0,
            triggerY: 50,
            targetX: 0,
            targetY: 0,
            targetWidth: 50,
            targetHeight: 100
        ),
        SnapZone(
            name: "Maximize",
            triggerX: 50,
            triggerY: 0,
            targetX: 0,
            targetY: 0,
            targetWidth: 100,
            targetHeight: 100
        ),
        SnapZone(
            name: "Right Half",
            triggerX: 100,
            triggerY: 50,
            targetX: 50,
            targetY: 0,
            targetWidth: 50,
            targetHeight: 100
        )
    ]

    static let newZone = SnapZone(
        name: "New Hotspot",
        triggerX: 50,
        triggerY: 0,
        targetX: 25,
        targetY: 25,
        targetWidth: 50,
        targetHeight: 50
    )
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
