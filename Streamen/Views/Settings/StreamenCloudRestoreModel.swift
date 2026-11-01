import SwiftUI

/// Drives `StreamenCloudRestoreSheet` and the tvOS restore step: joins the account
/// a recovery key belongs to, then makes Streamen Cloud this device's backend.
@MainActor
@Observable
final class StreamenCloudRestoreModel {
    var recoveryKey = ""
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    var hasRecoveryKey: Bool {
        !recoveryKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canRestore: Bool {
        hasRecoveryKey && !isWorking
    }

    /// `true` once this device restored; `false` on failure, with
    /// `errorMessage` set.
    func restore(using coordinator: CloudSyncCoordinator?) async -> Bool {
        guard canRestore else { return false }
        guard let coordinator else {
            errorMessage = StreamenCloudErrorDescription.message(for: StreamenCloudAccountError.unavailable)
            return false
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await coordinator.restoreStreamenCloud(recoveryKey: recoveryKey)
            return true
        } catch {
            errorMessage = StreamenCloudErrorDescription.message(for: error)
            return false
        }
    }
}
