//
//  TMDBRateLimiter.swift
//  Streamen
//
//  One request budget for all of the app's TMDB traffic. The index pass is
//  almost all of it, but detail screens and Home share the same per-IP limit
//  at TMDB, so they share the same pacing here.
//

import Foundation

/// Spaces TMDB requests to a target rate and adapts that rate to what TMDB
/// accepts: a 429 halves it and pauses for a moment (or for `Retry-After`),
/// and each run of successful requests raises it a step, back up to the cap.
///
/// Requests reserve evenly spaced start times, so however many callers are
/// waiting (the index pass keeps several lookups in flight), the starts stay
/// at `rate` per second rather than arriving in bursts.
actor TMDBRateLimiter {
    static let shared = TMDBRateLimiter()

    struct Policy {
        /// Requests per second at the start and the most it climbs back to.
        /// TMDB's documented ceiling is around 50 a second per IP; staying
        /// below it leaves room for the rest of the household's traffic.
        var initialRate: Double = 35
        var maxRate: Double = 40
        /// The least a run of 429s can halve the rate to.
        var minRate: Double = 4
        /// How much the rate rises after each `successesPerStep` requests in
        /// a row that TMDB accepted.
        var increaseStep: Double = 1
        var successesPerStep = 25
        /// Pause after a 429 that carries no usable `Retry-After`, and the
        /// longest any 429 stops requests for.
        var cooldown: Duration = .seconds(1)
        var maxCooldown: Duration = .seconds(30)
    }

    typealias Instant = ContinuousClock.Instant

    private let policy: Policy
    private let now: @Sendable () -> Instant
    private let sleepUntil: @Sendable (Instant) async throws -> Void

    /// The current target, in requests per second.
    private(set) var rate: Double
    /// The earliest start time not yet handed out.
    private var nextSlot: Instant
    private var successesSinceChange = 0
    /// When the rate was last halved. The lookups already in flight when TMDB
    /// starts refusing all come back 429 together; that is one signal, so
    /// further 429s inside one cooldown extend the pause but don't halve again.
    private var lastCut: Instant?

    init(
        policy: Policy = Policy(),
        now: @escaping @Sendable () -> Instant = { ContinuousClock.now },
        sleepUntil: @escaping @Sendable (Instant) async throws -> Void = { try await Task.sleep(until: $0) }
    ) {
        self.policy = policy
        self.now = now
        self.sleepUntil = sleepUntil
        rate = policy.initialRate
        nextSlot = now()
    }

    private var interval: Duration {
        .seconds(1 / rate)
    }

    /// Waits for this request's turn. Throws only when the task is cancelled
    /// while waiting.
    func acquire() async throws {
        let current = now()
        let slot = max(current, nextSlot)
        nextSlot = slot + interval
        if slot > current {
            try await sleepUntil(slot)
        }
    }

    /// TMDB accepted a request.
    func recordSuccess() {
        guard rate < policy.maxRate else { return }
        successesSinceChange += 1
        if successesSinceChange >= policy.successesPerStep {
            rate = min(policy.maxRate, rate + policy.increaseStep)
            successesSinceChange = 0
        }
    }

    /// TMDB answered 429. Halves the rate (once per cooldown) and holds every
    /// request back for `retryAfter`, or the policy's cooldown without one.
    func recordRateLimited(retryAfter: Duration? = nil) {
        let current = now()
        let pause = min(policy.maxCooldown, max(retryAfter ?? policy.cooldown, .zero))
        if lastCut.map({ current >= $0 + policy.cooldown }) ?? true {
            rate = max(policy.minRate, rate / 2)
            lastCut = current
        }
        successesSinceChange = 0
        nextSlot = max(nextSlot, current + pause)
    }

    /// `Retry-After` in its delta-seconds form, which is what TMDB sends.
    nonisolated static func retryAfter(from response: HTTPURLResponse) -> Duration? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = Double(value.trimmingCharacters(in: .whitespaces)),
              seconds >= 0
        else { return nil }
        return .seconds(seconds)
    }
}
