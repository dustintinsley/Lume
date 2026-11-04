//
//  M3UDuplicateStreamTests.swift
//  StreamenTests
//
//  A provider may list one stream under several groups or names ("NBC" in
//  Network TV and again in Local Channels). Each listing must stay its own
//  channel: keyed on the URL alone, the later listing overwrote the earlier
//  one, which vanished from its group.
//

import Foundation
@testable import Streamen
import SwiftData
import Testing

struct M3UDuplicateStreamTests {
    init() {
        clearM3UDigests()
    }

    private let playlist = """
    #EXTM3U
    #EXTINF:-1 tvg-id="NBCWTLV.us" group-title="Network TV",NBC
    http://dup.test/stream/22515.ts
    #EXTINF:-1 tvg-id="NBCEast_WNBC.us" group-title="Network TV",NBC (East)
    http://dup.test/stream/76203.ts
    #EXTINF:-1 tvg-id="NBCWTLV.us" group-title="Local Channels",NBC Jacksonville
    http://dup.test/stream/22515.ts
    #EXTINF:-1 tvg-id="NBCWTLV.us" group-title="Local Channels",NBC Jacksonville
    http://dup.test/stream/22515.ts
    """

    /// Writes `content` to a temporary file the caller deletes — a re-sync
    /// reads it again — and syncs it once as a new playlist.
    private func sync(_ content: String, into container: ModelContainer) async throws -> (Playlist, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m3u")
        try content.write(to: url, atomically: true, encoding: .utf8)
        let context = ModelContext(container)
        let playlist = Playlist(name: "Dup", m3uURL: url.absoluteString)
        context.insert(playlist)
        try context.save()
        try await ContentSyncManager(modelContainer: container).syncPlaylist(playlist)
        return (playlist, url)
    }

    private func channels(in container: ModelContainer) throws -> [LiveStream] {
        try ModelContext(container).fetch(FetchDescriptor<LiveStream>(sortBy: [SortDescriptor(\.name)]))
    }

    @Test func `a stream listed in two groups stays a channel in each`() async throws {
        let container = try makeTestContainer()
        let (playlist, file) = try await sync(playlist, into: container)
        defer { try? FileManager.default.removeItem(at: file) }

        let rows = try channels(in: container)
        #expect(rows.map(\.name) == ["NBC", "NBC (East)", "NBC Jacksonville"],
                "The exact repeat of the Local Channels listing is one channel, not two")

        let nbc = try #require(rows.first { $0.name == "NBC" })
        let local = try #require(rows.first { $0.name == "NBC Jacksonville" })
        #expect(nbc.categoryId?.hasSuffix("Network TV") == true)
        #expect(local.categoryId?.hasSuffix("Local Channels") == true)
        #expect(nbc.directURL == local.directURL)
        #expect(nbc.id != local.id)

        // The first listing keeps the URL-only id every existing row has, so
        // what hangs off that id (favourites, history) stays attached.
        let byURL = "\(playlist.id.uuidString)-live-\(M3UIdentity.key(for: "http://dup.test/stream/22515.ts"))"
        #expect(nbc.id == byURL)
    }

    @Test func `re-importing keeps both listings on the same rows`() async throws {
        let container = try makeTestContainer()
        let (playlist, file) = try await sync(playlist, into: container)
        defer { try? FileManager.default.removeItem(at: file) }
        let before = try Set(channels(in: container).map(\.id))

        M3UDigestStore.remove(playlistId: playlist.id)
        try await ContentSyncManager(modelContainer: container).syncPlaylist(playlist)

        let after = try Set(channels(in: container).map(\.id))
        #expect(after == before, "Neither listing is pruned or re-created by a re-sync")
    }

    @Test func `identities are first-listing-wins across batches`() {
        var seen = Set<UInt64>()
        let first = M3UEntry(name: "NBC", url: "http://x/1.ts", group: "Network TV")
        let again = M3UEntry(name: "NBC Local", url: "http://x/1.ts", group: "Local")
        let batchOne = ContentSyncManager.liveRowIdentities(for: [first], playlistPrefix: "P", seen: &seen)
        let batchTwo = ContentSyncManager.liveRowIdentities(for: [again], playlistPrefix: "P", seen: &seen)
        #expect(batchOne[0].id == "P-live-\(M3UIdentity.key(for: "http://x/1.ts"))")
        #expect(batchTwo[0].id != batchOne[0].id, "A listing in a later batch is still a repeat")
        #expect(batchOne[0].source == "http://x/1.ts")
    }
}
