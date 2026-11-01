import Foundation
import StreamenCloudKit

/// The Streamen Cloud server this build talks to. Set only by build config: the
/// per-configuration `STREAMEN_CLOUD_URL` build setting, overridden by
/// `STREAMEN_CLOUD_URL` in `.env` (Scripts/inject-env.sh). Never user-editable.
nonisolated enum StreamenCloudConfig {
    static let infoPlistKey = "StreamenCloudServerURL"

    static let serverURL: URL = resolve(Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String)

    static var defaultURL: URL {
        StreamenCloudAPI.officialURL
    }

    static func resolve(_ raw: String?) -> URL {
        // Trailing slashes stripped: SyncedBackendChoice auto-join compares URLs for equality.
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            !trimmed.hasPrefix("$("),
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
            url.host?.isEmpty == false
        else { return defaultURL }
        return url
    }

    /// Which server a URL is, for diagnostics: the exported report names the
    /// kind and never a custom server's address.
    enum ServerKind: String {
        case official
        case staging
        case custom
    }

    static var serverKind: ServerKind {
        serverKind(for: serverURL)
    }

    static func serverKind(for url: URL) -> ServerKind {
        switch comparable(url) {
        case comparable(StreamenCloudAPI.officialURL): .official
        case comparable(StreamenCloudAPI.stagingURL): .staging
        default: .custom
        }
    }

    static func comparable(_ url: URL) -> String {
        comparable(url.absoluteString)
    }

    static func comparable(_ url: String) -> String {
        url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
