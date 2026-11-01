import Foundation
@testable import Streamen
import StreamenCloudKit
import SwiftUI
import Testing

/// The backend-neutral status: Streamen Cloud errors map onto connection states,
/// the status text follows the active backend, and iCloud reads as before.
@MainActor
struct CloudSyncStatusTests {
    @Test func `errors from Streamen Cloud map onto connection states`() {
        #expect(StreamenCloudSyncState(error: .deviceRevoked) == .revoked)
        #expect(StreamenCloudSyncState(error: .accountDeleted) == .accountDeleted)
        #expect(StreamenCloudSyncState(error: .rateLimited(retryAfter: 30)) == .rateLimited)
        #expect(StreamenCloudSyncState(error: .rateLimited(retryAfter: nil)) == .rateLimited)
        #expect(StreamenCloudSyncState(error: .quotaExceeded) == .quotaExceeded)
        #expect(StreamenCloudSyncState(error: .transport(URLError(.notConnectedToInternet))) == .offline)
    }

    @Test func `errors that don't change the connection leave the state alone`() {
        let errors: [StreamenCloudError] = [
            .badRequest(message: nil), .badAuth, .signupClosed, .notFound, .accountExists, .pairingAlreadySealed,
            .resyncRequired, .recordTooLarge, .server(status: 500, code: nil), .decoding("x"), .missingCredentials
        ]
        for error in errors {
            #expect(StreamenCloudSyncState(error: error) == nil)
        }
    }

    @Test func `backend kinds map onto the selection, nil reading as Off`() {
        #expect(SyncBackendSelection(SyncBackendKind.icloud) == .icloud)
        #expect(SyncBackendSelection(SyncBackendKind.streamencloud) == .streamencloud)
        #expect(SyncBackendSelection(nil) == .off)
    }

    @Test func `the coordinator reports its backend`() throws {
        let container = try makeTestContainer()
        let iCloud = CloudSyncCoordinator(
            catalogContainer: container,
            cloudContainer: container,
            backend: ICloudBackend(mirrorContainer: container, cloudKitContainerIdentifier: "iCloud.test", cloudKitEnabled: false)
        )
        let off = CloudSyncCoordinator(catalogContainer: container, cloudContainer: container, backend: OffBackend())

        #expect(iCloud.status.backend == .icloud)
        #expect(off.status.backend == .off)
    }

    @Test func `iCloud wording is unchanged`() {
        let status = CloudSyncStatus()
        #expect(status.backend == .icloud)
        #expect(CloudSyncStatusText.summary(status) == "Checking…")

        status.account = .available
        #expect(CloudSyncStatusText.summary(status) == "On")
        #expect(CloudSyncStatusText.detail(for: status) == Text("Waiting for first sync…"))

        status.lastReconcile = Date()
        #expect(CloudSyncStatusText.summary(status) == "Synced")

        status.isSyncing = true
        #expect(CloudSyncStatusText.summary(status) == "Syncing…")
        #expect(CloudSyncStatusText.detail(for: status) == Text("Syncing…"))

        status.isSyncing = false
        status.lastError = "boom"
        #expect(CloudSyncStatusText.summary(status) == "Error")

        status.lastError = nil
        status.account = .noAccount
        #expect(CloudSyncStatusText.summary(status) == "No iCloud Account")
    }

    @Test func `iCloud state is ignored while another backend is active`() {
        let status = CloudSyncStatus()
        status.account = .noAccount
        status.isSyncing = true

        status.backend = .off
        #expect(CloudSyncStatusText.summary(status) == "Off")
        #expect(CloudSyncStatusText.detail(for: status) == Text("Sync is off. Changes stay on this device."))

        status.backend = .streamencloud
        status.streamenCloud = .joined
        #expect(CloudSyncStatusText.summary(status) == "On")
    }

    @Test func `each Streamen Cloud state maps to its summary`() {
        let status = CloudSyncStatus()
        status.backend = .streamencloud
        let expected: [(StreamenCloudSyncState, LocalizedStringKey)] = [
            (.notJoined, "Not Set Up"),
            (.joined, "On"),
            (.syncing, "Syncing…"),
            (.uploading(completed: 2, total: 5), "Syncing…"),
            (.revoked, "Removed"),
            (.accountDeleted, "Account Deleted"),
            (.rateLimited, "Busy"),
            (.quotaExceeded, "Storage Full"),
            (.offline, "Offline")
        ]
        for (state, summary) in expected {
            status.streamenCloud = state
            #expect(CloudSyncStatusText.summary(status) == summary)
        }

        status.streamenCloud = .joined
        status.lastReconcile = Date()
        #expect(CloudSyncStatusText.summary(status) == "Synced")
        status.lastError = "boom"
        #expect(CloudSyncStatusText.summary(status) == "Error")
    }

    @Test func `each Streamen Cloud state maps to its detail`() {
        let status = CloudSyncStatus()
        status.backend = .streamencloud
        // Error-backed states show StreamenCloudErrorDescription's already localized
        // sentence verbatim, so they compare against the localized string.
        let expected: [(StreamenCloudSyncState, Text)] = [
            (.notJoined, Text(verbatim: String(localized: "Streamen Cloud isn’t set up on this device."))),
            (.joined, Text("Waiting for first sync…")),
            (.syncing, Text("Syncing…")),
            (.revoked, Text(verbatim: String(localized: "This device was removed from Streamen Cloud. Your data stays on this device."))),
            (.accountDeleted, Text(verbatim: String(localized: "Your Streamen Cloud account was deleted. Your data stays on this device."))),
            (.rateLimited, Text(verbatim: String(localized: "Streamen Cloud is busy. Sync will retry automatically."))),
            (.quotaExceeded, Text(verbatim: String(localized: "Streamen Cloud storage is full. New changes stay on this device."))),
            (.offline, Text(verbatim: String(localized: "Streamen Cloud can’t be reached. Sync resumes automatically.")))
        ]
        for (state, detail) in expected {
            status.streamenCloud = state
            #expect(CloudSyncStatusText.detail(for: status) == detail, "\(state)")
        }
    }

    @Test func `diagnostics name the backend and the Streamen Cloud state only`() {
        let status = CloudSyncStatus()
        #expect(DebugLogExporter.cloudSyncLines(status).first == "Backend: iCloud")

        status.backend = .streamencloud
        status.streamenCloud = .quotaExceeded
        let lines = DebugLogExporter.cloudSyncLines(status, streamenCloudServer: .official)
        #expect(lines.first == "Backend: Streamen Cloud · server: official")
        #expect(lines.contains("State: quota exceeded"))
    }
}
