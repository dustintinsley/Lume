//
//  StreamenCloudLocalizationTests.swift
//  StreamenTests
//
//  Every user-facing literal the Streamen Cloud sync backend added, asserted
//  present and translated in every shipping locale, with the product name
//  kept in Latin script.
//

import Foundation
@testable import Streamen
import Testing

@Suite("Streamen Cloud localization")
struct StreamenCloudLocalizationTests {
    /// Settings ▸ Sync on every platform: the backend choice, the Streamen Cloud
    /// rows and the confirmations behind them.
    static let settingsKeys = [
        "Streamen Cloud",
        "Sync With",
        "Not Set Up",
        "Working…",
        "Switch",
        "Switch to iCloud?",
        "Switch to Streamen Cloud?",
        "Turn Off Sync",
        "Turn Off Sync?",
        "Set Up Streamen Cloud",
        "Create New Account",
        "Join with a Code",
        "Restore from Recovery Key",
        "Leave Streamen Cloud",
        "Leave Streamen Cloud?",
        "Delete Account",
        "Delete Streamen Cloud Account",
        "Delete Streamen Cloud Account?",
        "Device Name",
        "Devices",
        "Recovery Key",
        "Recovery key not viewed",
        "End-to-end encrypted",
        "Enter your PIN to change sync settings.",
        "Enter your PIN to add a device to Streamen Cloud.",
        "Your profiles, playlists and viewing on this device are merged with what’s in iCloud. Nothing is deleted.",
        "Your profiles, playlists and viewing on this device are merged with your Streamen Cloud account. Nothing is deleted.",
        "Changes stay on this device until you turn sync back on. Nothing is deleted.",
        "This device stops syncing. Your Streamen Cloud account and its data stay, so you can rejoin later.",
        "These devices keep using Streamen Cloud but stop syncing with this device: %@",
        "Your synced data is deleted from Streamen Cloud for good, for every device on this account, including Android devices. What’s on this device stays.",
        "Couldn’t Create Account",
        "Couldn’t Delete Account",
        "Couldn’t Leave Streamen Cloud",
        "Couldn’t Rename This Device",
        "Couldn’t Switch Sync"
    ]

    /// Joining with a code and adding a device, on the sheet (iOS, macOS,
    /// visionOS) and the drill-in steps (tvOS).
    static let pairingKeys = [
        "Join Streamen Cloud",
        "Add a Device",
        "Add “%@”?",
        "New Device",
        "Next",
        "Platform",
        "Pairing QR code",
        "Waiting for the other device…",
        "Enter the 6-digit code shown on the new device.",
        "On a device that already uses Streamen Cloud, open Settings ▸ Sync ▸ Add a Device and enter this code, or scan the QR code with that device’s camera.",
        "Only add devices you own. The new device can read everything you sync with Streamen Cloud."
    ]

    /// The device list and its remove confirmation.
    static let deviceKeys = [
        "This Device",
        "Other device",
        "Last seen %@",
        "Removed",
        "It stops syncing with Streamen Cloud. Anything already on it stays there.",
        "To remove this device, leave Streamen Cloud instead."
    ]

    /// Showing, saving and restoring the recovery key, including the tvOS
    /// "visible on your TV" confirmation.
    static let recoveryKeyKeys = [
        "I’ve saved it",
        "Later",
        "Copy",
        "Copied",
        "Share",
        "Show",
        "Show Recovery Key",
        "Show Recovery Key?",
        "Recovery key QR code",
        "This will be visible on your TV. Make sure no one else can see the screen.",
        "If you lose all your devices, this key is the only way back to your Streamen Cloud data. Without it, your synced data is gone.",
        "Store it somewhere safe, like a password manager. Never share it.",
        "You can find this key later in Settings ▸ Sync.",
        "Enter the recovery key you saved when you created your Streamen Cloud account."
    ]

    /// The status line, the terminal-error notices, the one-time handoff
    /// alert and the account-end alert.
    static let statusKeys = [
        "Busy",
        "Offline",
        "Storage Full",
        "Account Deleted",
        "Uploading %lld of %lld",
        "Sync is off. Changes stay on this device.",
        "Streamen Cloud is busy. Sync will retry automatically.",
        "Streamen Cloud storage is full. New changes stay on this device.",
        "Streamen Cloud can’t be reached. Sync resumes automatically.",
        "This device was removed from Streamen Cloud. Your data stays on this device.",
        "Your Streamen Cloud account was deleted. Your data stays on this device.",
        "Your Apple devices go back to iCloud. Your Streamen Cloud account and its data stay, so you can rejoin later.",
        "Checking Streamen Cloud for your playlists…",
        "Sync moved to Streamen Cloud",
        "Update Streamen on your other devices so they keep syncing.",
        "This device was removed from Streamen Cloud. Sync is off; your data stays on this device.",
        "Your Streamen Cloud account was deleted. Your Apple devices are back on iCloud; your data stays on this device.",
        "Your Streamen Cloud account was deleted. Sync is off; your data stays on this device.",
        "Each profile keeps its own watch history, progress and favorites. Profiles sync across your devices via Streamen Cloud.",
        "Each profile keeps its own watch history, progress and favorites. Sync is off, so profiles stay on this device."
    ]

    /// `StreamenCloudErrorDescription`'s sentences.
    static let errorKeys = [
        "An item is too large for Streamen Cloud and stays on this device.",
        "Another device already answered this pairing code.",
        "Streamen Cloud can’t be reached right now. Try again in a moment.",
        "Streamen Cloud didn’t accept this device’s sign-in.",
        "Streamen Cloud is busy. Try again in a moment.",
        "Streamen Cloud is syncing everything again. This happens automatically.",
        "Streamen Cloud isn’t available right now.",
        "Streamen Cloud isn’t set up on this device.",
        "Streamen Cloud ran into a problem. Sync will retry automatically.",
        "Streamen Cloud rejected a request. Export a diagnostic report for details.",
        "Streamen Cloud sent a response this version of Streamen can’t read. Update Streamen to resume syncing.",
        "Streamen couldn’t save the Streamen Cloud key on this device. Unlock the device and try again.",
        "Pairing didn’t finish. Start again on the new device.",
        "That device uses a different Streamen Cloud server.",
        "That isn’t a recovery key.",
        "The pairing code is wrong or has expired.",
        "The recovery key has a typo. Check it and try again.",
        "This Streamen Cloud server isn’t accepting new accounts.",
        "This account already exists. Join with a code or your recovery key instead.",
        "This device already syncs with Streamen Cloud.",
        "This recovery key doesn’t belong to a Streamen Cloud account.",
        "Turn on Streamen Cloud on this device first."
    ]

    static var allKeys: [String] {
        settingsKeys + pairingKeys + deviceKeys + recoveryKeyKeys + statusKeys + errorKeys
    }

    @Test func `every Streamen Cloud string is translated in every shipping locale`() throws {
        let catalog = try StringCatalog.localizable()
        for key in Self.allKeys {
            expectTranslatedEverywhere(key, in: catalog)
        }
    }

    @Test func `every Streamen Cloud string resolves to a non empty value`() {
        for key in Self.allKeys {
            let resolved = String(localized: String.LocalizationValue(key))
            #expect(!resolved.isEmpty, "\(key) resolved to an empty string")
        }
    }

    /// The product name is never transliterated, in any script.
    @Test func `every translation keeps Streamen Cloud in Latin script`() throws {
        let catalog = try StringCatalog.localizable()
        for key in Self.allKeys where key.contains("Streamen Cloud") {
            let translations = try #require(catalog.localizations(for: key), "\(key) is not in the string catalog")
            for (locale, value) in translations {
                #expect(value.contains("Streamen Cloud"), "\(locale) drops “Streamen Cloud” from \(key)")
            }
        }
    }
}
