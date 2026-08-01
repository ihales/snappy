import CoreGraphics
import Foundation

@main
@MainActor
enum SnapZoneSelfTests {
    static func main() {
        testTriggerPointPinsToNearestEdge()
        testActivationFrameUsesFixedDepthAndGlobalLength()
        testActivationZoneWrapsAroundCorner()
        testTargetFrameUsesTopLeftPercentages()
        testTargetFrameOnSmallDisplay()
        testDisplayWidthConditionsTreatZeroAsUnbounded()
        testDisplayWidthShortcutConflictRanges()
        testNormalizationKeepsDestinationInsideDisplay()
        testFrameIsRepositionedInsideSmallDisplay()
        testFrameMapsProportionallyBetweenDisplays()
        testClosestOverlappingHotspotWins()
        testShortcutKeysNormalizeAndDecodeFromOlderData()
        testShortcutModeStateMachine()
        testDirectionalScreenSelection()
        testNewZonesHaveIndependentIdentifiers()
        testDuplicateZoneIdentifiersAreRepaired()
        testZoneStoreAddsEditsAndRemovesIndependentZones()
        print("SnapZoneSelfTests: all checks passed")
    }

    private static func testTargetFrameOnSmallDisplay() {
        let visibleFrame = CGRect(x: 0, y: 24, width: 1024, height: 704)

        let leftFrame = SnapZone.defaults[0].targetFrame(in: visibleFrame)
        expect(leftFrame.minX, equals: 0)
        expect(leftFrame.maxX, equals: 512)
        expect(leftFrame.minY, equals: 24)
        expect(leftFrame.maxY, equals: 728)

        let maximizeFrame = SnapZone.defaults[1].targetFrame(in: visibleFrame)
        expect(maximizeFrame.minX, equals: visibleFrame.minX)
        expect(maximizeFrame.maxX, equals: visibleFrame.maxX)
        expect(maximizeFrame.minY, equals: visibleFrame.minY)
        expect(maximizeFrame.maxY, equals: visibleFrame.maxY)
    }

    private static func testTriggerPointPinsToNearestEdge() {
        let zone = SnapZone(
            name: "Test",
            triggerX: 25,
            triggerY: 20,
            targetX: 0,
            targetY: 0,
            targetWidth: 50,
            targetHeight: 50
        )
        let point = zone.triggerPoint(in: CGRect(x: 100, y: 200, width: 1000, height: 500))

        expect(point.x, equals: 350)
        expect(point.y, equals: 700)
        expect(zone.activationEdge == .top)
    }

    private static func testActivationFrameUsesFixedDepthAndGlobalLength() {
        let zone = SnapZone(
            name: "Left",
            triggerX: 0,
            triggerY: 50,
            targetX: 0,
            targetY: 0,
            targetWidth: 50,
            targetHeight: 100
        )
        let frames = zone.activationFrames(
            in: CGRect(x: 100, y: 200, width: 1000, height: 500),
            depth: 64,
            lengthPercent: 30
        )
        expect(frames.count == 1)
        let frame = frames[0]

        expect(frame.minX, equals: 100)
        expect(frame.maxX, equals: 164)
        expect(frame.minY, equals: 375)
        expect(frame.maxY, equals: 525)
    }

    private static func testActivationZoneWrapsAroundCorner() {
        let zone = SnapZone(
            name: "Corner",
            triggerX: 0,
            triggerY: 0,
            targetX: 0,
            targetY: 0,
            targetWidth: 50,
            targetHeight: 50
        )
        let display = CGRect(x: 100, y: 200, width: 1000, height: 500)
        let frames = zone.activationFrames(
            in: display,
            depth: 64,
            lengthPercent: 30
        )

        expect(frames.count == 2)
        expect(frames.contains { abs($0.minX - 100) < 0.001 && abs($0.maxY - 700) < 0.001 })
        expect(frames.contains { abs($0.minY - 636) < 0.001 && abs($0.minX - 100) < 0.001 })

        let fromLeftLeg = HotspotMatcher.closestZone(
            to: CGPoint(x: 130, y: 650),
            in: display,
            zones: [zone],
            lengthPercent: 30
        )
        let fromTopLeg = HotspotMatcher.closestZone(
            to: CGPoint(x: 200, y: 680),
            in: display,
            zones: [zone],
            lengthPercent: 30
        )
        expect(fromLeftLeg?.id == zone.id)
        expect(fromTopLeg?.id == zone.id)
    }

    private static func testTargetFrameUsesTopLeftPercentages() {
        let zone = SnapZone(
            name: "Test",
            triggerX: 0,
            triggerY: 0,
            targetX: 25,
            targetY: 10,
            targetWidth: 50,
            targetHeight: 40
        )
        let frame = zone.targetFrame(in: CGRect(x: 100, y: 200, width: 1000, height: 500))

        expect(frame.origin.x, equals: 350)
        expect(frame.origin.y, equals: 450)
        expect(frame.width, equals: 500)
        expect(frame.height, equals: 200)
    }

    private static func testDisplayWidthConditionsTreatZeroAsUnbounded() {
        let unrestricted = SnapZone.defaults[0]
        expect(unrestricted.isAvailable(forDisplayWidth: 800))
        expect(unrestricted.isAvailable(forDisplayWidth: 3000))

        let restricted = SnapZone(
            name: "Wide",
            triggerX: 0,
            triggerY: 0,
            targetX: 0,
            targetY: 0,
            targetWidth: 100,
            targetHeight: 100,
            minimumDisplayWidth: 1200,
            maximumDisplayWidth: 1800
        )
        expect(!restricted.isAvailable(forDisplayWidth: 1199))
        expect(restricted.isAvailable(forDisplayWidth: 1200))
        expect(restricted.isAvailable(forDisplayWidth: 1800))
        expect(!restricted.isAvailable(forDisplayWidth: 1801))
    }

    private static func testDisplayWidthShortcutConflictRanges() {
        var compact = SnapZone.defaults[0]
        compact.minimumDisplayWidth = 0
        compact.maximumDisplayWidth = 1199

        var wide = SnapZone.defaults[1]
        wide.minimumDisplayWidth = 1200
        wide.maximumDisplayWidth = 0

        expect(!compact.displayWidthAvailabilityOverlaps(with: wide))
        wide.minimumDisplayWidth = 1199
        expect(compact.displayWidthAvailabilityOverlaps(with: wide))
    }

    private static func testNormalizationKeepsDestinationInsideDisplay() {
        let zone = SnapZone(
            name: "Clamped",
            triggerX: -10,
            triggerY: 120,
            targetX: 80,
            targetY: 90,
            targetWidth: 50,
            targetHeight: 50,
            minimumDisplayWidth: -100,
            maximumDisplayWidth: -200
        )

        expect(zone.triggerX, equals: 0)
        expect(zone.triggerY, equals: 100)
        expect(zone.targetX, equals: 80)
        expect(zone.targetY, equals: 90)
        expect(zone.targetWidth, equals: 20)
        expect(zone.targetHeight, equals: 10)
        expect(zone.minimumDisplayWidth, equals: 0)
        expect(zone.maximumDisplayWidth, equals: 0)
    }

    private static func testFrameIsRepositionedInsideSmallDisplay() {
        let bounds = CGRect(x: 100, y: 50, width: 1000, height: 700)
        let corrected = WindowFrameGeometry.repositionedInside(
            CGRect(x: 900, y: 600, width: 300, height: 200),
            bounds: bounds
        )

        expect(corrected.minX, equals: 800)
        expect(corrected.maxX, equals: 1100)
        expect(corrected.minY, equals: 550)
        expect(corrected.maxY, equals: 750)
        expect(WindowFrameGeometry.isInside(corrected, bounds: bounds))

        let correctedLeft = WindowFrameGeometry.repositionedInside(
            CGRect(x: 20, y: 30, width: 400, height: 300),
            bounds: bounds
        )
        expect(correctedLeft.minX, equals: 100)
        expect(correctedLeft.minY, equals: 50)
        expect(WindowFrameGeometry.isInside(correctedLeft, bounds: bounds))
    }

    private static func testFrameMapsProportionallyBetweenDisplays() {
        let mapped = WindowFrameGeometry.mappedProportionally(
            CGRect(x: 500, y: 250, width: 1000, height: 500),
            from: CGRect(x: 0, y: 0, width: 2000, height: 1000),
            to: CGRect(x: 100, y: 50, width: 1000, height: 800)
        )

        expect(mapped.minX, equals: 350)
        expect(mapped.minY, equals: 250)
        expect(mapped.width, equals: 500)
        expect(mapped.height, equals: 400)
    }

    private static func testShortcutKeysNormalizeAndDecodeFromOlderData() {
        expect(SnapZone.normalizedShortcutKey("G") == "g")
        expect(SnapZone.normalizedShortcutKey("12") == "2")
        expect(SnapZone.normalizedShortcutKey("!") == nil)

        let legacyJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Legacy",
          "triggerX": 0,
          "triggerY": 50,
          "targetX": 0,
          "targetY": 0,
          "targetWidth": 50,
          "targetHeight": 100,
          "minimumDisplayWidth": 0,
          "maximumDisplayWidth": 0
        }
        """
        let decoded = try? JSONDecoder().decode(SnapZone.self, from: Data(legacyJSON.utf8))
        expect(decoded?.name == "Legacy")
        expect(decoded?.shortcutKey == nil)
    }

    private static func testShortcutModeStateMachine() {
        var mode = ShortcutModeState()
        expect(!mode.handle(.zoneKey("1")))
        expect(mode.handle(.activate))
        expect(mode.isArmed)
        expect(mode.handle(.move(.right)))
        expect(mode.isArmed)
        expect(mode.handle(.zoneKey("1")))
        expect(!mode.isArmed)

        expect(mode.handle(.activate))
        expect(mode.handle(.cancel))
        expect(!mode.isArmed)
    }

    private static func testDirectionalScreenSelection() {
        let frames = [
            CGRect(x: 0, y: 0, width: 1000, height: 800),
            CGRect(x: 1000, y: 100, width: 800, height: 600),
            CGRect(x: 0, y: 800, width: 1000, height: 700),
            CGRect(x: 1900, y: 900, width: 700, height: 500)
        ]

        expect(ScreenLayoutGeometry.neighborIndex(from: 0, direction: .right, frames: frames) == 1)
        expect(ScreenLayoutGeometry.neighborIndex(from: 0, direction: .up, frames: frames) == 2)
        expect(ScreenLayoutGeometry.neighborIndex(from: 0, direction: .left, frames: frames) == nil)
        expect(ScreenLayoutGeometry.neighborIndex(from: 2, direction: .down, frames: frames) == 0)
    }

    private static func testNewZonesHaveIndependentIdentifiers() {
        let first = SnapZone.newZone
        let second = SnapZone.newZone

        expect(first.id != second.id)
    }

    private static func testDuplicateZoneIdentifiersAreRepaired() {
        let first = SnapZone.newZone
        var duplicate = SnapZone.newZone
        duplicate.id = first.id

        let repaired = SnapZone.repairingDuplicateIdentifiers(in: [first, duplicate])

        expect(repaired.count == 2)
        expect(repaired[0].id == first.id)
        expect(repaired[1].id != first.id)
        expect(Set(repaired.map(\.id)).count == repaired.count)
    }

    private static func testZoneStoreAddsEditsAndRemovesIndependentZones() {
        let suiteName = "com.isaac.snappy.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            expect(false)
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ZoneStore(defaults: defaults)
        let firstID = store.add()
        let secondID = store.add()
        expect(firstID != secondID)

        guard var first = store.zone(withID: firstID) else {
            expect(false)
            return
        }
        first.name = "Edited independently"
        store.replace(first)

        expect(store.zone(withID: firstID)?.name == "Edited independently")
        expect(store.zone(withID: secondID)?.name != "Edited independently")

        store.remove(id: firstID)
        expect(store.zone(withID: firstID) == nil)
        expect(store.zone(withID: secondID) != nil)
    }

    private static func testClosestOverlappingHotspotWins() {
        let first = SnapZone(
            name: "First",
            triggerX: 0,
            triggerY: 45,
            targetX: 0,
            targetY: 0,
            targetWidth: 50,
            targetHeight: 100
        )
        let second = SnapZone(
            name: "Second",
            triggerX: 0,
            triggerY: 55,
            targetX: 50,
            targetY: 0,
            targetWidth: 50,
            targetHeight: 100
        )
        let display = CGRect(x: 0, y: 0, width: 1000, height: 500)

        let closest = HotspotMatcher.closestZone(
            to: CGPoint(x: 32, y: 235),
            in: display,
            zones: [first, second],
            lengthPercent: 30
        )
        expect(closest?.id == second.id)

        let outside = HotspotMatcher.closestZone(
            to: CGPoint(x: 100, y: 235),
            in: display,
            zones: [first, second],
            lengthPercent: 30
        )
        expect(outside == nil)
    }

    private static func expect(
        _ actual: CGFloat,
        equals expected: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        expect(abs(actual - expected) < 0.001, file: file, line: line)
    }

    private static func expect(
        _ actual: Double,
        equals expected: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        expect(abs(actual - expected) < 0.001, file: file, line: line)
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard condition() else {
            fputs("Check failed at \(file):\(line)\n", stderr)
            exit(1)
        }
    }
}
