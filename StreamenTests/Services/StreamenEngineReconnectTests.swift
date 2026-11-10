import Foundation
@testable import Streamen
import Testing

// `StreamenEngineFailure.init(_:)` itself isn't covered here: the test bundle
// doesn't link StreamenEngine, so it can't build an `EngineError`.

/// Outcomes, not stopwatch readings: under a loaded parallel run the main
/// actor can stall for seconds, so elapsed-time bounds fail spuriously.
@MainActor
struct StreamenEngineShutdownWaitTests {
    @Test func `opens right after a shutdown that finishes quickly`() async {
        let shutdown = Task<Void, Never> {}
        // A grace no stall reaches: only the shutdown finishing can open the gate.
        #expect(await StreamenEngineCoordinator.waitForShutdown(shutdown, grace: .seconds(600)) == false)
    }

    @Test func `stops waiting for a shutdown that hangs once the grace period passes`() async {
        let shutdown = Task<Void, Never> { try? await Task.sleep(for: .seconds(600)) }
        defer { shutdown.cancel() }
        let start = ContinuousClock.now
        let timedOut = await StreamenEngineCoordinator.waitForShutdown(shutdown, grace: .milliseconds(200))
        #expect(timedOut)
        #expect(ContinuousClock.now - start >= .milliseconds(200))
    }

    @Test func `the default grace is short`() {
        #expect(StreamenEngineCoordinator.shutdownGrace <= .seconds(3))
    }

    @Test func `nothing to wait for without a previous session`() async {
        #expect(await StreamenEngineCoordinator.waitForShutdown(nil) == false)
    }
}

@MainActor
struct PlaybackRetryPaceTests {
    @Test func `an overloaded source waits longer before every attempt`() {
        let normal = PlaybackRetryController.Pace.normal.schedule
        let overloaded = PlaybackRetryController.Pace.overloaded.schedule
        #expect(zip(normal, overloaded).allSatisfy { $0 < $1 })
    }

    @Test func `both paces spend the same attempt budget`() {
        #expect(PlaybackRetryController.Pace.overloaded.schedule.count == PlaybackRetryController.Pace.normal.schedule.count)
    }
}
