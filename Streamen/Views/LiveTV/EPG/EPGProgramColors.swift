//
//  EPGProgramColors.swift
//  Streamen
//
//  The Colorful guide (Settings › Live TV › Guide › Colorful), after UHF: each
//  programme a muted colour of its own. The colour comes from the airing's
//  title and start, so one airing simulcast on several feeds ("The Tonight
//  Show" on NBC and NBC East) is the same colour on each, while neighbouring
//  programmes in a row usually differ. It works from titles and times alone,
//  so it colours every guide, unlike a tint by XMLTV category, which most
//  providers' guides barely fill in.
//

import SwiftUI

extension EnvironmentValues {
    /// Settings › Live TV › Guide, set once by `EPGGuideView` so the guide's
    /// many cells don't each observe the stored settings.
    @Entry var epgStyle = GuideStyle()
}

nonisolated enum EPGProgramColors {
    /// Distinct system colours, so each adapts to light and dark appearance
    /// like the rest of the guide.
    static let palette: [Color] = [.blue, .orange, .green, .pink, .teal, .purple, .yellow, .red, .mint, .indigo, .brown, .cyan]

    /// The palette index for one airing: its title and start, hashed —
    /// stable across launches, unlike `Hashable`'s seeded hash.
    static func colorIndex(forProgramme title: String, start: Date) -> Int {
        let hash = M3UIdentity.hash64("\(title)\u{1F}\(Int(start.timeIntervalSince1970))")
        return Int(hash % UInt64(palette.count))
    }
}
