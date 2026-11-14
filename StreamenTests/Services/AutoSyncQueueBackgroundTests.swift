//
//  AutoSyncQueueBackgroundTests.swift
//  StreamenTests
//
//  "Sync in Background" on the startup cover: the playlist becomes the queue's
//  background sync, so closing the cover doesn't start the next playlist
//  alongside it, and the queue stays busy (holding the guide back) until the
//  sync ends.
//

import Foundation
@testable import Streamen
import SwiftData
import Testing

@MainActor
struct AutoSyncQueueBackgroundTests {
    @Test func `a cover sent to the background keeps the queue busy until its sync ends`() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let playlist = Playlist(name: "Home", serverURL: "http://example.com", username: "u", password: "p")
        context.insert(playlist)

        let queue = AutoSyncQueue()
        queue.coverPlaylist = playlist
        let gate = AsyncStream<Void>.makeStream()
        let sync = Task { for await _ in gate.stream {} }

        queue.continueInBackground(sync, context: context)

        #expect(queue.coverPlaylist == nil)
        #expect(queue.backgroundPlaylist?.id == playlist.id)
        #expect(queue.isBusy)
        // The cover's onDismiss runs now; with the sync still going it must
        // not promote anything.
        queue.promoteNextIfIdle(scope: .isolated(playlist.id), context: context)
        #expect(queue.backgroundPlaylist?.id == playlist.id)

        gate.continuation.finish()
        await sync.value
        for _ in 0 ..< 50 where queue.isBusy {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!queue.isBusy)
    }

    @Test func `without a cover playlist it does nothing`() throws {
        let container = try makeTestContainer()
        let queue = AutoSyncQueue()

        queue.continueInBackground(Task {}, context: container.mainContext)

        #expect(queue.backgroundPlaylist == nil)
        #expect(!queue.isBusy)
    }
}
