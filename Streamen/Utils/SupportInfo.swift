//
//  SupportInfo.swift
//  Streamen
//
//  Canonical support / contact links, shared by the iOS Settings list (tappable
//  Link rows) and the tvOS About pane (read-only text plus a scannable QR code,
//  since Apple TV can't open a URL itself). One source of truth so the two
//  surfaces can never drift.
//

import Foundation

nonisolated enum SupportInfo {
    static let website = "http://streamen.app"
    static let email = "support@streamen.app"

    /// App Store listing, and the deep link that opens straight to the
    /// write-a-review composer (`?action=write-review`).
    static let appStore = "https://apps.apple.com/app/id6832292870"
    static let appStoreReview = "https://apps.apple.com/app/id6832292870?action=write-review"

    /// How to install and run a StreamenDVR server, linked from the Recording
    /// Server settings.
    static let recorderGuide = "https://streamen.app/dvr.htm"

    /// Scheme-stripped forms for compact on-screen display.
    static let websiteDisplay = "streamen.app"
    static let appStoreDisplay = "App Store"
    static let recorderGuideDisplay = "streamen.app/dvr.htm"

    static var websiteURL: URL? {
        URL(string: website)
    }

    static var recorderGuideURL: URL? {
        URL(string: recorderGuide)
    }

    static var emailURL: URL? {
        URL(string: "mailto:\(email)")
    }

    static var appStoreReviewURL: URL? {
        URL(string: appStoreReview)
    }

    /// The Movie Database, credited in About as its API terms require.
    static let tmdb = "https://www.themoviedb.org"
    static let tmdbDisplay = "themoviedb.org"

    static var tmdbURL: URL? {
        URL(string: tmdb)
    }

    /// Marketing version (`CFBundleShortVersionString`, e.g. "2.1.0"), sourced
    /// from the build's `MARKETING_VERSION` rather than a hardcoded string so
    /// the iOS and tvOS About panes always reflect the shipped version.
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
