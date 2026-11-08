//
//  TeamPalette.swift
//  Streamen
//
//  The colour toolkit the Sports Hub draws its team tints, card gradients and
//  standings highlights from. ESPN hands us a team's `color`/`alternateColor`
//  as raw hex; many of those are near-white or near-black, which vanish (or
//  glare) as a subtle tint over the hub's dark card material. `TeamPalette`
//  applies a relative-luminance contrast floor: a bright brand colour (an
//  orange, a yellow) is deepened until white type reads on it, keeping its
//  hue; a near-white or grey one, which deepening would only turn grey, and a
//  near-black one degrade to a neutral tint instead of an illegible one.
//  `SportsFixture.matchupColors` then gives each side its primary colour,
//  unless the two are too alike to tell apart.
//

import SwiftUI

/// A team's on-screen colours after the contrast floor, ready for tints and
/// gradients over the hub's dark base.
nonisolated struct TeamPalette: Equatable {
    let primary: Color
    let secondary: Color

    /// The tint substituted when a source colour is too light or too dark to
    /// read as a subtle wash over the dark card material.
    static let neutral = TeamPalette(primary: .secondary, secondary: .secondary)

    /// Opacity for a colour used as a card wash — the design brief's 25–35%.
    static let tintOpacity: Double = 0.3

    /// Minimum WCAG contrast a colour must have against white text before it is
    /// treated as usable rather than near-white.
    private static let minContrastAgainstWhite: Double = 3
    /// Relative luminance below which a colour reads as near-black.
    private static let nearBlackLuminance: Double = 0.02
    /// Spread between a colour's strongest and weakest channel below which it
    /// reads as white or grey rather than as a hue worth deepening.
    private static let minChroma: Double = 0.2

    init(primary: Color, secondary: Color) {
        self.primary = primary
        self.secondary = secondary
    }

    /// Builds a palette from raw ESPN hexes (no leading `#` required). A hex that
    /// fails the contrast floor falls back to the neutral tint; a missing or
    /// unusable secondary falls back to the primary.
    init(primaryHex: String?, secondaryHex: String? = nil) {
        let resolvedPrimary = TeamPalette.usableTint(fromHex: primaryHex) ?? TeamPalette.neutral.primary
        let resolvedSecondary = TeamPalette.usableTint(fromHex: secondaryHex) ?? resolvedPrimary
        self.init(primary: resolvedPrimary, secondary: resolvedSecondary)
    }

    init(_ colors: SportsTeamColors) {
        self.init(primaryHex: colors.primaryHex, secondaryHex: colors.alternateHex)
    }

    /// The primary colour as a subtle wash for a fixture card background.
    var cardTint: Color {
        primary.opacity(Self.tintOpacity)
    }

    /// A diagonal wash from the first-drawn side to the second, dimmed for legibility.
    static func gradient(leading: TeamPalette, trailing: TeamPalette) -> LinearGradient {
        LinearGradient(
            colors: [leading.primary.opacity(tintOpacity), trailing.primary.opacity(tintOpacity)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The colour for `hex` once it clears the contrast floor: deepened, hue
    /// kept, when it is too bright for white text (contrast below 3:1) but has
    /// a clear hue; `nil` when it is near-white or grey, or near-black, so
    /// callers can substitute the neutral tint.
    static func usableTint(fromHex hex: String?) -> Color? {
        usableRGB(fromHex: hex).map { Color(.sRGB, red: $0.red, green: $0.green, blue: $0.blue, opacity: 1) }
    }

    /// `usableTint`'s channels, for comparing two teams' colours.
    static func usableRGB(fromHex hex: String?) -> TeamPaletteRGB? {
        guard let hex, let rgba = teamPaletteRGBA(hex: hex) else { return nil }
        var rgb = TeamPaletteRGB(red: rgba.r, green: rgba.g, blue: rgba.b)
        if rgb.luminance < nearBlackLuminance { return nil }
        if rgb.contrastAgainstWhite < minContrastAgainstWhite {
            guard rgb.chroma >= minChroma else { return nil }
            // Scaling every channel keeps the hue; step down until white reads.
            while rgb.contrastAgainstWhite < minContrastAgainstWhite {
                rgb = rgb.scaled(by: 0.95)
            }
        }
        return rgb
    }
}

/// A colour's sRGB channels, 0–1.
nonisolated struct TeamPaletteRGB: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    var luminance: Double {
        teamPaletteRelativeLuminance(red: red, green: green, blue: blue)
    }

    var contrastAgainstWhite: Double {
        1.05 / (luminance + 0.05)
    }

    var chroma: Double {
        max(red, green, blue) - min(red, green, blue)
    }

    func scaled(by factor: Double) -> TeamPaletteRGB {
        TeamPaletteRGB(red: red * factor, green: green * factor, blue: blue * factor)
    }

    /// How far apart two colours look, 0 (same) to about 3: the "redmean"
    /// approximation, which weights the channels as the eye does.
    func distance(to other: TeamPaletteRGB) -> Double {
        let meanRed = (red + other.red) / 2
        let deltaRed = red - other.red
        let deltaGreen = green - other.green
        let deltaBlue = blue - other.blue
        return ((2 + meanRed) * deltaRed * deltaRed + 4 * deltaGreen * deltaGreen + (3 - meanRed) * deltaBlue * deltaBlue)
            .squareRoot()
    }
}

nonisolated extension Color {
    /// `RRGGBB` or `RRGGBBAA`, with or without a leading `#`; nil when malformed.
    init?(hex: String) {
        guard let rgba = teamPaletteRGBA(hex: hex) else { return nil }
        self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }
}

private nonisolated func teamPaletteRGBA(hex: String) -> (r: Double, g: Double, b: Double, a: Double)? {
    var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("#") { trimmed.removeFirst() }
    guard trimmed.count == 6 || trimmed.count == 8, let value = UInt64(trimmed, radix: 16) else {
        return nil
    }
    if trimmed.count == 6 {
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255,
            1
        )
    }
    return (
        Double((value >> 24) & 0xFF) / 255,
        Double((value >> 16) & 0xFF) / 255,
        Double((value >> 8) & 0xFF) / 255,
        Double(value & 0xFF) / 255
    )
}

private nonisolated func teamPaletteRelativeLuminance(red: Double, green: Double, blue: Double) -> Double {
    func linear(_ component: Double) -> Double {
        component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
}

nonisolated extension SportsFixture {
    /// The home team's tint palette; the neutral tint when there is no home side.
    var homePalette: TeamPalette {
        TeamPalette(primaryHex: home?.team.colorHex, secondaryHex: home?.team.alternateColorHex)
    }

    /// The away team's tint palette; the neutral tint when there is no away side.
    var awayPalette: TeamPalette {
        TeamPalette(primaryHex: away?.team.colorHex, secondaryHex: away?.team.alternateColorHex)
    }

    /// Whether the away side is drawn first — on the left of a card, on top of
    /// a stacked row — with home on the right, as US scoreboards and ESPN
    /// print a game ("UK @ TENN"). A tennis match has no home side, only
    /// ESPN's two player slots, so it keeps its first-listed player first,
    /// matching the set-by-set line.
    var awayLeads: Bool {
        sport != "tennis"
    }

    /// The side drawn first: the away team (see `awayLeads`).
    var leadingSide: SportsCompetitor? {
        awayLeads ? away : home
    }

    /// The side drawn second: the home team (see `awayLeads`).
    var trailingSide: SportsCompetitor? {
        awayLeads ? home : away
    }

    var leadingPalette: TeamPalette {
        awayLeads ? awayPalette : homePalette
    }

    var trailingPalette: TeamPalette {
        awayLeads ? homePalette : awayPalette
    }

    /// The two colours a matchup is drawn in, first-drawn side first: each
    /// team's primary colour, unless the two are too alike to tell apart (two
    /// navy blues, two reds), when the away side switches to its alternate —
    /// or, if that doesn't separate them, the home side does. A side with no
    /// usable colour takes the neutral tint.
    var matchupColors: (leading: Color, trailing: Color) {
        let leadingTeam = leadingSide?.team
        let trailingTeam = trailingSide?.team
        let leadingPrimary = TeamPalette.usableRGB(fromHex: leadingTeam?.colorHex)
        let trailingPrimary = TeamPalette.usableRGB(fromHex: trailingTeam?.colorHex)
        var leading = leadingPrimary
        var trailing = trailingPrimary
        if let leadingPrimary, let trailingPrimary, leadingPrimary.distance(to: trailingPrimary) < Self.minMatchupDistance {
            let awayTeam = awayLeads ? leadingTeam : trailingTeam
            let homeTeam = awayLeads ? trailingTeam : leadingTeam
            let awayPrimary = awayLeads ? leadingPrimary : trailingPrimary
            let homePrimary = awayLeads ? trailingPrimary : leadingPrimary
            var away = awayPrimary
            var home = homePrimary
            if let alternate = TeamPalette.usableRGB(fromHex: awayTeam?.alternateColorHex),
               alternate.distance(to: homePrimary) >= Self.minMatchupDistance
            {
                away = alternate
            } else if let alternate = TeamPalette.usableRGB(fromHex: homeTeam?.alternateColorHex),
                      alternate.distance(to: awayPrimary) >= Self.minMatchupDistance
            {
                home = alternate
            }
            leading = awayLeads ? away : home
            trailing = awayLeads ? home : away
        }
        return (Self.color(leading), Self.color(trailing))
    }

    /// The `TeamPaletteRGB.distance` under which two clubs' colours read as
    /// the same colour across a card.
    private static let minMatchupDistance = 0.45

    private static func color(_ rgb: TeamPaletteRGB?) -> Color {
        guard let rgb else { return TeamPalette.neutral.primary }
        return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }

    /// The competitor whose provider team id matches, if either side does.
    func team(forTeamId teamId: String?) -> SportsTeam? {
        guard let teamId else { return nil }
        if home?.team.teamId == teamId { return home?.team }
        if away?.team.teamId == teamId { return away?.team }
        return nil
    }

    /// The tint for a provider team id — the away palette for the away side, the
    /// home palette otherwise.
    func palette(forTeamId teamId: String?) -> TeamPalette {
        if let teamId, away?.team.teamId == teamId { return awayPalette }
        return homePalette
    }
}
