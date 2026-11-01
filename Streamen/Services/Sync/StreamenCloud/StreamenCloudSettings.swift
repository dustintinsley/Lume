import Foundation

/// The backend this device reconciles against. Per device: only `icloud` and
/// `streamencloud` are ever mirrored to `SyncedBackendChoice`, never `off`.
nonisolated enum SyncBackendSelection: String, CaseIterable {
    case icloud
    case streamencloud
    case off
}

/// Per-device Streamen Cloud preferences. Small scalars only; the identity lives in
/// `StreamenCloudKeyStore`. None of these values may reach logs or exports — the
/// diagnostic settings dump skips non-`player.` strings, which covers the
/// device id and name.
nonisolated struct StreamenCloudSettings {
    enum Key {
        static let backend = "sync.backend"
        static let deviceID = "streamencloud.deviceID"
        static let deviceName = "streamencloud.deviceName"
        static let recoveryKeyViewed = "streamencloud.recoveryKeyViewed"
        static let movedNoticePending = "streamencloud.movedNoticePending"
        static let movedNoticeShown = "streamencloud.movedNoticeShown"
    }

    /// SIDE_LOAD builds have no CloudKit, so they start Off.
    static var defaultBackend: SyncBackendSelection {
        #if SIDE_LOAD
            .off
        #else
            .icloud
        #endif
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// An unknown raw value reads as the default. SIDE_LOAD builds never report
    /// iCloud.
    var backend: SyncBackendSelection {
        get {
            let stored = defaults.string(forKey: Key.backend).flatMap(SyncBackendSelection.init(rawValue:)) ?? Self.defaultBackend
            #if SIDE_LOAD
                return stored == .icloud ? .off : stored
            #else
                return stored
            #endif
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.backend) }
    }

    /// Whether a backend was ever stored on this device: by a switch, the
    /// first-run sync choice, or an install that predates that choice.
    var hasStoredBackend: Bool {
        defaults.object(forKey: Key.backend) != nil
    }

    /// This device's id on the server (`X-Lume-Device`). Generated and persisted
    /// on first read.
    var deviceID: UUID {
        if let raw = defaults.string(forKey: Key.deviceID), let id = UUID(uuidString: raw) {
            return id
        }
        return rotateDeviceID()
    }

    /// Replaces the device id. The server never re-registers a revoked id, so a
    /// revoked device needs a fresh one before it can join again.
    @discardableResult
    func rotateDeviceID() -> UUID {
        let id = UUID()
        defaults.set(id.uuidString, forKey: Key.deviceID)
        return id
    }

    /// The name shown in the device list. Falls back to the generic model name;
    /// setting a blank name restores that fallback.
    var deviceName: String {
        get {
            let stored = defaults.string(forKey: Key.deviceName)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let stored, !stored.isEmpty else { return Self.genericModelName }
            return stored
        }
        nonmutating set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                defaults.removeObject(forKey: Key.deviceName)
            } else {
                defaults.set(trimmed, forKey: Key.deviceName)
            }
        }
    }

    /// Whether the recovery key has been shown since the account was created.
    /// False keeps the badge on Settings ▸ Sync.
    var recoveryKeyViewed: Bool {
        get { defaults.bool(forKey: Key.recoveryKeyViewed) }
        nonmutating set { defaults.set(newValue, forKey: Key.recoveryKeyViewed) }
    }

    /// Whether Settings badges its Sync entry: Streamen Cloud is on and its
    /// recovery key unseen. Views pass `viewed` from their own `@AppStorage`
    /// so the badge updates as soon as the key is marked viewed.
    static func showsRecoveryKeyBadge(backend: SyncBackendSelection?, viewed: Bool) -> Bool {
        backend == .streamencloud && !viewed
    }

    /// Queues the one-time "Sync moved to Streamen Cloud" alert, unless it was
    /// already shown on this device.
    func queueMovedNotice() {
        guard !defaults.bool(forKey: Key.movedNoticeShown) else { return }
        defaults.set(true, forKey: Key.movedNoticePending)
    }

    /// Product names, not translated. The user-assigned device name needs an
    /// entitlement Streamen doesn't have.
    static var genericModelName: String {
        #if os(tvOS)
            "Apple TV"
        #elseif os(visionOS)
            "Apple Vision Pro"
        #elseif os(macOS)
            "Mac"
        #else
            if ProcessInfo.processInfo.isiOSAppOnMac { return "Mac" }
            return DebugLogExporter.deviceModel.hasPrefix("iPad") ? "iPad" : "iPhone"
        #endif
    }
}
