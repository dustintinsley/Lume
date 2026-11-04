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

/// How the Guide draws its rows — Settings › Live TV › Guide.
nonisolated enum GuideStyleSettings {
    /// Colourful: each programme takes a muted colour of its own
    /// (`EPGProgramColors`). Off draws every programme in the neutral fill.
    static let colorfulKey = "streamen.liveTV.guideColorful"
    /// Off shows a wide logo tile and no channel name in the channel column.
    static let showsChannelNamesKey = "streamen.liveTV.guideChannelNames"
    /// Lightens the part of the programme on now that has already aired.
    static let showsProgressKey = "streamen.liveTV.guideProgress"
    /// The vertical line marking the current time across the grid.
    static let showsNowLineKey = "streamen.liveTV.guideNowLine"

    static let colorfulDefault = false
    static let showsChannelNamesDefault = true
    static let showsProgressDefault = true
    static let showsNowLineDefault = true
}

/// The Guide's style settings as one value, which `EPGGuideView` reads once
/// and hands down through `\.epgStyle`.
nonisolated struct GuideStyle: Equatable {
    var colorful = GuideStyleSettings.colorfulDefault
    var showsChannelNames = GuideStyleSettings.showsChannelNamesDefault
    var showsProgress = GuideStyleSettings.showsProgressDefault
    var showsNowLine = GuideStyleSettings.showsNowLineDefault
}
