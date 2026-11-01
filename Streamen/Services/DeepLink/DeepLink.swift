//
//  DeepLink.swift
//  Streamen
//
//  Custom URL-scheme deep links. `streamen://movie/{tmdbId}` and
//  `streamen://series/{tmdbId}` open a title's detail screen directly;
//  `streamen://play/{movie|episode|live}/{catalogId}` and
//  `streamen://open/{series|movie}/{catalogId}` are emitted by the widgets / Top Shelf
//  (built in `WidgetDeepLink`) and launch playback or a detail screen;
//  `streamen://resume` reopens the last played stream and `streamen://downloads` is
//  the download Live Activity's tap target. `streamen://cloud/pair?code=` is the
//  Streamen Cloud pairing QR a new device shows.
//

import Foundation

/// A parsed `streamen://` deep link. Parsing is pure (it never touches the catalog)
/// so it can be unit-tested in isolation; resolving the link to a catalog item
/// and driving navigation happens in `MainTabView`.
nonisolated enum DeepLink: Equatable {
    case movie(tmdbId: Int)
    case series(tmdbId: Int)
    case playMovie(id: String)
    case playEpisode(id: String)
    case playLive(id: String)
    case openSeries(id: String)
    case openMovie(id: String)
    /// Reopens the player on the last played stream, where it left off
    /// (see `PlaybackResumeStore`).
    case resume
    /// Opens the downloads list — the download Live Activity's tap target
    /// (see `DownloadLiveActivity`).
    case downloads
    /// Opens the Streamen Cloud add-device flow with the six-digit code a new
    /// device shows in its pairing QR. Never log the code.
    case cloudPair(code: String)

    /// The app's registered URL scheme (see `CFBundleURLTypes` in Info.plist).
    static let scheme = "streamen"

    /// Parses every supported `streamen://` form. Returns nil for any other scheme,
    /// an unknown kind, or a malformed id.
    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        if let link = Self.hostOnly(host: url.host()) {
            self = link
            return
        }
        // For `streamen://movie/123` the kind is the host and the id is the first
        // path component; `pathComponents` includes the leading "/" and returns
        // components percent-decoded (widget links encode their catalog ids).
        let components = url.pathComponents.filter { $0 != "/" }
        if let link = Self.cloud(host: url.host(), components: components, url: url) {
            self = link
            return
        }
        guard let link = Self.catalog(host: url.host(), components: components) else { return nil }
        self = link
    }

    /// The host-only links, which carry no path.
    private static func hostOnly(host: String?) -> DeepLink? {
        switch host?.lowercased() {
        case "resume": .resume
        case "downloads": .downloads
        default: nil
        }
    }

    /// `cloud/pair?code={6 digits}`, built by `StreamenCloudPairingCode.deepLink`.
    private static func cloud(host: String?, components: [String], url: URL) -> DeepLink? {
        guard host?.lowercased() == "cloud", components.map({ $0.lowercased() }) == ["pair"] else { return nil }
        let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "code" }?.value
        guard let code = code.flatMap({ try? StreamenCloudBackend.normalizedPairingCode($0) }) else { return nil }
        return .cloudPair(code: code)
    }

    /// The catalog links: `movie/` and `series/` by TMDB id, `play/` and
    /// `open/` by catalog id (the widgets' and Top Shelf's links).
    private static func catalog(host: String?, components: [String]) -> DeepLink? {
        switch host?.lowercased() {
        case "movie":
            guard let tmdbId = components.first.flatMap(Int.init) else { return nil }
            return .movie(tmdbId: tmdbId)
        case "series":
            guard let tmdbId = components.first.flatMap(Int.init) else { return nil }
            return .series(tmdbId: tmdbId)
        case "play":
            return play(components)
        case "open":
            return open(components)
        default:
            return nil
        }
    }

    /// `open/{series|movie}/{catalogId}` — built by `WidgetDeepLink.openSeries`
    /// and `.openMovie`.
    private static func open(_ components: [String]) -> DeepLink? {
        guard components.count == 2 else { return nil }
        return switch components[0].lowercased() {
        case "series": .openSeries(id: components[1])
        case "movie": .openMovie(id: components[1])
        default: nil
        }
    }

    /// `play/{movie|episode|live}/{catalogId}` — built by `WidgetDeepLink.play`.
    private static func play(_ components: [String]) -> DeepLink? {
        guard components.count == 2 else { return nil }
        return switch components[0].lowercased() {
        case "movie": .playMovie(id: components[1])
        case "episode": .playEpisode(id: components[1])
        case "live": .playLive(id: components[1])
        default: nil
        }
    }
}

/// The main tab bar's selectable tabs. Hoisted out of `MainTabView` so a deep
/// link can switch tabs through `DeepLinkRouter`.
nonisolated enum AppTab: Hashable {
    case search, home, movies, series, liveTV, sports, settings
}
