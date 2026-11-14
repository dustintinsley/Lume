import Foundation

/// The id of the currently active profile, persisted in `UserDefaults`.
///
/// A small scalar flag (not structured data), so `UserDefaults` is appropriate —
/// and it must be reachable from the sync engine's background actor *without* a
/// SwiftData fetch, which is why it lives here rather than on a model. Written by
/// `ProfileManager`, read by `CloudSyncEngine` to scope content reconciliation.
nonisolated enum ActiveProfileStore {
    static let key = "profiles.activeProfileID.v1"

    static var current: UUID? {
        get { current(in: .standard) }
        set { setCurrent(newValue, in: .standard) }
    }

    /// The active profile as `defaults` holds it. The sync engine reads it from
    /// its own preferences (`.standard` in the app), so a test's engine never
    /// sees a profile another test switched to.
    static func current(in defaults: UserDefaults) -> UUID? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return UUID(uuidString: raw)
    }

    static func setCurrent(_ id: UUID?, in defaults: UserDefaults) {
        if let id {
            defaults.set(id.uuidString, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
