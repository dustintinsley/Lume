import Foundation

/// Streamen Cloud membership for the Sync settings: turning it on with a new
/// account, leaving, deleting the account and naming this device. Views reach
/// the backend only through this facade.
extension CloudSyncCoordinator {
    /// Whether this device holds a usable Streamen Cloud account, so switching to
    /// Streamen Cloud needs no create-or-join step. Opens the Streamen Cloud store on
    /// first use; call it from actions, not from a view body.
    func hasStreamenCloudAccount() -> Bool {
        (try? streamenCloudBackend())?.isJoined ?? false
    }

    /// Where leaving Streamen Cloud takes this device: iCloud, or Off where this
    /// build has no iCloud.
    var streamenCloudLeaveTarget: SyncBackendSelection {
        isICloudAvailable ? .icloud : .off
    }

    /// Creates an account, makes Streamen Cloud this device's backend and returns
    /// the recovery key to show. Never log it.
    func createStreamenCloudAccount() async throws -> String {
        let recoveryKey = try await streamenCloudBackend().createAccount()
        try await switchBackend(to: .streamencloud)
        return recoveryKey
    }

    /// Leaves Streamen Cloud on this device: switches to `streamenCloudLeaveTarget`,
    /// then removes this device from the account's device list (best effort).
    /// The account, its data and the keychain identity stay.
    func leaveStreamenCloud() async throws {
        try await switchBackend(to: streamenCloudLeaveTarget)
        await (try? streamenCloudBackend())?.leave()
    }

    /// Deletes the account on the server, then switches to
    /// `streamenCloudLeaveTarget`. Throws, without switching, when the server can't
    /// be reached: a deletion is never queued. Local data stays.
    func deleteStreamenCloudAccount() async throws {
        try await streamenCloudBackend().deleteAccount()
        try await switchBackend(to: streamenCloudLeaveTarget)
    }

    /// The name this device shows in the account's device list.
    var streamenCloudDeviceName: String {
        settings.deviceName
    }

    /// Renames this device locally and, while joined, on the server.
    func renameStreamenCloudDevice(to name: String) async throws {
        try await streamenCloudBackend().renameDevice(to: name)
    }
}
