import SwiftUI

/// Titles and messages of the Sync confirmations, shared with the tvOS pane.
enum SyncSettingsPromptText {
    static let privacyNote: LocalizedStringKey = "End-to-end encrypted"

    static func name(of backend: SyncBackendSelection) -> LocalizedStringKey {
        switch backend {
        case .icloud: "iCloud"
        case .streamencloud: "Streamen Cloud"
        case .off: "Off"
        }
    }

    static func title(_ prompt: SyncSettingsModel.Prompt) -> Text {
        switch prompt {
        case .switchTo(.icloud): Text("Switch to iCloud?")
        case .switchTo(.streamencloud): Text("Switch to Streamen Cloud?")
        case .switchTo(.off): Text("Turn Off Sync?")
        case .setUpStreamenCloud: Text("Set Up Streamen Cloud")
        case .leave: Text("Leave Streamen Cloud?")
        case .deleteAccount: Text("Delete Streamen Cloud Account?")
        }
    }

    static func message(_ prompt: SyncSettingsModel.Prompt, leaveTarget: SyncBackendSelection) -> Text {
        switch prompt {
        case .switchTo(.icloud):
            Text("Your profiles, playlists and viewing on this device are merged with what’s in iCloud. Nothing is deleted.")
        case .switchTo(.streamencloud):
            Text(verbatim: String(localized: "Your profiles, playlists and viewing on this device are merged with your Streamen Cloud account. Nothing is deleted.")
                + "\n\n" + otherAppleDevicesNote)
        case .switchTo(.off):
            Text("Changes stay on this device until you turn sync back on. Nothing is deleted.")
        case .setUpStreamenCloud:
            Text(verbatim: String(localized: "End-to-end encrypted") + "\n\n" + otherAppleDevicesNote)
        case let .leave(otherDeviceNames):
            Text(verbatim: leaveMessage(otherDeviceNames: otherDeviceNames, leaveTarget: leaveTarget))
        case .deleteAccount:
            Text("Your synced data is deleted from Streamen Cloud for good, for every device on this account, including Android devices. What’s on this device stays.")
        }
    }

    /// Entering Streamen Cloud writes the Apple-wide choice, but only a build that
    /// reads it follows: an older one stays on iCloud and stops seeing this
    /// device's changes.
    private static var otherAppleDevicesNote: String {
        String(localized: "Your other Apple devices that sync with iCloud follow once they run the latest version of Streamen. Until then, they don’t see changes from this device.")
    }

    private static func leaveMessage(otherDeviceNames: [String], leaveTarget: SyncBackendSelection) -> String {
        let base = leaveTarget == .icloud
            ? String(localized: "Your Apple devices go back to iCloud. Your Streamen Cloud account and its data stay, so you can rejoin later.")
            : String(localized: "This device stops syncing. Your Streamen Cloud account and its data stay, so you can rejoin later.")
        guard !otherDeviceNames.isEmpty else { return base }
        let names = otherDeviceNames.formatted(.list(type: .and))
        let devices = String(localized: "These devices keep using Streamen Cloud but stop syncing with this device: \(names)")
        return base + "\n\n" + devices
    }
}
