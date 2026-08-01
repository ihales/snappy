import SwiftUI

struct DisplayPreviewView: View {
    @Binding var zone: SnapZone
    @AppStorage("hotspotLengthPercent") private var hotspotLength = 30.0

    @State private var destinationMoveStart: SnapZone?
    @State private var destinationResizeStart: SnapZone?

    var body: some View {
        GeometryReader { proxy in
            let frame = CGRect(origin: .zero, size: proxy.size)
            let destination = previewDestination(in: frame)
            let activations = previewActivations(in: frame)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.separator, lineWidth: 1)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.accentColor.opacity(0.24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 2)
                    }
                    .contentShape(Rectangle())
                    .frame(width: destination.width, height: destination.height)
                    .offset(x: destination.minX, y: destination.minY)
                    .gesture(destinationMoveGesture(in: frame))
                    .help("Drag to move the destination frame")

                Text("Window")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
                    .position(x: destination.midX, y: destination.midY)
                    .allowsHitTesting(false)

                ForEach(DestinationCorner.allCases, id: \.self) { corner in
                    Circle()
                        .fill(.background)
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                        .frame(width: 14, height: 14)
                        .position(destinationHandle(for: corner, in: destination))
                        .gesture(destinationResizeGesture(corner: corner, in: frame))
                        .help("Drag to resize the destination frame")
                }

                ActivationZoneShape(frames: activations)
                    .fill(Color.orange.opacity(0.82))
                    .contentShape(ActivationZoneShape(frames: activations))
                    .shadow(color: Color.orange.opacity(0.35), radius: 2)
                    .gesture(activationMoveGesture(in: frame))
                    .help("Drag to move the drop zone")

                Image(systemName: zone.activationEdge.isVertical ? "arrow.up.and.down" : "arrow.left.and.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .position(activationLabelPoint(in: activations))
                    .allowsHitTesting(false)
            }
            .coordinateSpace(name: "displayPreview")
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Visual editor for \(zone.name)")
        .accessibilityValue(
            "Drop zone on the \(zone.activationEdge.title.lowercased()) edge at \(zone.activationPosition) percent"
        )
    }

    private func previewDestination(in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.width * zone.targetX / 100,
            y: frame.height * zone.targetY / 100,
            width: frame.width * zone.targetWidth / 100,
            height: frame.height * zone.targetHeight / 100
        )
    }

    private func previewActivations(in frame: CGRect) -> [CGRect] {
        zone.activationFrames(
            in: frame,
            depth: 16,
            lengthPercent: hotspotLength
        ).map { appKitFrame in
            CGRect(
                x: appKitFrame.minX,
                y: frame.maxY - appKitFrame.maxY,
                width: appKitFrame.width,
                height: appKitFrame.height
            )
        }
    }

    private func activationMoveGesture(in frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("displayPreview"))
            .onChanged { value in
                let location = CGPoint(
                    x: min(max(value.location.x, frame.minX), frame.maxX),
                    y: min(max(value.location.y, frame.minY), frame.maxY)
                )
                let edge = closestEdge(to: location, in: frame)
                let rawPosition = edge.isVertical
                    ? Double((location.y - frame.minY) / frame.height * 100)
                    : Double((location.x - frame.minX) / frame.width * 100)

                var updated = zone
                updated.setActivation(edge: edge, position: rawPosition)
                updated.normalize()
                zone = updated
            }
    }

    private func destinationMoveGesture(in frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("displayPreview"))
            .onChanged { value in
                let start = destinationMoveStart ?? zone
                if destinationMoveStart == nil {
                    destinationMoveStart = zone
                }

                let deltaX = Double(value.translation.width / frame.width * 100)
                let deltaY = Double(value.translation.height / frame.height * 100)
                var updated = start
                updated.targetX = min(max(start.targetX + deltaX, 0), 100 - start.targetWidth)
                updated.targetY = min(max(start.targetY + deltaY, 0), 100 - start.targetHeight)
                updated.normalize()
                zone = updated
            }
            .onEnded { _ in
                destinationMoveStart = nil
            }
    }

    private func destinationResizeGesture(
        corner: DestinationCorner,
        in frame: CGRect
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("displayPreview"))
            .onChanged { value in
                let start = destinationResizeStart ?? zone
                if destinationResizeStart == nil {
                    destinationResizeStart = zone
                }

                let deltaX = Double(value.translation.width / frame.width * 100)
                let deltaY = Double(value.translation.height / frame.height * 100)
                let minimumSize = 4.0
                var left = start.targetX
                var right = start.targetX + start.targetWidth
                var top = start.targetY
                var bottom = start.targetY + start.targetHeight

                if corner.isLeft {
                    left = min(max(start.targetX + deltaX, 0), right - minimumSize)
                } else {
                    right = max(min(start.targetX + start.targetWidth + deltaX, 100), left + minimumSize)
                }

                if corner.isTop {
                    top = min(max(start.targetY + deltaY, 0), bottom - minimumSize)
                } else {
                    bottom = max(min(start.targetY + start.targetHeight + deltaY, 100), top + minimumSize)
                }

                var updated = start
                updated.targetX = left
                updated.targetY = top
                updated.targetWidth = right - left
                updated.targetHeight = bottom - top
                updated.normalize()
                zone = updated
            }
            .onEnded { _ in
                destinationResizeStart = nil
            }
    }

    private func closestEdge(to point: CGPoint, in frame: CGRect) -> SnapEdge {
        let distances: [(edge: SnapEdge, distance: CGFloat)] = [
            (.left, point.x - frame.minX),
            (.top, point.y - frame.minY),
            (.right, frame.maxX - point.x),
            (.bottom, frame.maxY - point.y)
        ]
        return distances.min { $0.distance < $1.distance }?.edge ?? .left
    }

    private func destinationHandle(
        for corner: DestinationCorner,
        in frame: CGRect
    ) -> CGPoint {
        CGPoint(
            x: corner.isLeft ? frame.minX + 7 : frame.maxX - 7,
            y: corner.isTop ? frame.minY + 7 : frame.maxY - 7
        )
    }

    private func activationLabelPoint(in frames: [CGRect]) -> CGPoint {
        let matchingFrame = zone.activationEdge.isVertical
            ? frames.max(by: { $0.height < $1.height })
            : frames.max(by: { $0.width < $1.width })
        guard let matchingFrame else {
            return .zero
        }
        return CGPoint(x: matchingFrame.midX, y: matchingFrame.midY)
    }
}

private struct ActivationZoneShape: Shape {
    let frames: [CGRect]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for frame in frames {
            path.addRoundedRect(
                in: frame,
                cornerSize: CGSize(width: 5, height: 5)
            )
        }
        return path
    }
}

private enum DestinationCorner: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var isLeft: Bool {
        self == .topLeft || self == .bottomLeft
    }

    var isTop: Bool {
        self == .topLeft || self == .topRight
    }
}
