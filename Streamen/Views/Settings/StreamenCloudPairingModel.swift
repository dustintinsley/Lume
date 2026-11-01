import SwiftUI

/// Drives `StreamenCloudPairingSheet` and the tvOS pairing steps: the join wait
/// or the add-device lookup and confirmation.
@MainActor
@Observable
final class StreamenCloudPairingModel {
    static let codeLength = 6

    /// The code this device shows while it waits to join.
    private(set) var pairingCode: StreamenCloudPairingCode?
    /// Bumped to start the join over after it failed.
    private(set) var joinAttempt = 0
    /// The code typed (or prefilled) to add another device.
    var code = ""
    /// The device behind `code`, waiting for confirmation.
    private(set) var pendingDevice: StreamenCloudPendingDevice?
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    var canLookUp: Bool {
        code.count == Self.codeLength && pendingDevice == nil && !isWorking
    }

    func prefill(_ code: String) {
        self.code = code
        sanitizeCode()
    }

    func sanitizeCode() {
        let digits = String(code.unicodeScalars.filter { ("0" ... "9").contains($0) }.prefix(Self.codeLength).map(Character.init))
        if digits != code {
            code = digits
        }
    }

    /// Drops the looked-up device without adding it, keeping the code.
    func discardPendingDevice() {
        pendingDevice = nil
    }

    func retryJoin() {
        errorMessage = nil
        joinAttempt += 1
    }

    /// `true` once this device joined and syncs through Streamen Cloud; `false`
    /// on failure (with `errorMessage` set) or when the wait was cancelled.
    func join(using coordinator: CloudSyncCoordinator?) async -> Bool {
        pairingCode = nil
        errorMessage = nil
        guard let coordinator else {
            errorMessage = StreamenCloudErrorDescription.message(for: StreamenCloudAccountError.unavailable)
            return false
        }
        do {
            try await coordinator.joinStreamenCloud { code in
                pairingCode = code
            }
            return true
        } catch {
            pairingCode = nil
            if !Task.isCancelled, !(error is CancellationError) {
                errorMessage = StreamenCloudErrorDescription.message(for: error)
            }
            return false
        }
    }

    func lookUp(using coordinator: CloudSyncCoordinator?) async {
        guard canLookUp else { return }
        guard let coordinator else {
            errorMessage = StreamenCloudErrorDescription.message(for: StreamenCloudAccountError.unavailable)
            return
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            pendingDevice = try await coordinator.lookUpStreamenCloudPairing(code: code)
        } catch {
            if case StreamenCloudAccountError.pairingExpired = error {
                code = ""
            }
            errorMessage = StreamenCloudErrorDescription.message(for: error)
        }
    }

    /// `true` once the device was added.
    func confirm(using coordinator: CloudSyncCoordinator?) async -> Bool {
        guard let device = pendingDevice, !isWorking else { return false }
        guard let coordinator else {
            errorMessage = StreamenCloudErrorDescription.message(for: StreamenCloudAccountError.unavailable)
            return false
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await coordinator.confirmStreamenCloudPairing(device)
            return true
        } catch {
            if case StreamenCloudAccountError.pairingExpired = error {
                pendingDevice = nil
                code = ""
            }
            errorMessage = StreamenCloudErrorDescription.message(for: error)
            return false
        }
    }
}
