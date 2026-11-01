import SwiftUI

/// Drives the first-run sync choice (`SyncSetupView`): the backend picked,
/// the Streamen Cloud step, the account flow it opens and the coordinator call
/// behind each. The choice ends once a backend is committed, or once a Streamen
/// Cloud flow switched this device to Streamen Cloud and closed.
@MainActor
@Observable
final class SyncSetupModel {
    /// A Streamen Cloud flow: a sheet here, a step in place on tvOS.
    enum Flow: Hashable, Identifiable {
        case join
        case restore
        /// The key of the account just created. Never log it.
        case recoveryKey(String)

        var id: String {
            switch self {
            case .join: "join"
            case .restore: "restore"
            case .recoveryKey: "recoveryKey"
            }
        }
    }

    var selection: SyncBackendSelection
    /// The Streamen Cloud step (create, join or restore) is showing.
    var showsStreamenCloud = false
    var flow: Flow?
    var alert: SyncSettingsModel.Alert?
    private(set) var isWorking = false

    var isAlertPresented: Bool {
        get { alert != nil }
        set { if !newValue { alert = nil } }
    }

    init(selection: SyncBackendSelection) {
        self.selection = selection
    }

    /// Commits `selection`: iCloud and Off end the choice, Streamen Cloud opens its step.
    func commit(using coordinator: CloudSyncCoordinator) {
        guard selection != .streamencloud else {
            showsStreamenCloud = true
            return
        }
        let target = selection
        run(failureTitle: "Couldn’t Switch Sync") {
            try await coordinator.chooseInitialBackend(target)
        }
    }

    func createAccount(using coordinator: CloudSyncCoordinator) {
        run(failureTitle: "Couldn’t Create Account") { [weak self] in
            let recoveryKey = try await coordinator.createStreamenCloudAccount()
            self?.flow = .recoveryKey(recoveryKey)
        }
    }

    /// Joins the account the user's other Apple devices sync with; no code needed.
    func joinOfferedAccount(using coordinator: CloudSyncCoordinator) {
        run(failureTitle: "Couldn’t Join Streamen Cloud") {
            try await coordinator.joinOfferedStreamenCloudAccount()
            coordinator.finishBackendChoice()
        }
    }

    /// A flow closed. Once it switched this device to Streamen Cloud the choice is
    /// made; a cancelled one leaves the Streamen Cloud step up.
    func flowDidClose(using coordinator: CloudSyncCoordinator) {
        flow = nil
        guard coordinator.selectedBackend == .streamencloud else { return }
        coordinator.finishBackendChoice()
    }

    /// The backend changed under the setup: a flow left early (Menu during a
    /// restore on tvOS) that still switched this device to Streamen Cloud ends the
    /// choice. A running call or an open flow ends it itself.
    func backendDidChange(using coordinator: CloudSyncCoordinator) {
        guard flow == nil, !isWorking, coordinator.selectedBackend == .streamencloud else { return }
        coordinator.finishBackendChoice()
    }

    private func run(failureTitle: LocalizedStringKey, _ action: @escaping () async throws -> Void) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await action()
            } catch {
                alert = SyncSettingsModel.Alert(title: failureTitle, message: StreamenCloudErrorDescription.actionMessage(for: error))
            }
        }
    }
}
