//
//  TMDBRateLimiterTests.swift
//  StreamenTests
//
//  The shared TMDB pacing: requests start evenly spaced at the target rate, a
//  429 halves that rate (once per burst) and pauses, and accepted requests
//  climb it back up to the cap.
//

import Foundation
@testable import Streamen
import Testing

/// A clock the test moves: `sleepUntil` jumps straight to the instant asked
/// for and records it, so pacing is checked without real waiting.
private final nonisolated class FakeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = ContinuousClock.now
    private var sleptUntil: [ContinuousClock.Instant] = []
    let start: ContinuousClock.Instant

    init() {
        start = current
    }

    var now: ContinuousClock.Instant {
        lock.withLock { current }
    }

    func advance(by duration: Duration) {
        lock.withLock { current += duration }
    }

    func sleep(until instant: ContinuousClock.Instant) {
        lock.withLock {
            sleptUntil.append(instant)
            current = max(current, instant)
        }
    }

    /// Each recorded wake-up as an offset from the start, in milliseconds.
    var wakeOffsets: [Int] {
        lock.withLock { sleptUntil.map { Int(((($0 - start) / .milliseconds(1))).rounded()) } }
    }
}

private func makeLimiter(_ clock: FakeClock, policy: TMDBRateLimiter.Policy) -> TMDBRateLimiter {
    TMDBRateLimiter(policy: policy, now: { clock.now }, sleepUntil: { clock.sleep(until: $0) })
}

struct TMDBRateLimiterTests {
    private func policy(
        rate: Double = 10, max maxRate: Double = 12, min minRate: Double = 2, step: Int = 3
    ) -> TMDBRateLimiter.Policy {
        var policy = TMDBRateLimiter.Policy()
        policy.initialRate = rate
        policy.maxRate = maxRate
        policy.minRate = minRate
        policy.successesPerStep = step
        policy.cooldown = .seconds(1)
        policy.maxCooldown = .seconds(5)
        return policy
    }

    @Test func `requests start evenly spaced at the target rate`() async throws {
        let clock = FakeClock()
        let limiter = makeLimiter(clock, policy: policy(rate: 10))

        for _ in 0 ..< 4 {
            try await limiter.acquire()
        }

        // The first goes at once; the rest a tenth of a second apart.
        #expect(clock.wakeOffsets == [100, 200, 300])
    }

    @Test func `an idle limiter doesn't make the next request wait`() async throws {
        let clock = FakeClock()
        let limiter = makeLimiter(clock, policy: policy(rate: 10))

        try await limiter.acquire()
        clock.advance(by: .seconds(2))
        try await limiter.acquire()

        #expect(clock.wakeOffsets.isEmpty)
    }

    @Test func `a 429 halves the rate and holds requests for the cooldown`() async throws {
        let clock = FakeClock()
        let limiter = makeLimiter(clock, policy: policy(rate: 10))

        await limiter.recordRateLimited()
        #expect(await limiter.rate == 5)

        try await limiter.acquire() // held for the 1 s cooldown
        try await limiter.acquire() // then spaced at the halved rate
        #expect(clock.wakeOffsets == [1000, 1200])
    }

    @Test func `Retry-After sets the pause, capped at the longest cooldown`() async throws {
        let clock = FakeClock()
        let limiter = makeLimiter(clock, policy: policy())

        await limiter.recordRateLimited(retryAfter: .seconds(3))
        try await limiter.acquire()
        #expect(clock.wakeOffsets == [3000])

        await limiter.recordRateLimited(retryAfter: .seconds(60))
        try await limiter.acquire()
        #expect(clock.wakeOffsets.last == 3000 + 5000)
    }

    @Test func `429s from one burst halve the rate only once`() async {
        let clock = FakeClock()
        let limiter = makeLimiter(clock, policy: policy(rate: 16))

        // Every lookup in flight comes back refused at about the same time.
        for _ in 0 ..< 8 {
            await limiter.recordRateLimited()
        }
        #expect(await limiter.rate == 8)

        // A 429 after the cooldown is a new signal.
        clock.advance(by: .seconds(1))
        await limiter.recordRateLimited()
        #expect(await limiter.rate == 4)
    }

    @Test func `the rate never drops below the floor`() async {
        let clock = FakeClock()
        let limiter = makeLimiter(clock, policy: policy(rate: 10, min: 3))

        for _ in 0 ..< 6 {
            await limiter.recordRateLimited()
            clock.advance(by: .seconds(1))
        }

        #expect(await limiter.rate == 3)
    }

    @Test func `accepted requests raise the rate a step at a time up to the cap`() async {
        let clock = FakeClock()
        let limiter = makeLimiter(clock, policy: policy(rate: 10, max: 12, step: 3))

        for _ in 0 ..< 2 {
            await limiter.recordSuccess()
        }
        #expect(await limiter.rate == 10)

        await limiter.recordSuccess()
        #expect(await limiter.rate == 11)

        for _ in 0 ..< 30 {
            await limiter.recordSuccess()
        }
        #expect(await limiter.rate == 12)
    }

    @Test func `a 429 restarts the climb`() async {
        let clock = FakeClock()
        let limiter = makeLimiter(clock, policy: policy(rate: 10, step: 3))

        await limiter.recordSuccess()
        await limiter.recordSuccess()
        await limiter.recordRateLimited()
        await limiter.recordSuccess()
        await limiter.recordSuccess()

        // Two successes since the cut aren't yet a step.
        #expect(await limiter.rate == 5)
    }

    @Test func `Retry-After is read in seconds and ignored when unusable`() throws {
        func response(_ value: String?) throws -> HTTPURLResponse {
            let url = try #require(URL(string: "https://api.themoviedb.org/3/movie/1"))
            let headers = value.map { ["Retry-After": $0] } ?? [:]
            return try #require(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: headers))
        }

        #expect(try TMDBRateLimiter.retryAfter(from: response("2")) == .seconds(2))
        #expect(try TMDBRateLimiter.retryAfter(from: response(" 0.5 ")) == .milliseconds(500))
        #expect(try TMDBRateLimiter.retryAfter(from: response(nil)) == nil)
        #expect(try TMDBRateLimiter.retryAfter(from: response("Wed, 21 Oct 2026 07:28:00 GMT")) == nil)
        #expect(try TMDBRateLimiter.retryAfter(from: response("-1")) == nil)
    }
}

// MARK: - TMDBClient

/// Answers TMDB requests from a per-test script of status codes. Its own
/// class and state, so it never meets the shared stub other TMDB suites use.
private final nonisolated class ScriptedTMDBProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var scripts: [String: [Int]] = [:]
    private nonisolated(unsafe) static var counts: [String: Int] = [:]

    /// Each test uses its own movie id, which is how requests find their script.
    static func script(movieID: Int, statuses: [Int]) {
        lock.withLock { scripts["/3/movie/\(movieID)"] = statuses }
    }

    static func requestCount(movieID: Int) -> Int {
        lock.withLock { counts["/3/movie/\(movieID)"] ?? 0 }
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScriptedTMDBProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else { return }
        let path = url.path
        let status: Int = Self.lock.withLock {
            let index = Self.counts[path, default: 0]
            Self.counts[path] = index + 1
            let script = Self.scripts[path] ?? [200]
            return script[min(index, script.count - 1)]
        }
        let body = status == 200 ? Data(#"{"id":1,"overview":"Found."}"#.utf8) : Data()
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

struct TMDBClientRateLimitTests {
    /// A real limiter with no pause after a 429, so the retries run at once.
    private func makeClient() -> TMDBClient {
        var policy = TMDBRateLimiter.Policy()
        policy.cooldown = .zero
        return TMDBClient(
            session: ScriptedTMDBProtocol.makeSession(),
            token: "test-token",
            language: "en-US",
            rateLimiter: TMDBRateLimiter(policy: policy)
        )
    }

    @Test func `a 429 is retried after the back-off and the request succeeds`() async throws {
        ScriptedTMDBProtocol.script(movieID: 9101, statuses: [429, 200])

        let details = try await makeClient().movieDetails(9101)

        #expect(details.overview == "Found.")
        #expect(ScriptedTMDBProtocol.requestCount(movieID: 9101) == 2)
    }

    @Test func `a 429 that outlasts the retries is thrown to the caller`() async {
        ScriptedTMDBProtocol.script(movieID: 9102, statuses: [429])

        await #expect {
            try await makeClient().movieDetails(9102)
        } throws: { error in
            if case TMDBError.serverError(429) = error { return true }
            return false
        }
        #expect(ScriptedTMDBProtocol.requestCount(movieID: 9102) == 3)
    }

    @Test func `other server errors are not retried`() async {
        ScriptedTMDBProtocol.script(movieID: 9103, statuses: [500, 200])

        await #expect(throws: TMDBError.self) {
            try await makeClient().movieDetails(9103)
        }
        #expect(ScriptedTMDBProtocol.requestCount(movieID: 9103) == 1)
    }
}
