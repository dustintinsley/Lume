//
//  M3UCategoryOrderTests.swift
//  StreamenTests
//
//  A group a provider adds to its m3u file between syncs takes its place in
//  "Playlist order" at its file position, not after every group the playlist
//  already had.
//

import Foundation
@testable import Streamen
import SwiftData
import Testing

@MainActor
struct M3UCategoryOrderTests {
    private func playlistFile(groups: [String]) -> String {
        var lines = ["#EXTM3U"]
        for (index, group) in groups.enumerated() {
            lines.append("#EXTINF:-1 tvg-id=\"ch.\(index)\" group-title=\"\(group)\",\(group) One")
            lines.append("http://example.com/live/\(group.lowercased())\(index).ts")
        }
        return lines.joined(separator: "\n")
    }

    private func liveCategoryNames(in container: ModelContainer) throws -> [String] {
        try ModelContext(container)
            .fetch(FetchDescriptor<Streamen.Category>())
            .filter { $0.type == .live }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.name)
    }

    @Test func `a group added between syncs sorts at its file position`() async throws {
        let container = try makeTestContainer()
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m3u")
        try playlistFile(groups: ["News", "Sports"]).write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let context = ModelContext(container)
        let playlist = Playlist(name: "Order", m3uURL: fileURL.absoluteString)
        context.insert(playlist)
        try context.save()
        defer { M3UDigestStore.remove(playlistId: playlist.id) }

        let manager = ContentSyncManager(modelContainer: container)
        try await manager.syncPlaylist(playlist)
        #expect(try liveCategoryNames(in: container) == ["News", "Sports"])

        try playlistFile(groups: ["Kids", "News", "Weather", "Sports"])
            .write(to: fileURL, atomically: true, encoding: .utf8)
        try await manager.syncPlaylist(playlist)
        #expect(try liveCategoryNames(in: container) == ["Kids", "News", "Weather", "Sports"])
    }
}
