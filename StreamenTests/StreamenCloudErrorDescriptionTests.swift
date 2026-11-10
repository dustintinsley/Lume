import Foundation
@testable import Streamen
import StreamenCloudKit
import Testing

struct StreamenCloudErrorDescriptionTests {
    private static let everyCase: [StreamenCloudError] = [
        .badRequest(message: "rid 7f3a rejected"),
        .badAuth,
        .deviceRevoked,
        .signupClosed,
        .accountDeleted,
        .notFound,
        .accountExists,
        .pairingAlreadySealed,
        .resyncRequired,
        .recordTooLarge,
        .rateLimited(retryAfter: 30),
        .quotaExceeded,
        .server(status: 503, code: "unavailable"),
        .transport(URLError(.timedOut)),
        .decoding("missing key seq at changes.0"),
        .missingCredentials
    ]

    @Test func `every case has a sentence and a log detail`() {
        for error in Self.everyCase {
            #expect(!StreamenCloudErrorDescription.message(for: error).isEmpty, "\(error)")
            #expect(!StreamenCloudErrorDescription.logDetail(for: error).isEmpty, "\(error)")
        }
    }

    @Test func `account errors read as their own sentence, not the generic fallback`() {
        let errors: [StreamenCloudAccountError] = [
            .unavailable, .notJoined, .alreadyJoined, .keychainUnavailable, .invalidPairingCode, .pairingExpired,
            .pairingFailed, .serverMismatch, .cannotRevokeCurrentDevice, .invalidRecoveryKey, .recoveryKeyTypo,
            .wrongRecoveryKey
        ]
        let fallback = LogRedaction.scrubURLs(in: (StreamenCloudAccountError.pairingExpired as any Error).localizedDescription)
        for error in errors {
            let message = StreamenCloudErrorDescription.message(for: error as any Error)
            #expect(!message.isEmpty && message != fallback, "\(error)")
        }
        #expect(StreamenCloudErrorDescription.message(for: StreamenCloudAccountError.pairingExpired as any Error)
            == StreamenCloudErrorDescription.message(for: StreamenCloudError.notFound))
    }

    @Test func `states shared with the status row read the same`() {
        #expect(StreamenCloudErrorDescription.message(for: .quotaExceeded) == "Streamen Cloud storage is full. New changes stay on this device.")
        #expect(StreamenCloudErrorDescription.message(for: .rateLimited(retryAfter: nil)) == "Streamen Cloud is busy. Sync will retry automatically.")
        #expect(StreamenCloudErrorDescription.message(for: .transport(URLError(.notConnectedToInternet)))
            == "Streamen Cloud can’t be reached. Sync resumes automatically.")
    }

    @Test func `an existing account points to joining instead`() {
        let message = "This account already exists. Join with a code or your recovery key instead."
        #expect(StreamenCloudErrorDescription.message(for: .accountExists) == message)
        #expect(StreamenCloudErrorDescription.actionMessage(for: StreamenCloudError.accountExists) == message)
        #expect(StreamenCloudErrorDescription.logDetail(for: .accountExists) == "accountExists")
    }

    @Test func `one-off actions ask to try again instead of promising a retry`() {
        let tryAgain = "Streamen Cloud can’t be reached right now. Try again in a moment."
        #expect(StreamenCloudErrorDescription.actionMessage(for: StreamenCloudError.transport(URLError(.notConnectedToInternet))) == tryAgain)
        #expect(StreamenCloudErrorDescription.actionMessage(for: StreamenCloudError.server(status: 503, code: "unavailable")) == tryAgain)
        #expect(StreamenCloudErrorDescription.actionMessage(for: StreamenCloudError.rateLimited(retryAfter: 5))
            == "Streamen Cloud is busy. Try again in a moment.")
        #expect(StreamenCloudErrorDescription.actionMessage(for: StreamenCloudError.signupClosed)
            == StreamenCloudErrorDescription.message(for: .signupClosed))
        #expect(StreamenCloudErrorDescription.actionMessage(for: StreamenCloudAccountError.notJoined)
            == StreamenCloudErrorDescription.message(for: StreamenCloudAccountError.notJoined))
    }

    @Test func `the server's free text never reaches either rendering`() {
        let error = StreamenCloudError.badRequest(message: "rid 7f3a rejected for acct_fictional01")
        #expect(!StreamenCloudErrorDescription.message(for: error).contains("acct_fictional01"))
        #expect(StreamenCloudErrorDescription.logDetail(for: error) == "badRequest")
    }

    @Test func `log detail names status, code and retry delay`() {
        #expect(StreamenCloudErrorDescription.logDetail(for: .server(status: 503, code: "unavailable"))
            == "server(status: 503, code: unavailable)")
        #expect(StreamenCloudErrorDescription.logDetail(for: .server(status: 502, code: nil)) == "server(status: 502, code: none)")
        #expect(StreamenCloudErrorDescription.logDetail(for: .rateLimited(retryAfter: 1.2)) == "rateLimited(retryAfter: 2s)")
        #expect(StreamenCloudErrorDescription.logDetail(for: .transport(URLError(.timedOut))) == "transport(NSURLErrorDomain -1001)")
        #expect(StreamenCloudErrorDescription.logDetail(for: .deviceRevoked) == "deviceRevoked")
        #expect(StreamenCloudErrorDescription.logDetail(for: .pairingAlreadySealed) == "pairingAlreadySealed")
    }

    @Test func `an unexpected server code is reduced to identifier characters`() {
        let detail = StreamenCloudErrorDescription.logDetail(for: .server(status: 500, code: "oops Bearer abc.def https://x.test/"))
        #expect(detail == "server(status: 500, code: oopsBearerabcdefhttpsxtest)")
    }

    @Test func `other errors fall back to a redacted rendering`() {
        let error = NSError(domain: "TestDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: "failed at https://cloud.example.test/v1/x"])
        #expect(StreamenCloudErrorDescription.message(for: error) == "failed at https://<redacted>")
        #expect(StreamenCloudErrorDescription.logDetail(for: error) == "TestDomain 3: failed at https://<redacted>")
    }

    @Test func `server kind names the build's server without its address`() throws {
        #expect(StreamenCloudConfig.serverKind(for: StreamenCloudConfig.streamenURL) == .official)
        #expect(StreamenCloudConfig.serverKind(for: StreamenCloudAPI.stagingURL) == .staging)
        #expect(try StreamenCloudConfig.serverKind(for: #require(URL(string: "https://cloud.streamen.app/"))) == .official)
        #expect(StreamenCloudConfig.serverKind(for: StreamenCloudAPI.officialURL) == .official)
        #expect(try StreamenCloudConfig.serverKind(for: #require(URL(string: "https://sync.example.test"))) == .custom)
    }
}
