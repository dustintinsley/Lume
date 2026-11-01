import Foundation
import StreamenCloudKit

/// Every Streamen Cloud call `StreamenCloudBackend` makes: the sync calls of
/// `StreamenCloudSyncing` plus accounts, devices and pairing. A seam over
/// `StreamenCloudClient` so the account flows are tested offline. Never retries.
nonisolated protocol StreamenCloudAccountAPI: StreamenCloudSyncing {
    func createAccount(keys: StreamenCloudKeys) async throws -> AccountCreated
    func deleteAccount() async throws
    func registerDevice(id: UUID, name: String, platform: StreamenCloudPlatform) async throws -> Device
    func devices() async throws -> [Device]
    func revokeDevice(id: UUID) async throws
    func startPairing(publicKey: String, deviceName: String, platform: StreamenCloudPlatform) async throws -> PairingTicket
    func pairingRequest(code: String) async throws -> PairingRequest
    func sealPairing(code: String, sealed: SealedGrant) async throws
    func pairingResult(code: String, pollToken: String) async throws -> PairingPollResult
}

/// Builds a client for one set of credentials; `nil` for the unauthenticated
/// calls (account creation, the new device's side of pairing).
typealias StreamenCloudClientFactory = @Sendable (StreamenCloudClient.Credentials?) -> any StreamenCloudAccountAPI

/// `StreamenCloudAccountAPI` over the real server, sharing the sync transport's
/// ephemeral session.
nonisolated struct LiveStreamenCloudAccountAPI: StreamenCloudAccountAPI {
    private let client: StreamenCloudClient
    private let socketClient: StreamenCloudClient

    init(baseURL: URL, credentials: StreamenCloudClient.Credentials?) {
        client = StreamenCloudClient(baseURL: baseURL, session: LiveStreamenCloudSyncing.session, credentials: credentials)
        socketClient = StreamenCloudClient(baseURL: baseURL, session: LiveStreamenCloudSyncing.socketSession, credentials: credentials)
    }

    static func factory(serverURL: URL) -> StreamenCloudClientFactory {
        { credentials in LiveStreamenCloudAccountAPI(baseURL: serverURL, credentials: credentials) }
    }

    func allChanges(since: Int, limit: Int?) async throws -> ChangesPage {
        try await client.allChanges(since: since, limit: limit)
    }

    func push(_ records: [PushRecord]) async throws -> PushResponse {
        try await client.push(records)
    }

    func changes(since: Int, limit: Int?) async throws -> ChangesPage {
        try await client.changes(since: since, limit: limit)
    }

    func events() -> AsyncThrowingStream<Int, Error> {
        socketClient.events()
    }

    func createAccount(keys: StreamenCloudKeys) async throws -> AccountCreated {
        try await client.createAccount(keys: keys)
    }

    func account() async throws -> AccountInfo {
        try await client.account()
    }

    func deleteAccount() async throws {
        try await client.deleteAccount()
    }

    func registerDevice(id: UUID, name: String, platform: StreamenCloudPlatform) async throws -> Device {
        try await client.registerDevice(id: id, name: name, platform: platform)
    }

    func devices() async throws -> [Device] {
        try await client.devices()
    }

    func revokeDevice(id: UUID) async throws {
        try await client.revokeDevice(id: id)
    }

    func startPairing(publicKey: String, deviceName: String, platform: StreamenCloudPlatform) async throws -> PairingTicket {
        try await client.startPairing(publicKey: publicKey, deviceName: deviceName, platform: platform)
    }

    func pairingRequest(code: String) async throws -> PairingRequest {
        try await client.pairingRequest(code: code)
    }

    func sealPairing(code: String, sealed: SealedGrant) async throws {
        try await client.sealPairing(code: code, sealed: sealed)
    }

    func pairingResult(code: String, pollToken: String) async throws -> PairingPollResult {
        try await client.pairingResult(code: code, pollToken: pollToken)
    }
}
