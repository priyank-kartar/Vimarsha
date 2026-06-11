import Testing
@testable import Vimarsha

/// V19 — the pure transport rules behind the glass cluster.
struct TransportTests {
    @Test func rateLadderCyclesAndWraps() {
        #expect(Transport.nextRate(after: 1.0) == 1.25)
        #expect(Transport.nextRate(after: 1.75) == 2.0)
        #expect(Transport.nextRate(after: 2.0) == 0.75)  // wraps to the bottom
    }

    @Test func offLadderRateRecoversToTheLadder() {
        #expect(Transport.nextRate(after: 3.7) == 1.25)
    }

    @Test func clockFormatsMinutesAndHours() {
        #expect(Transport.timeString(ms: 0) == "0:00")
        #expect(Transport.timeString(ms: 7_000) == "0:07")
        #expect(Transport.timeString(ms: 205_000) == "3:25")
        #expect(Transport.timeString(ms: 3_723_000) == "1:02:03")
        #expect(Transport.timeString(ms: -500) == "0:00")  // clamps
    }

    @Test func rateLabelsReadLikeSpeedChips() {
        #expect(Transport.rateLabel(1.0) == "1×")
        #expect(Transport.rateLabel(1.25) == "1.25×")
        #expect(Transport.rateLabel(1.5) == "1.5×")
        #expect(Transport.rateLabel(2.0) == "2×")
    }
}
