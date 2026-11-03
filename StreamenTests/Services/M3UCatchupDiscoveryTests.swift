//
//  M3UCatchupDiscoveryTests.swift
//  StreamenTests
//
//  Catch-up for m3u playlists that don't declare it the usual way: header-level
//  defaults on `#EXTM3U`, a channel that gives a depth but no dialect, and an
//  Xtream panel's export with no catch-up attributes at all, whose archive is
//  discovered from the panel's own live list. Every playlist here is a local
//  file synced through the real ContentSyncManager into an in-memory store;
//  the panel is a `StubURLProtocol` host, never the network.
//

import Foundation
@testable import Streamen
import SwiftData
import Testing

struct M3UCatchupDiscoveryTests {
    init() {
        clearM3UDigests()
    }

    // MARK: - Fixtures

    private func writeTempFile(_ content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m3u")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Syncs `content` as an m3u playlist and returns its live channels by name.
    private func sync(
        _ content: String,
        client: XtreamClient = XtreamClient()
    ) async throws -> [String: LiveStream] {
        let container = try makeTestContainer()
        let fileURL = try writeTempFile(content)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let context = ModelContext(container)
        let playlist = Playlist(name: "Test M3U", m3uURL: fileURL.absoluteString)
        context.insert(playlist)
        try context.save()

        try await ContentSyncManager(modelContainer: container, xtreamClient: client).syncPlaylist(playlist)

        let streams = try ModelContext(container).fetch(FetchDescriptor<LiveStream>())
        return Dictionary(streams.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// A stub panel answering `get_live_streams` with `body` (or `status`).
    private func panelClient(host: String, status: Int = 200, body: String) -> XtreamClient {
        StubURLProtocol.register(host: host) { _ in .init(status: status, body: body) }
        return XtreamClient(urlSession: StubURLProtocol.makeSession())
    }

    // MARK: - Header defaults

    @Test func `channels inherit catch-up declared on the header`() async throws {
        let streams = try await sync("""
        #EXTM3U catchup="flussonic" catchup-days="3"
        #EXTINF:-1 group-title="News",Inherits
        http://example.com/news/index.m3u8
        #EXTINF:-1 catchup-days="9" group-title="News",Own Depth
        http://example.com/sport/index.m3u8
        #EXTINF:-1 catchup="none" group-title="News",Opts Out
        http://example.com/film/index.m3u8
        """)

        let inherits = try #require(streams["Inherits"])
        #expect(inherits.catchupType == .flussonic)
        #expect(inherits.tvArchiveDuration == 3)

        let ownDepth = try #require(streams["Own Depth"])
        #expect(ownDepth.catchupType == .flussonic, "The dialect still comes from the header")
        #expect(ownDepth.tvArchiveDuration == 9, "A channel's own value wins over the header's")

        let optsOut = try #require(streams["Opts Out"])
        #expect(optsOut.tvArchive == 0, "An explicit dialect on the channel overrides the header, even one meaning none")
    }

    // MARK: - Depth without a dialect

    @Test func `a depth with no dialect is xc on an Xtream-shaped stream only`() async throws {
        let streams = try await sync("""
        #EXTM3U
        #EXTINF:-1 catchup-days="7" group-title="News",Panel Channel
        http://panel.depth.test/live/user/pass/101.ts
        #EXTINF:-1 timeshift="2" group-title="News",Plain Channel
        http://example.com/news/index.m3u8
        """)

        let panel = try #require(streams["Panel Channel"])
        #expect(panel.catchupType == .xc)
        #expect(panel.tvArchiveDuration == 7)

        let plain = try #require(streams["Plain Channel"])
        #expect(plain.tvArchive == 0, "No dialect and no URL to derive an archive from: no guess")
    }

    @Test func `a named dialect is never replaced by an inferred one`() {
        let named = M3UEntry(name: "A", url: "http://p.test/live/u/p/1.ts", catchupTypeRaw: "quantum", catchupDays: 5)
        #expect(ContentSyncManager.candidateCatchupTypes(for: named).isEmpty)

        let templated = M3UEntry(name: "B", url: "http://p.test/b.ts", catchupSource: "?utc={utc}")
        #expect(ContentSyncManager.candidateCatchupTypes(for: templated) == [.default])

        let bare = M3UEntry(name: "C", url: "http://p.test/live/u/p/1.ts")
        #expect(ContentSyncManager.candidateCatchupTypes(for: bare).isEmpty)
    }

    // MARK: - Discovery

    /// The reported case: a panel's m3u export with no catch-up attributes.
    @Test func `discovers catch-up the panel archives`() async throws {
        let host = "panel.discovery.test"
        let client = panelClient(host: host, body: """
        [{"stream_id": 101, "name": "NBC", "tv_archive": 1, "tv_archive_duration": 2},
         {"stream_id": 102, "name": "CBS", "tv_archive": 0, "tv_archive_duration": 0}]
        """)
        let streams = try await sync("""
        #EXTM3U
        #EXTINF:-1 tvg-id="nbc.us" group-title="Network TV",NBC
        http://\(host)/live/user/pass/101.ts
        #EXTINF:-1 tvg-id="cbs.us" group-title="Network TV",CBS
        http://\(host)/live/user/pass/102.ts
        #EXTINF:-1 catchup="append" catchup-source="?utc={utc}" group-title="Network TV",Declared
        http://\(host)/live/user/pass/103.ts
        """, client: client)

        let nbc = try #require(streams["NBC"])
        #expect(nbc.tvArchive == 1)
        #expect(nbc.tvArchiveDuration == 2)
        #expect(nbc.catchupType == .xc)

        let cbs = try #require(streams["CBS"])
        #expect(cbs.tvArchive == 0, "Only channels the panel archives gain catch-up")

        let declared = try #require(streams["Declared"])
        #expect(declared.catchupType == .append, "What the file declares is never overwritten")

        let calls = StubURLProtocol.requests(host: host)
        #expect(calls.count == 1, "One request per panel account, however many channels share it")
        #expect(calls.first?.url?.query?.contains("action=get_live_streams") == true)
    }

    @Test func `a panel that fails changes nothing and the sync still succeeds`() async throws {
        let host = "panel.failing.test"
        let client = panelClient(host: host, status: 500, body: "")
        let streams = try await sync("""
        #EXTM3U
        #EXTINF:-1 group-title="Network TV",NBC
        http://\(host)/live/user/pass/101.ts
        """, client: client)

        let nbc = try #require(streams["NBC"])
        #expect(nbc.tvArchive == 0)
        #expect(nbc.catchupTypeRaw == nil)
    }

    // MARK: - Addresses

    @Test func `only live-segment Xtream URLs are worth asking a panel about`() throws {
        let address = try #require(ContentSyncManager.discoverableAddress("https://p.test:8080/sub/live/u/p/22515.ts?token=t"))
        #expect(address.serverURL == "https://p.test:8080/sub")
        #expect(address.username == "u")
        #expect(address.password == "p")
        #expect(address.streamId == 22515)
        #expect(address.query == "token=t")

        #expect(ContentSyncManager.discoverableAddress("http://p.test/u/p/1.ts") == nil, "The live-less form is too generic")
        #expect(ContentSyncManager.discoverableAddress("http://p.test/movie/u/p/1.mkv") == nil)
        #expect(ContentSyncManager.discoverableAddress("http://p.test/live/u/p/news.ts") == nil, "No numeric stream id")
        #expect(ContentSyncManager.discoverableAddress(nil) == nil)
    }
}
