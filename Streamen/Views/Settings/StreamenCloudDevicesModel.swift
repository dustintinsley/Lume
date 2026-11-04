import SwiftUI

/// Drives `StreamenCloudDevicesView` and `TVStreamenCloudDevicesStep`: the live
/// device list and removals.
@MainActor
@Observable
final class StreamenCloudDevicesModel {
    /// Nil until the first fetch lands.
    private(set) var devices: [StreamenCloudDeviceInfo]?
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    /// The device whose removal is in flight.
    private(set) var removingID: UUID?
    /// The device waiting for the removal confirmation.
    var pendingRemoval: StreamenCloudDeviceInfo?

    var isRemovalPresented: Bool {
        get { pendingRemoval != nil }
        set { if !newValue { pendingRemoval = nil } }
    }

    func load(using coordinator: CloudSyncCoordinator?) async {
        guard let coordinator else {
            errorMessage = StreamenCloudErrorDescription.message(for: StreamenCloudAccountError.unavailable)
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await coordinator.streamenCloudDevices()
            devices = fetched
            errorMessage = nil
        } catch {
            if !Task.isCancelled, !(error is CancellationError) {
                errorMessage = StreamenCloudErrorDescription.message(for: error)
            }
        }
    }

    func remove(_ device: StreamenCloudDeviceInfo, using coordinator: CloudSyncCoordinator?) async {
        guard !device.isCurrent, removingID == nil else { return }
        guard let coordinator else {
            errorMessage = StreamenCloudErrorDescription.message(for: StreamenCloudAccountError.unavailable)
            return
        }
        removingID = device.id
        errorMessage = nil
        defer { removingID = nil }
        do {
            try await coordinator.revokeStreamenCloudDevice(id: device.id)
            devices?.removeAll { $0.id == device.id }
        } catch {
            errorMessage = StreamenCloudErrorDescription.message(for: error)
        }
    }
}
