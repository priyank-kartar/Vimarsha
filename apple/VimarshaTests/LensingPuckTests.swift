import Testing
import CoreGraphics
@testable import Vimarsha

/// Geometry of the lensing drag puck (glass moment #2 / motion grammar #6). The puck is a
/// pure function of the active drag location + speed → where to draw the glass drop, how
/// big, how visible. No state, no time: fully scrubbable, deterministic.
@Suite("LensingPuck — drag-tracking geometry")
struct LensingPuckTests {
    private let bounds = CGSize(width: 400, height: 800)

    @Test("hidden default is fully transparent")
    func hiddenIsInvisible() {
        #expect(LensingPuck.hidden.opacity == 0)
    }

    @Test("an active drag yields a fully-visible puck")
    func activeDragIsVisible() {
        let puck = LensingPuck.at(location: CGPoint(x: 200, y: 400), in: bounds)
        #expect(puck.opacity == 1)
        #expect(puck.diameter == LensingPuck.baseDiameter)
    }

    @Test("puck lifts above the touch point so the finger doesn't occlude it")
    func liftsAboveTouch() {
        let location = CGPoint(x: 200, y: 400)
        let puck = LensingPuck.at(location: location, in: bounds)
        #expect(puck.center.x == location.x)
        #expect(puck.center.y == location.y - LensingPuck.lift)
    }

    @Test("clamps fully inside bounds near every edge")
    func clampsInsideBounds() {
        let r = LensingPuck.baseDiameter / 2
        // Near the top — the lift would push it off-screen; clamp to the radius.
        #expect(LensingPuck.at(location: CGPoint(x: 200, y: 10), in: bounds).center.y == r)
        // Left edge.
        #expect(LensingPuck.at(location: CGPoint(x: 5, y: 400), in: bounds).center.x == r)
        // Right edge.
        #expect(LensingPuck.at(location: CGPoint(x: 395, y: 400), in: bounds).center.x == bounds.width - r)
        // Bottom edge.
        #expect(LensingPuck.at(location: CGPoint(x: 200, y: 795), in: bounds).center.y == bounds.height - r)
    }

    @Test("faster drag swells the lens (velocity-reactive, grammar #6)")
    func speedSwellsLens() {
        let still = LensingPuck.at(location: CGPoint(x: 200, y: 400), dragSpeed: 0, in: bounds)
        let fast = LensingPuck.at(location: CGPoint(x: 200, y: 400), dragSpeed: 400, in: bounds)
        #expect(fast.diameter > still.diameter)
        #expect(still.diameter == LensingPuck.baseDiameter)
    }

    @Test("lens diameter is clamped at the maximum on a hard flick")
    func diameterClampedAtMax() {
        let flick = LensingPuck.at(location: CGPoint(x: 200, y: 400), dragSpeed: 100_000, in: bounds)
        #expect(flick.diameter == LensingPuck.maxDiameter)
    }

    @Test("degenerate bounds smaller than the puck don't crash or invert")
    func degenerateBounds() {
        let tiny = CGSize(width: 20, height: 20)
        let puck = LensingPuck.at(location: CGPoint(x: 10, y: 10), in: tiny)
        let r = LensingPuck.baseDiameter / 2
        #expect(puck.center.x == r)
        #expect(puck.center.y == r)
    }
}
