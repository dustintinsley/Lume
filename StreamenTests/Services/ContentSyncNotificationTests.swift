//
//  ContentSyncNotificationTests.swift
//  StreamenTests
//
//  `.streamenContentSyncDidComplete` carries the catalog container as its
//  sender and `CloudSyncCoordinator` observes only its own. The app builds most
//  `ContentSyncManager`s from `modelContext.container`, so that has to be the
//  very container the coordinator holds, or a finished sync would never start
//  the catch-up pass.
//

import Foundation
@testable import Streamen
import SwiftData
import Testing

@MainActor
struct ContentSyncNotificationTests {
    @Test func `a context's container is the container it came from`() throws {
        let container = try makeTestContainer()
        #expect(container.mainContext.container === container)
        #expect(ModelContext(container).container === container)
    }
}
