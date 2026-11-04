//
//  SyncBackendChoiceTests.swift
//  StreamenTests
//
//  The first-run sync choice over in-memory stores and
//  `StubStreamenCloudAccountServer`: only a fresh install asks, sync stays Off
//  and the launch gate closed while it does, each choice is stored and hands
//  the gate to the chosen backend's first sync, and the Apple-wide Streamen Cloud
//  record is offered there instead of followed. No CloudKit, no network.
//
//  The switches run real engine passes, which read the keychain PIN, so the
//  tests live in an extension of the `.serialized` `CloudSyncParentalEngineTests`
//  suite (see SyncBackendSwitchTests).
//

import Foundation
@testable import Streamen
import StreamenCloudKit
import SwiftData
import Testing

@MainActor
private struct SetupHarness {
    nonisolated static let serverURL = StreamenCloudAPI.stagingURL

    let catalog: ModelContainer
    /// The iCloud `CloudUserData` store: the mirror plus the record.
    let iCloudMirror: ModelContainer
    let defaults: UserDefaults
    let fixture = StreamenCloudBackendFixture(keychainService: "streamen.cloud.tests.backend-setup")

    init() throws {
        catalog = try makeTestContainer()
        iCloudMirror = try makeICloudMirrorTestContainer(extraModels: [SyncedBackendChoice.self])
        defaults = StreamenCloudBackendFixture.makeDefaults()
    }

    var settings: StreamenCloudSettings {
        StreamenCloudSettings(defaults: defaults)
    }

    /// A launch as `StreamenApp` makes it.
    func launch(offer: CloudSyncCoordinator.BackendChoiceOffer = .freshInstall) -> CloudSyncCoordinator {
        CloudSyncCoordinator(
            catalogContainer: catalog,
            cloudContainer: iCloudMirror,
            cloudKitContainerIdentifier: "iCloud.test.setup",
            cloudKitEnabled: false,
            backendChoice: offer,
            defaults: defaults
        )
    }

    /// A fresh install behind the choice, with a Streamen Cloud backend to join.
    func launchAwaitingChoice() throws -> (CloudSyncCoordinator, StreamenCloudBackend) {
        let streamenCloud = try fixture.makeBackend(defaults: defaults)
        let coordinator = CloudSyncCoordinator(
            catalogContainer: catalog,
            cloudContainer: iCloudMirror,
            backend: OffBackend(),
            iCloudBackend: ICloudBackend(mirrorContainer: iCloudMirror, cloudKitContainerIdentifier: "iCloud.test.setup", cloudKitEnabled: false),
            makeStreamenCloudBackend: { streamenCloud },
            awaitingBackendChoice: true,
            defaults: defaults
        )
        return (coordinator, streamenCloud)
    }

    func makeWatcher(for coordinator: CloudSyncCoordinator) -> SyncedBackendChoiceWatcher {
        SyncedBackendChoiceWatcher(
            coordinator: coordinator,
            container: iCloudMirror,
            isEnabled: true,
            serverURL: Self.serverURL,
            keyStore: fixture.keyStore
        )
    }

    func insertPlaylist() throws {
        let context = ModelContext(catalog)
        context.insert(Playlist(name: "Fictional TV", serverURL: "http://x", username: "u", password: "p"))
        try context.save()
    }

    func insertChoice(_ backend: SyncedBackendChoice.Backend, serverURL: URL = SetupHarness.serverURL, identity: StreamenCloudIdentity) throws {
        let context = ModelContext(iCloudMirror)
        context.insert(SyncedBackendChoice(
            backend: backend,
            serverURL: serverURL.absoluteString,
            accountId: identity.accountId,
            rootKey: identity.rootKey,
            changedAt: Date()
        ))
        try context.save()
    }

    func choices() throws -> [SyncedBackendChoice] {
        try ModelContext(iCloudMirror).fetch(FetchDescriptor<SyncedBackendChoice>())
    }
}

@MainActor
private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0 ..< 200 where !condition() {
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(condition())
}

extension CloudSyncParentalEngineTests {
    @Test func `a fresh install starts Off behind the sync choice with the launch gate closed`() throws {
        let harness = try SetupHarness()

        let coordinator = harness.launch()

        #expect(coordinator.status.isAwaitingBackendChoice)
        #expect(coordinator.selectedBackend == .off)
        #expect(!coordinator.status.isLaunchGateOpen)
        #expect(!harness.settings.hasStoredBackend)
    }

    @Test func `an install from before the choice keeps its backend and stores it`() throws {
        let harness = try SetupHarness()
        try harness.insertPlaylist()

        let coordinator = harness.launch()

        #expect(!coordinator.status.isAwaitingBackendChoice)
        #expect(coordinator.selectedBackend == .icloud)
        #expect(harness.settings.hasStoredBackend)
        #expect(harness.settings.backend == .icloud)
    }

    @Test func `a stored backend never asks again, even with an empty catalog`() throws {
        let harness = try SetupHarness()
        harness.settings.backend = .off

        #expect(!harness.launch().status.isAwaitingBackendChoice)
        #expect(!harness.launch(offer: .never).status.isAwaitingBackendChoice)
        #expect(harness.launch(offer: .always).status.isAwaitingBackendChoice)
    }

    @Test func `choosing iCloud stores it and opens the gate once nothing is left to wait for`() async throws {
        let harness = try SetupHarness()
        let coordinator = harness.launch()

        try await coordinator.chooseInitialBackend(.icloud)

        #expect(coordinator.selectedBackend == .icloud)
        #expect(harness.settings.backend == .icloud)
        #expect(!coordinator.status.isAwaitingBackendChoice)
        #expect(coordinator.status.isLaunchGateOpen)
    }

    @Test func `choosing not to sync stores Off and opens the gate`() async throws {
        let harness = try SetupHarness()
        let coordinator = harness.launch()

        try await coordinator.chooseInitialBackend(.off)

        #expect(coordinator.selectedBackend == .off)
        #expect(harness.settings.hasStoredBackend)
        #expect(harness.settings.backend == .off)
        #expect(coordinator.status.isLaunchGateOpen)
    }

    @Test func `choosing Streamen Cloud needs an account flow`() async throws {
        let harness = try SetupHarness()
        let coordinator = harness.launch()

        await #expect(throws: SyncBackendSwitchError.notJoined) {
            try await coordinator.chooseInitialBackend(.streamencloud)
        }
        #expect(coordinator.status.isAwaitingBackendChoice)
        #expect(!harness.settings.hasStoredBackend)
    }

    @Test func `a new Streamen Cloud account keeps the choice up until its flow closes, then waits for the first pass`() async throws {
        let harness = try SetupHarness()
        let (coordinator, streamenCloud) = try harness.launchAwaitingChoice()
        let model = SyncSetupModel(selection: .streamencloud)

        _ = try await coordinator.createStreamenCloudAccount()
        model.flow = .recoveryKey("fictional-key")
        model.backendDidChange(using: coordinator)

        #expect(coordinator.selectedBackend == .streamencloud)
        #expect(harness.settings.backend == .streamencloud)
        #expect(coordinator.status.isAwaitingBackendChoice)

        model.flowDidClose(using: coordinator)

        #expect(!coordinator.status.isAwaitingBackendChoice)
        try await waitUntil { coordinator.status.isLaunchGateOpen }
        #expect(streamenCloud.isJoined)
    }

    @Test func `a cancelled Streamen Cloud flow leaves the choice up and sync Off`() throws {
        let harness = try SetupHarness()
        let (coordinator, _) = try harness.launchAwaitingChoice()
        let model = SyncSetupModel(selection: .streamencloud)
        model.showsStreamenCloud = true
        model.flow = .join

        model.flowDidClose(using: coordinator)

        #expect(model.flow == nil)
        #expect(model.showsStreamenCloud)
        #expect(coordinator.status.isAwaitingBackendChoice)
        #expect(coordinator.selectedBackend == .off)
    }

    @Test func `while the choice is up the Apple-wide account is offered, not joined`() async throws {
        let harness = try SetupHarness()
        let (other, _) = try await harness.fixture.makeJoinedBackend()
        let identity = try #require(other.identity)
        try harness.insertChoice(.streamencloud, identity: identity)
        let (coordinator, streamenCloud) = try harness.launchAwaitingChoice()
        let watcher = harness.makeWatcher(for: coordinator)

        await watcher.start()

        #expect(coordinator.selectedBackend == .off)
        #expect(coordinator.offeredStreamenCloudAccount == identity)
        #expect(harness.fixture.server.devices(of: identity.accountId).count == 1)

        try await coordinator.joinOfferedStreamenCloudAccount()
        coordinator.finishBackendChoice()
        try await waitUntil { coordinator.status.isLaunchGateOpen }

        #expect(coordinator.selectedBackend == .streamencloud)
        #expect(streamenCloud.identity == identity)
        #expect(coordinator.offeredStreamenCloudAccount == nil)
        #expect(harness.fixture.server.devices(of: identity.accountId).count == 2)
        #expect(try harness.choices().map(\.accountId) == [identity.accountId])
    }

    @Test func `an Apple-wide account on another server is not offered`() async throws {
        let harness = try SetupHarness()
        let (other, _) = try await harness.fixture.makeJoinedBackend()
        try harness.insertChoice(.streamencloud, serverURL: StreamenCloudAPI.officialURL, identity: #require(other.identity))
        let (coordinator, _) = try harness.launchAwaitingChoice()

        await harness.makeWatcher(for: coordinator).start()

        #expect(coordinator.offeredStreamenCloudAccount == nil)
        #expect(coordinator.selectedBackend == .off)
    }
}
