//
//  StreamenCloudBackendTestSupport.swift
//  StreamenTests
//
//  Shared setup for the `StreamenCloudBackend` suites: a backend over an in-memory
//  Streamen Cloud store (`cloudKitDatabase: .none`), a throwaway defaults suite, its
//  own keychain service, and `StubStreamenCloudAccountServer` instead of the network.
//

import Foundation
@testable import Streamen
import StreamenCloudKit
import SwiftData

/// Records what a backend reports to the coordinator.
@MainActor
final class StubSyncBackendHost: SyncBackendHost {
    let status = CloudSyncStatus()
    private(set) var reconciles: [ReconcileReason] = []
    private(set) var settledCount = 0

    func reconcile(reason: ReconcileReason, debounced _: Bool) {
        reconciles.append(reason)
    }

    func backendDidSettleInitialSync() {
        settledCount += 1
    }
}

/// One simulated Apple ID's worth of Streamen Cloud devices. Every device of a
/// fixture shares the keychain service, as iCloud Keychain would.
@MainActor
struct StreamenCloudBackendFixture {
    let server = StubStreamenCloudAccountServer()
    let keyStore: StreamenCloudKeyStore

    init(keychainService: String) {
        keyStore = StreamenCloudKeyStore(service: keychainService)
        keyStore.clear()
    }

    nonisolated static func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "streamencloud.backend.tests.\(UUID().uuidString)")!
    }

    func makeBackend(
        defaults: UserDefaults = makeDefaults(),
        serverURL: URL = StreamenCloudAPI.stagingURL,
        isInert: Bool = false
    ) throws -> StreamenCloudBackend {
        try StreamenCloudBackend(
            container: StreamenApp.makeStreamenCloudContainer(isStoredInMemoryOnly: true),
            serverURL: serverURL,
            defaults: defaults,
            keyStore: keyStore,
            isInert: isInert,
            pairingPollInterval: .milliseconds(10),
            eventBackoff: StreamenCloudEventListener.Backoff(initial: .milliseconds(5), maximum: .milliseconds(20)),
            makeClient: server.factory
        )
    }

    /// A backend that created an account.
    func makeJoinedBackend(defaults: UserDefaults = makeDefaults()) async throws -> (StreamenCloudBackend, recoveryKey: String) {
        let backend = try makeBackend(defaults: defaults)
        let recoveryKey = try await backend.createAccount()
        return (backend, recoveryKey)
    }
}
