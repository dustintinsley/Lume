//
//  SyncBackendSwitchTests.swift
//  StreamenTests
//
//  `CloudSyncCoordinator.switchBackend(to:)` over in-memory stores and
//  `StubStreamenCloudAccountServer`: a switch carries mirror-only data and deletes
//  nothing, a Streamen Cloud rejoin starts from an empty mirror, user deletions
//  become tombstones, and a revoked device or a deleted account switches the
//  device away while keeping its data, and a launch starts on the backend
//  the device chose. No CloudKit, no network.
//
//  Every test runs real engine passes, which read the keychain PIN, so they
//  live in an extension of the `.serialized` `CloudSyncParentalEngineTests`
//  suite (see CloudSyncShadowNamespaceTests).
//

import Foundation
@testable import Streamen
import StreamenCloudKit
import SwiftData
import SwiftUI
import Synchronization
import Testing

@MainActor
private struct SwitchHarness {
    let catalog: ModelContainer
    let iCloudMirror: ModelContainer
    let defaults: UserDefaults
    let fixture = StreamenCloudBackendFixture(keychainService: "streamen.cloud.tests.backend-switch")
    let iCloud: ICloudBackend
    let playlistID: UUID
    let movieID: String

    init() throws {
        catalog = try makeTestContainer()
        iCloudMirror = try makeICloudMirrorTestContainer()
        defaults = StreamenCloudBackendFixture.makeDefaults()
        iCloud = ICloudBackend(mirrorContainer: iCloudMirror, cloudKitContainerIdentifier: "iCloud.test.switch", cloudKitEnabled: false)

        let context = catalog.mainContext
        let playlist = Playlist(name: "Fictional TV", serverURL: "http://x", username: "u", password: "p")
        context.insert(playlist)
        playlistID = playlist.id
        movieID = "\(playlist.id.uuidString)-movie-1"
        let movie = Movie(id: movieID, streamId: 1, name: "Film")
        movie.isFavorite = true
        context.insert(movie)
        try context.save()
    }

    func makeCoordinator(
        backend: any SyncBackend,
        streamenCloud: StreamenCloudBackend?,
        iCloudAvailable: Bool = true
    ) -> CloudSyncCoordinator {
        CloudSyncCoordinator(
            catalogContainer: catalog,
            cloudContainer: iCloudMirror,
            backend: backend,
            iCloudBackend: iCloudAvailable ? iCloud : nil,
            makeStreamenCloudBackend: {
                guard let streamenCloud else { throw SyncBackendSwitchError.unavailable }
                return streamenCloud
            },
            defaults: defaults
        )
    }

    func playlistCount() throws -> Int {
        try ModelContext(catalog).fetchCount(FetchDescriptor<Playlist>())
    }

    func isFavorite() throws -> Bool {
        let id = movieID
        return try ModelContext(catalog).fetch(FetchDescriptor<Movie>(predicate: #Predicate { $0.id == id })).first?.isFavorite == true
    }
}

@MainActor
private func runPass(_ coordinator: CloudSyncCoordinator) async throws {
    coordinator.status.lastReconcile = nil
    coordinator.reconcile(reason: .queued, debounced: false)
    try await waitUntil { coordinator.status.lastReconcile != nil }
}

@MainActor
private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0 ..< 200 where !condition() {
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(condition())
}

private func rows<Model: PersistentModel>(_: Model.Type, in container: ModelContainer) throws -> [Model] {
    try ModelContext(container).fetch(FetchDescriptor<Model>())
}

@MainActor
private func remoteRecord(_ logicalKey: String, of backend: StreamenCloudBackend, on server: StubStreamenCloudAccountServer) throws -> RemoteRecord? {
    let keys = try StreamenCloudKeys(rootKey: #require(backend.identity).rootKey)
    let rid = keys.recordID(for: logicalKey)
    return server.feed.state.withLock { $0.records[rid] }
}

extension CloudSyncParentalEngineTests {
    @Test func `switching to Streamen Cloud carries mirror-only data and deletes nothing`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let juniper = UUID()
        let mirror = ModelContext(harness.iCloudMirror)
        mirror.insert(UserProfile(id: juniper, name: "Juniper"))
        mirror.insert(UserContentState(contentId: "\(harness.playlistID.uuidString)-movie-9", kind: .movie, profileID: juniper, isFavorite: true))
        mirror.insert(SyncedSportsFollow(key: "soccer/team/fictional", profileID: juniper))
        mirror.insert(SyncedRecordingServer(name: "Attic Recorder", baseURL: "http://recorder.invalid"))
        try mirror.save()
        let coordinator = harness.makeCoordinator(backend: harness.iCloud, streamenCloud: streamenCloud)
        try await runPass(coordinator)

        // A stale `.streamencloud` baseline from an earlier session: without the
        // reset it reads the playlist and the favourite as deleted remotely.
        _ = try await CloudSyncEngine(
            catalogContainer: harness.catalog,
            cloudContainer: StreamenApp.makeStreamenCloudContainer(isStoredInMemoryOnly: true),
            shadow: CloudSyncShadow(defaults: harness.defaults, namespace: .streamencloud)
        ).reconcile()

        coordinator.status.lastReconcile = nil
        try await coordinator.switchBackend(to: .streamencloud)
        try await waitUntil { coordinator.status.lastReconcile != nil }

        #expect(coordinator.selectedBackend == .streamencloud)
        #expect(coordinator.engineNamespace == .streamencloud)
        #expect(coordinator.mirrorContainer === streamenCloud.container)
        #expect(StreamenCloudSettings(defaults: harness.defaults).backend == .streamencloud)
        #expect(try harness.playlistCount() == 1)
        #expect(try harness.isFavorite())
        let target = streamenCloud.container
        #expect(try rows(SyncedPlaylist.self, in: target).map(\.id) == [harness.playlistID])
        #expect(try rows(UserProfile.self, in: target).contains { $0.id == juniper && $0.name == "Juniper" })
        #expect(try rows(UserContentState.self, in: target).contains { $0.profileID == juniper && $0.isFavorite })
        #expect(try rows(SyncedSportsFollow.self, in: target).map(\.key) == ["soccer/team/fictional"])
        #expect(try rows(SyncedRecordingServer.self, in: target).map(\.name) == ["Attic Recorder"])
        // The dormant iCloud mirror is left as it was.
        #expect(try rows(UserProfile.self, in: harness.iCloudMirror).contains { $0.id == juniper })
        #expect(try rows(SyncedPlaylist.self, in: harness.iCloudMirror).count == 1)
    }

    @Test func `a Streamen Cloud rejoin empties its mirror and cursor before the first pass`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let stale = ModelContext(streamenCloud.container)
        stale.insert(SyncedPlaylist(
            id: UUID(), name: "Gone Elsewhere", serverURL: "http://y", username: "u", password: "p",
            sourceTypeRaw: "xtream", epgURL: nil, syncEnabled: true
        ))
        try stale.insert(StreamenCloudSyncMeta(nextSeq: 42, accountId: #require(streamenCloud.identity).accountId))
        try stale.save()
        let coordinator = harness.makeCoordinator(backend: harness.iCloud, streamenCloud: streamenCloud)

        coordinator.status.lastReconcile = nil
        try await coordinator.switchBackend(to: .streamencloud)
        try await waitUntil { coordinator.status.lastReconcile != nil }

        #expect(try harness.playlistCount() == 1)
        #expect(try rows(SyncedPlaylist.self, in: streamenCloud.container).map(\.id) == [harness.playlistID])
        #expect(harness.fixture.server.feed.requestedSince.last == 0)
    }

    @Test func `switching to Streamen Cloud without an account is refused`() async throws {
        let harness = try SwitchHarness()
        let streamenCloud = try harness.fixture.makeBackend(defaults: harness.defaults)
        let coordinator = harness.makeCoordinator(backend: harness.iCloud, streamenCloud: streamenCloud)

        await #expect(throws: SyncBackendSwitchError.notJoined) {
            try await coordinator.switchBackend(to: .streamencloud)
        }

        #expect(coordinator.selectedBackend == .icloud)
        #expect(StreamenCloudSettings(defaults: harness.defaults).backend == .icloud)
    }

    @Test func `deleting a playlist under Streamen Cloud sends tombstones for it and its content`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let server = harness.fixture.server
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud)
        try await runPass(coordinator)
        let playlistKey = StreamenCloudPayloadCodec.playlistKey(id: harness.playlistID)
        let contentKey = try #require(rows(UserContentState.self, in: streamenCloud.container).first).streamenCloudKey
        #expect(try remoteRecord(playlistKey, of: streamenCloud, on: server)?.deleted == false)
        #expect(try remoteRecord(contentKey, of: streamenCloud, on: server)?.deleted == false)

        await coordinator.deletePlaylist(id: harness.playlistID)
        try await runPass(coordinator)

        #expect(try harness.playlistCount() == 0)
        #expect(try remoteRecord(playlistKey, of: streamenCloud, on: server)?.deleted == true)
        #expect(try remoteRecord(contentKey, of: streamenCloud, on: server)?.deleted == true)
    }

    @Test func `deleting a profile under Streamen Cloud sends tombstones for its records only`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let server = harness.fixture.server
        let juniper = UUID()
        let willow = UUID()
        let mirror = ModelContext(streamenCloud.container)
        mirror.insert(UserProfile(id: juniper, name: "Juniper"))
        mirror.insert(UserContentState(contentId: "\(harness.playlistID.uuidString)-movie-7", kind: .movie, profileID: juniper, isWatched: true))
        mirror.insert(SyncedSportsFollow(key: "soccer/team/juniper", profileID: juniper))
        mirror.insert(SyncedSportsFollow(key: "soccer/team/willow", profileID: willow))
        try mirror.save()
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud)
        try await runPass(coordinator)
        let profileKey = StreamenCloudPayloadCodec.profileKey(id: juniper)
        let contentKey = StreamenCloudPayloadCodec.contentKey(profileID: juniper, contentId: "\(harness.playlistID.uuidString)-movie-7")
        let followKey = StreamenCloudPayloadCodec.sportsFollowKey(profileID: juniper, key: "soccer/team/juniper")
        let otherFollowKey = StreamenCloudPayloadCodec.sportsFollowKey(profileID: willow, key: "soccer/team/willow")
        #expect(try remoteRecord(profileKey, of: streamenCloud, on: server)?.deleted == false)

        await coordinator.deleteProfile(id: juniper)
        try await runPass(coordinator)

        #expect(try remoteRecord(profileKey, of: streamenCloud, on: server)?.deleted == true)
        #expect(try remoteRecord(contentKey, of: streamenCloud, on: server)?.deleted == true)
        #expect(try remoteRecord(followKey, of: streamenCloud, on: server)?.deleted == true)
        #expect(try remoteRecord(otherFollowKey, of: streamenCloud, on: server)?.deleted == false)
    }

    @Test func `a revoked device goes Off and keeps its data`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let identity = try #require(streamenCloud.identity)
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud)
        try await runPass(coordinator)
        let deviceID = StreamenCloudSettings(defaults: harness.defaults).deviceID
        harness.fixture.server.state.withLock { $0.devices[identity.accountId]?[deviceID]?.revoked = true }

        coordinator.reconcile(reason: .queued, debounced: false)
        try await waitUntil { coordinator.accountEndNotice != nil }

        #expect(coordinator.accountEndNotice == StreamenCloudAccountEndNotice(reason: .deviceRevoked, resultingBackend: .off))
        #expect(coordinator.selectedBackend == .off)
        #expect(StreamenCloudSettings(defaults: harness.defaults).backend == .off)
        #expect(StreamenCloudSettings(defaults: harness.defaults).deviceID != deviceID)
        #expect(!streamenCloud.isJoined)
        #expect(harness.fixture.keyStore.load() == .identity(identity))
        #expect(try harness.playlistCount() == 1)
        #expect(try harness.isFavorite())
        #expect(try rows(SyncedPlaylist.self, in: streamenCloud.container).count == 1)

        coordinator.dismissAccountEndNotice()
        #expect(coordinator.accountEndNotice == nil)
    }

    @Test func `a deleted account returns the device to iCloud with its data`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let accountId = try #require(streamenCloud.identity?.accountId)
        let juniper = UUID()
        let mirror = ModelContext(streamenCloud.container)
        mirror.insert(UserProfile(id: juniper, name: "Juniper"))
        try mirror.save()
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud)
        try await runPass(coordinator)
        harness.fixture.server.state.withLock { _ = $0.deletedAccounts.insert(accountId) }

        coordinator.reconcile(reason: .queued, debounced: false)
        try await waitUntil { coordinator.accountEndNotice != nil }
        try await waitUntil { (try? rows(SyncedPlaylist.self, in: harness.iCloudMirror))?.isEmpty == false }

        #expect(coordinator.accountEndNotice == StreamenCloudAccountEndNotice(reason: .accountDeleted, resultingBackend: .icloud))
        #expect(coordinator.selectedBackend == .icloud)
        #expect(coordinator.engineNamespace == .icloud)
        #expect(StreamenCloudSettings(defaults: harness.defaults).backend == .icloud)
        #expect(harness.fixture.keyStore.load() == .notSet)
        #expect(try harness.playlistCount() == 1)
        #expect(try harness.isFavorite())
        #expect(try rows(UserProfile.self, in: harness.iCloudMirror).contains { $0.id == juniper })

        coordinator.dismissAccountEndNotice()
        #expect(coordinator.accountEndNotice == nil)
    }

    @Test func `a deleted account goes Off where iCloud isn't available`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let accountId = try #require(streamenCloud.identity?.accountId)
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud, iCloudAvailable: false)
        try await runPass(coordinator)
        harness.fixture.server.state.withLock { _ = $0.deletedAccounts.insert(accountId) }

        coordinator.reconcile(reason: .queued, debounced: false)
        try await waitUntil { coordinator.accountEndNotice != nil }

        #expect(coordinator.accountEndNotice == StreamenCloudAccountEndNotice(reason: .accountDeleted, resultingBackend: .off))
        #expect(coordinator.selectedBackend == .off)
        #expect(StreamenCloudSettings(defaults: harness.defaults).backend == .off)
        #expect(harness.fixture.keyStore.load() == .notSet)
        #expect(try harness.playlistCount() == 1)
    }

    @Test func `a launch starts on the backend this device chose`() throws {
        let harness = try SwitchHarness()
        let streamenCloud = try harness.fixture.makeBackend(defaults: harness.defaults)
        func launch(_ choice: SyncBackendSelection, store: (() throws -> StreamenCloudBackend)? = nil) -> any SyncBackend {
            CloudSyncCoordinator.launchBackend(for: choice, iCloud: harness.iCloud, makeStreamenCloudBackend: store ?? { streamenCloud })
        }

        #expect(launch(.icloud) === harness.iCloud)
        #expect(launch(.streamencloud) === streamenCloud)
        #expect(launch(.off) is OffBackend)
        #expect(launch(.streamencloud) { throw SyncBackendSwitchError.unavailable } === harness.iCloud)
    }

    @Test func `a relaunch after turning sync off stays Off`() throws {
        let harness = try SwitchHarness()
        StreamenCloudSettings(defaults: harness.defaults).backend = .off

        let coordinator = CloudSyncCoordinator(
            catalogContainer: harness.catalog,
            cloudContainer: harness.iCloudMirror,
            cloudKitContainerIdentifier: "iCloud.test.switch",
            cloudKitEnabled: false,
            defaults: harness.defaults
        )

        #expect(coordinator.selectedBackend == .off)
        #expect(coordinator.status.hasCompletedInitialSync)
        #expect(coordinator.mirrorContainer === harness.iCloudMirror)
    }

    @Test func `the Streamen Cloud socket follows the scene and the active backend`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud)
        #expect(streamenCloud.eventListener == nil)

        coordinator.handleScenePhaseChange(to: .active)
        #expect(streamenCloud.eventListener?.isRunning == true)

        coordinator.status.lastReconcile = nil
        coordinator.handleScenePhaseChange(to: .background)
        #expect(streamenCloud.eventListener == nil)
        try await waitUntil { coordinator.status.lastReconcile != nil }

        coordinator.handleScenePhaseChange(to: .active)
        #expect(streamenCloud.eventListener?.isRunning == true)
        try await coordinator.switchBackend(to: .icloud)
        #expect(streamenCloud.eventListener == nil)
    }

    @Test func `a background flush pushes local Streamen Cloud edits`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud)
        let juniper = UUID()
        let mirror = ModelContext(streamenCloud.container)
        mirror.insert(UserProfile(id: juniper, name: "Juniper"))
        try mirror.save()

        coordinator.status.lastReconcile = nil
        coordinator.handleScenePhaseChange(to: .background)
        try await waitUntil { coordinator.status.lastReconcile != nil }

        let keys = try StreamenCloudKeys(rootKey: #require(streamenCloud.identity).rootKey)
        let rid = keys.recordID(for: "profile/\(juniper.uuidString)")
        let record = harness.fixture.server.feed.state.withLock { $0.records[rid] }
        let ciphertext = try #require(record?.ciphertext)
        #expect(try keys.openPayload(ciphertext, rid: rid).type == "profile")
    }

    // MARK: Settings ▸ Sync membership

    @Test func `creating an account from Settings switches to Streamen Cloud and leaves the recovery key unviewed`() async throws {
        let harness = try SwitchHarness()
        let streamenCloud = try harness.fixture.makeBackend(defaults: harness.defaults)
        let coordinator = harness.makeCoordinator(backend: harness.iCloud, streamenCloud: streamenCloud)
        #expect(!coordinator.hasStreamenCloudAccount())

        let recoveryKey = try await coordinator.createStreamenCloudAccount()

        #expect(!recoveryKey.isEmpty)
        #expect(coordinator.hasStreamenCloudAccount())
        #expect(coordinator.selectedBackend == .streamencloud)
        #expect(!StreamenCloudSettings(defaults: harness.defaults).recoveryKeyViewed)
        #expect(try harness.playlistCount() == 1)
    }

    @Test func `leaving Streamen Cloud returns to iCloud, removes this device and keeps the identity`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let identity = try #require(streamenCloud.identity)
        let deviceID = StreamenCloudSettings(defaults: harness.defaults).deviceID
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud)
        try await runPass(coordinator)

        try await coordinator.leaveStreamenCloud()

        #expect(coordinator.selectedBackend == .icloud)
        #expect(StreamenCloudSettings(defaults: harness.defaults).backend == .icloud)
        #expect(harness.fixture.server.devices(of: identity.accountId).first { $0.id == deviceID }?.revoked == true)
        #expect(!harness.fixture.server.isDeleted(identity.accountId))
        #expect(harness.fixture.keyStore.load() == .identity(identity))
        #expect(try harness.playlistCount() == 1)
        #expect(try harness.isFavorite())
    }

    @Test func `leaving Streamen Cloud goes Off where iCloud isn't available`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud, iCloudAvailable: false)

        try await coordinator.leaveStreamenCloud()

        #expect(coordinator.selectedBackend == .off)
        #expect(try harness.playlistCount() == 1)
    }

    @Test func `deleting the account from Settings returns to iCloud and clears the identity`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let accountId = try #require(streamenCloud.identity?.accountId)
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud)
        try await runPass(coordinator)

        try await coordinator.deleteStreamenCloudAccount()

        #expect(harness.fixture.server.isDeleted(accountId))
        #expect(coordinator.selectedBackend == .icloud)
        #expect(harness.fixture.keyStore.load() == .notSet)
        #expect(try harness.playlistCount() == 1)
        #expect(try harness.isFavorite())
    }

    @Test func `an unreachable server refuses the deletion and keeps Streamen Cloud`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let identity = try #require(streamenCloud.identity)
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud)
        harness.fixture.server.failure.withLock { $0 = .transport(URLError(.notConnectedToInternet)) }

        await #expect(throws: StreamenCloudError.self) {
            try await coordinator.deleteStreamenCloudAccount()
        }

        #expect(coordinator.selectedBackend == .streamencloud)
        #expect(streamenCloud.isJoined)
        #expect(harness.fixture.keyStore.load() == .identity(identity))
        #expect(!harness.fixture.server.isDeleted(identity.accountId))
    }

    @Test func `renaming this device updates the account's device list`() async throws {
        let harness = try SwitchHarness()
        let (streamenCloud, _) = try await harness.fixture.makeJoinedBackend(defaults: harness.defaults)
        let accountId = try #require(streamenCloud.identity?.accountId)
        let deviceID = StreamenCloudSettings(defaults: harness.defaults).deviceID
        let coordinator = harness.makeCoordinator(backend: streamenCloud, streamenCloud: streamenCloud)

        try await coordinator.renameStreamenCloudDevice(to: "  Reading Nook ")

        #expect(coordinator.streamenCloudDeviceName == "Reading Nook")
        #expect(harness.fixture.server.devices(of: accountId).first { $0.id == deviceID }?.name == "Reading Nook")
    }
}

@Suite("Streamen Cloud account-end notice")
struct StreamenCloudAccountEndNoticeTests {
    @Test func `a revoked device is told sync is off`() {
        #expect(StreamenCloudAccountEnd.deviceRevoked.noticeMessage(returnedToICloud: false).key
            == "This device was removed from Streamen Cloud. Sync is off; your data stays on this device.")
    }

    @Test func `a deleted account names iCloud only where the device went back to it`() {
        #expect(StreamenCloudAccountEnd.accountDeleted.noticeMessage(returnedToICloud: true).key
            == "Your Streamen Cloud account was deleted. Your Apple devices are back on iCloud; your data stays on this device.")
        #expect(StreamenCloudAccountEnd.accountDeleted.noticeMessage(returnedToICloud: false).key
            == "Your Streamen Cloud account was deleted. Sync is off; your data stays on this device.")
    }
}
