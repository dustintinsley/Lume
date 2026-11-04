//
//  StreamenCloudContainerTests.swift
//  StreamenTests
//
//  The two user-data mirrors' schemas: `SyncedBackendChoice` only in the iCloud
//  mirror, the transport bookkeeping only in the Streamen Cloud mirror, and neither
//  mirror ever treated as the catalog by the history purge. Every configuration
//  is in-memory with `cloudKitDatabase: .none`.
//

import Foundation
@testable import Streamen
import SwiftData
import Testing

@MainActor
struct StreamenCloudContainerTests {
    private func entityNames(_ container: ModelContainer) -> Set<String> {
        Set(container.schema.entities.map(\.name))
    }

    @Test func `the Streamen Cloud mirror is local-only and carries the bookkeeping`() throws {
        let container = try StreamenApp.makeStreamenCloudContainer(isStoredInMemoryOnly: true)
        let configuration = try #require(container.configurations.first)
        #expect(container.configurations.count == 1)
        #expect(configuration.name == ContentSyncManager.streamenCloudMirrorConfigurationName)
        #expect(configuration.cloudKitContainerIdentifier == nil)

        let names = entityNames(container)
        #expect(names.contains("StreamenCloudRecordState"))
        #expect(names.contains("StreamenCloudSyncMeta"))
        #expect(names.contains("SyncedPlaylist"))
        #expect(names.contains("SyncedLiveTVPreferences"))
        #expect(!names.contains("SyncedBackendChoice"))
    }

    @Test func `the iCloud mirror carries the backend choice and no bookkeeping`() throws {
        let names = try entityNames(makeICloudMirrorTestContainer(extraModels: [SyncedBackendChoice.self]))
        #expect(names.contains("SyncedBackendChoice"))
        #expect(!names.contains("StreamenCloudRecordState"))
        #expect(!names.contains("StreamenCloudSyncMeta"))
    }

    @Test func `history purge refuses both mirrors`() throws {
        let streamenCloud = try StreamenApp.makeStreamenCloudContainer(isStoredInMemoryOnly: true)
        #expect(ContentSyncManager.historyPurgeIsSafe(for: streamenCloud.configurations) == false)
        let iCloud = try makeICloudMirrorTestContainer(extraModels: [SyncedBackendChoice.self])
        #expect(ContentSyncManager.historyPurgeIsSafe(for: iCloud.configurations) == false)
    }

    @Test func `a record state with an existing rid replaces it`() throws {
        let container = try StreamenApp.makeStreamenCloudContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.insert(StreamenCloudRecordState(rid: "rid-1", logicalKey: "profile:none", type: "profile", version: 1))
        try context.save()
        context.insert(StreamenCloudRecordState(
            rid: "rid-1",
            logicalKey: "profile:none",
            type: "profile",
            version: 2,
            lastSyncedPayload: Data("{}".utf8),
            isDirty: true
        ))
        try context.save()

        let states = try context.fetch(FetchDescriptor<StreamenCloudRecordState>())
        #expect(states.count == 1)
        #expect(states.first?.version == 2)
        #expect(states.first?.isDirty == true)
    }

    @Test func `the sync meta and backend choice round-trip`() throws {
        let streamenCloud = try ModelContext(StreamenApp.makeStreamenCloudContainer(isStoredInMemoryOnly: true))
        streamenCloud.insert(StreamenCloudSyncMeta(nextSeq: 42, accountId: "account-fixture"))
        try streamenCloud.save()
        let meta = try #require(try streamenCloud.fetch(FetchDescriptor<StreamenCloudSyncMeta>()).first)
        #expect(meta.id == StreamenCloudSyncMeta.singletonID)
        #expect(meta.nextSeq == 42)

        let iCloud = try ModelContext(makeICloudMirrorTestContainer(extraModels: [SyncedBackendChoice.self]))
        let rootKey = Data(repeating: 7, count: 32)
        iCloud.insert(SyncedBackendChoice(
            backend: .streamencloud,
            serverURL: "https://cloud.example.test",
            accountId: "account-fixture",
            rootKey: rootKey
        ))
        try iCloud.save()
        let choice = try #require(try iCloud.fetch(FetchDescriptor<SyncedBackendChoice>()).first)
        #expect(choice.id == SyncedBackendChoice.singletonID)
        #expect(choice.backend == SyncedBackendChoice.Backend.streamencloud.rawValue)
        #expect(choice.rootKey == rootKey)
    }
}
