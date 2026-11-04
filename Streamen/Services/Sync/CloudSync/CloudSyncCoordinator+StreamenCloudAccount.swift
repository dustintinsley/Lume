import Foundation

/// Streamen Cloud devices and recovery key, for the Sync settings: views reach the
/// backend only through this facade.
extension CloudSyncCoordinator {
    /// The account's devices that still sync, this device first.
    func streamenCloudDevices() async throws -> [StreamenCloudDeviceInfo] {
        try await streamenCloudBackend().devices()
    }

    /// Removes another device from the account. This device leaves instead.
    func revokeStreamenCloudDevice(id: UUID) async throws {
        try await streamenCloudBackend().revokeDevice(id: id)
    }

    /// Clears the "recovery key not viewed" badge on Settings ▸ Sync.
    func markStreamenCloudRecoveryKeyViewed() {
        try? streamenCloudBackend().markRecoveryKeyViewed()
    }

    /// The joined account's recovery key, for showing on screen: reading it
    /// clears the "not viewed" badge. Never log it.
    func revealStreamenCloudRecoveryKey() throws -> String {
        let recoveryKey = try streamenCloudBackend().recoveryKey()
        markStreamenCloudRecoveryKeyViewed()
        return recoveryKey
    }

    /// Joins the account `recoveryKey` belongs to, then makes Streamen Cloud this
    /// device's backend.
    func restoreStreamenCloud(recoveryKey: String) async throws {
        try await streamenCloudBackend().restore(recoveryKey: recoveryKey)
        try await switchBackend(to: .streamencloud)
    }
}
