//
//  GuideDisplayTests.swift
//  StreamenTests
//
//  Settings › Live TV › Guide: the time span's scale and the Colorful guide's
//  per-channel colours.
//

import CoreGraphics
import Foundation
@testable import Streamen
import Testing

@MainActor
struct GuideDisplayTests {
    // MARK: - Time span

    @Test func `a time span fits exactly that many minutes across the track`() {
        let metrics = EPGMetrics.current
        let ppm = metrics.pointsPerMinute(forGuideWidth: 1000, span: .twoHours)
        #if os(tvOS)
            let track = TVLiveTVLayout.paneWidth - metrics.channelColumnWidth - metrics.channelColumnGap
        #else
            let track = 1000 - metrics.channelColumnWidth - 2 * metrics.channelColumnGap
        #endif
        #expect(abs(ppm * 120 - track) < 1, "Two hours of track at the computed scale fills the track")
    }

    @Test func `standard and an unmeasured guide keep the platform scale`() {
        let metrics = EPGMetrics.current
        #expect(metrics.pointsPerMinute(forGuideWidth: 1000, span: .standard) == metrics.pointsPerMinute)
        #if !os(tvOS)
            #expect(metrics.pointsPerMinute(forGuideWidth: 0, span: .twoHours) == metrics.pointsPerMinute)
        #endif
    }

    @Test func `the default span is two hours on iOS only`() {
        #if os(iOS)
            #expect(GuideTimeSpan.defaultValue == .twoHours)
        #else
            #expect(GuideTimeSpan.defaultValue == .standard)
        #endif
        #expect(GuideTimeSpan(storedValue: "nonsense") == .defaultValue)
        #expect(GuideTimeSpan(storedValue: "240") == .fourHours)
    }

    // MARK: - Genres

    // MARK: - Channel colours

    @Test func `feeds of one channel share a group`() {
        let nbc = EPGChannelColors.groupKey(for: "NBC")
        #expect(EPGChannelColors.groupKey(for: "NBC HD") == nbc)
        #expect(EPGChannelColors.groupKey(for: "NBC East") == nbc)
        #expect(EPGChannelColors.groupKey(for: "US: NBC (WTLV)") == nbc)
        #expect(EPGChannelColors.groupKey(for: "UK | NBC FHD") == nbc)
        #expect(EPGChannelColors.groupKey(for: "ESPN2") == EPGChannelColors.groupKey(for: "ESPN"))
        #expect(EPGChannelColors.groupKey(for: "CBS") != nbc)
        #expect(EPGChannelColors.groupKey(for: "ABC-News") != EPGChannelColors.groupKey(for: "News"),
                "A dash without spaces isn't a region prefix")
    }

    @Test func `a run of one channel shares a colour and the next run differs`() {
        let names = ["NBC", "NBC HD", "NBC East", "CBS", "CBS HD", "CBS West"]
        let colors = EPGChannelColors.colorIndices(forNames: names)
        #expect(Set(colors[0 ... 2]).count == 1)
        #expect(Set(colors[3 ... 5]).count == 1)
        #expect(colors[0] != colors[3])
    }

    @Test func `neighbouring groups never share a colour`() {
        // A group that returns keeps its colour unless that clashes with the
        // group right above it.
        let names = ["NBC", "CBS", "NBC", "ABC", "CBS", "CBS HD", "NBC"]
        let colors = EPGChannelColors.colorIndices(forNames: names)
        for index in colors.indices.dropFirst() where
            EPGChannelColors.groupKey(for: names[index]) != EPGChannelColors.groupKey(for: names[index - 1])
        {
            #expect(colors[index] != colors[index - 1])
        }
        #expect(colors[0] == colors[2], "NBC keeps its colour when it comes back")
        #expect(colors[4] == colors[5])
    }

    @Test func `rows stamp their channel's colour on every cell`() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let timeline = EPGTimeline(start: now, end: now.addingTimeInterval(7200), pointsPerMinute: 3)
        let streams = ["NBC", "NBC HD", "CBS"].enumerated().map { index, name in
            LiveStream(id: "s\(index)", streamId: index, name: name)
        }
        let rows = EPGGridBuilder.rows(streams: streams, cellsByChannel: [:], timeline: timeline)
        let colors = rows.map { Set($0.cells.map(\.colorIndex)) }
        #expect(colors.allSatisfy { $0.count == 1 }, "Every cell of a row has the row's colour")
        #expect(colors[0] == colors[1])
        #expect(colors[0] != colors[2])
    }
}
