//
//  GuideDisplaySettings.swift
//  Streamen
//
//  Settings › Live TV › Guide: how many hours of programmes the TV Guide fits
//  across its track, and whether programmes are tinted by category.
//  Device-local on purpose — a phone and a television want different spans.
//

import CoreGraphics
import Foundation

/// How much time the Guide shows across its programme track.
nonisolated enum GuideTimeSpan: String, CaseIterable, Identifiable {
    /// The platform's own scale, as the guide always drew it: two hours on
    /// tvOS, a fixed density on Mac (a wider window shows more).
    case standard
    case oneHour = "60"
    case ninetyMinutes = "90"
    case twoHours = "120"
    case threeHours = "180"
    case fourHours = "240"

    static let storageKey = "streamen.liveTV.guideTimeSpan"

    /// Two hours on iPhone and iPad, where the standard scale crowds three or
    /// four hours onto a phone; the standard scale elsewhere.
    static var defaultValue: GuideTimeSpan {
        #if os(iOS)
            .twoHours
        #else
            .standard
        #endif
    }

    var id: String {
        rawValue
    }

    /// Minutes across the track, or nil for the platform's own scale.
    var minutes: CGFloat? {
        Int(rawValue).map(CGFloat.init)
    }

    var displayName: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .oneHour: String(localized: "1 Hour")
        case .ninetyMinutes: String(localized: "1½ Hours")
        case .twoHours: String(localized: "2 Hours")
        case .threeHours: String(localized: "3 Hours")
        case .fourHours: String(localized: "4 Hours")
        }
    }

    /// An unknown or missing stored value reads as the default.
    init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? Self.defaultValue
    }
}

/// Whether the Guide tints each channel's programmes with that channel's colour
/// (`EPGChannelColors`). Off draws every programme in the neutral fill.
nonisolated enum GuideColorSettings {
    static let colorfulKey = "streamen.liveTV.guideColorful"
    static let colorfulDefault = false
}
