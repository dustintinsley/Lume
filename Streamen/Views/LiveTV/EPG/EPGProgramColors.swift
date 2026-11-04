//
//  EPGChannelColors.swift
//  Streamen
//
//  The Colorful guide (Settings › Live TV › Guide › Colorful): every programme
//  on a channel takes that channel's colour, so the eye can follow a row
//  across the grid. Channels whose names differ only by quality or region —
//  "NBC", "NBC HD", "NBC East", "US: NBC (WTLV)" — are one group and share a
//  colour, and a group never shares its colour with the group just above it.
//  Works from the channel names alone, so it colours every guide, unlike a
//  tint by XMLTV category, which most providers' guides barely fill in.
//

import SwiftUI

extension EnvironmentValues {
    /// Settings › Live TV › Guide › Colorful, set once by `EPGGuideView` so the
    /// guide's many programme blocks don't each observe the stored setting.
    @Entry var epgColorful = false
}

nonisolated enum EPGChannelColors {
    /// Distinct system colours, so each adapts to light and dark appearance
    /// like the rest of the guide. Ordered so consecutive entries contrast.
    static let palette: [Color] = [.blue, .orange, .green, .pink, .teal, .purple, .yellow, .red, .mint, .indigo, .brown, .cyan]

    /// The palette index for each channel, in guide order: one per group, and
    /// never the index of the group directly above. A group that turns up
    /// again further down keeps its colour where that doesn't clash.
    static func colorIndices(forNames names: [String]) -> [Int] {
        var assigned: [String: Int] = [:]
        var result: [Int] = []
        result.reserveCapacity(names.count)
        var previous: (key: String, index: Int)?
        var next = 0

        for name in names {
            let key = groupKey(for: name)
            if let previous, previous.key == key {
                result.append(previous.index)
                continue
            }
            var index = assigned[key] ?? next
            if index == previous?.index {
                index = (index + 1) % palette.count
            }
            if assigned[key] == nil {
                next = (index + 1) % palette.count
            }
            assigned[key] = index
            result.append(index)
            previous = (key, index)
        }
        return result
    }

    /// What makes channels "the same" for colouring: the first word of the name
    /// once a region prefix, bracketed notes, quality and region words and a
    /// trailing feed number are dropped — "US: NBC HD (WTLV)" → "nbc",
    /// "ESPN2" → "espn". Coarse on purpose: "Fox News" and "Fox Sports" group
    /// together, as near-identical names should.
    static func groupKey(for name: String) -> String {
        var text = name.lowercased()
        // "US: ", "UK | ", "CA - " provider prefixes — a dash only with spaces
        // around it, so "ABC-News" keeps its "ABC".
        if let prefix = text.range(of: #"^[a-z]{2,3}(\s*[:|]\s*|\s+-\s+)"#, options: .regularExpression) {
            text.removeSubrange(prefix)
        }
        // "(WTLV)", "[Backup]".
        text = text.replacingOccurrences(of: #"\([^)]*\)|\[[^\]]*\]"#, with: " ", options: .regularExpression)

        let words = text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard let first = words.first(where: { !noiseWords.contains($0) }) else {
            return name.lowercased()
        }
        // "espn2" → "espn"; an all-digit name ("5") stays as it is.
        let trimmed = first.replacingOccurrences(of: #"\d+$"#, with: "", options: .regularExpression)
        return trimmed.isEmpty ? first : trimmed
    }

    /// Quality, codec and region words that tell feeds of one channel apart.
    private static let noiseWords: Set<String> = [
        "hd", "fhd", "uhd", "sd", "hq", "lq", "4k", "8k", "hdr", "hevc", "h264", "h265",
        "1080p", "1080i", "720p", "2160p", "50fps", "60fps",
        "east", "west", "pacific", "mountain", "central", "backup", "alt", "raw", "vip", "the"
    ]
}
