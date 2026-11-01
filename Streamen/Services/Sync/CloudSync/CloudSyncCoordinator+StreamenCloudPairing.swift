import Foundation

/// Streamen Cloud pairing, for the pairing sheet: views reach the backend only
/// through this facade.
extension CloudSyncCoordinator {
    /// Joins an account through pairing (the code goes to `onCode` to show),
    /// then makes Streamen Cloud this device's backend. Cancel the calling task to
    /// stop waiting.
    func joinStreamenCloud(onCode: (StreamenCloudPairingCode) -> Void) async throws {
        try await streamenCloudBackend().joinWithPairingCode(onCode: onCode)
        try await switchBackend(to: .streamencloud)
    }

    /// The device waiting behind `code`, for the user to confirm.
    func lookUpStreamenCloudPairing(code: String) async throws -> StreamenCloudPendingDevice {
        try await streamenCloudBackend().lookUpPairing(code: code)
    }

    /// Adds the confirmed device to this device's account.
    func confirmStreamenCloudPairing(_ device: StreamenCloudPendingDevice) async throws {
        try await streamenCloudBackend().confirmPairing(device)
    }
}
