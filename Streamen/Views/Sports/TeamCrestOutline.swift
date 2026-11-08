//
//  TeamCrestOutline.swift
//  Streamen
//
//  A thin outline around a team crest that would otherwise melt into the club
//  colour behind it — a blue crest on its own blue scoreboard half. The crest's
//  most common colour (`SportsCrestTint.prevailingRGB`) is compared with the
//  colour behind it; when the two read as one, the crest's silhouette gets a
//  white edge, or a dark one when the crest itself is mostly white.
//

import CoreGraphics
import SwiftUI

/// Each crest's most common colour, remembered for the session so a crest is
/// analysed once however many cards show it. A miss is remembered too.
actor TeamCrestColourCache {
    static let shared = TeamCrestColourCache()

    private var colours: [URL: TeamPaletteRGB?] = [:]

    func prevailingRGB(for url: URL) async -> TeamPaletteRGB? {
        if let known = colours[url] { return known }
        let image = await SportsCrestTintCache.pipelineImage(url)
        let colour = image.flatMap(SportsCrestTint.prevailingRGB(of:))
        colours[url] = colour
        return colour
    }
}

enum TeamCrestOutline {
    /// The outline a crest needs against `backdrop`, or nil when it already
    /// stands out (or either colour is unknown).
    static func color(crest: TeamPaletteRGB?, backdrop: TeamPaletteRGB?) -> Color? {
        guard let crest, let backdrop, crest.distance(to: backdrop) < SportsFixture.minMatchupDistance else { return nil }
        return crest.luminance > 0.5 ? Color(white: 0.1) : .white
    }
}

extension View {
    /// Draws `color` around the opaque shape of this view (a crest image) by
    /// stacking a flat silhouette of it, nudged `width` points in eight
    /// directions, underneath.
    func silhouetteOutline(_ color: Color, width: CGFloat) -> some View {
        background {
            ZStack {
                ForEach(0 ..< 8, id: \.self) { step in
                    let angle = Double(step) * .pi / 4
                    self
                        .brightness(1)
                        .colorMultiply(color)
                        .offset(x: cos(angle) * width, y: sin(angle) * width)
                }
            }
        }
    }
}
