//
//  GuideDisplayTests.swift
//  StreamenTests
//
//  Settings › Live TV › Guide: the time span's scale and the Colorful guide's
//  per-programme colours.
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

    // MARK: - Programme colours

    @Test func `one airing is the same colour on every feed`() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let timeline = EPGTimeline(start: now, end: now.addingTimeInterval(7200), pointsPerMinute: 3)
        func cells(_ id: String) -> [EPGProgramCell] {
            EPGGridBuilder.cells(for: [
                EPGWindowListing(id: id + "a", title: "The Tonight Show", detail: "", start: now, end: now.addingTimeInterval(3600)),
                EPGWindowListing(id: id + "b", title: "Late Night", detail: "", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200))
            ], timeline: timeline)
        }
        let nbc = cells("nbc")
        let east = cells("east")
        #expect(nbc[0].colorIndex == east[0].colorIndex, "A simulcast shares its colour across feeds")
        #expect(nbc[1].colorIndex == east[1].colorIndex)
        #expect(EPGProgramColors.colorIndex(forProgramme: "The Tonight Show", start: now)
            == EPGProgramColors.colorIndex(forProgramme: "The Tonight Show", start: now),
            "The colour is stable, not random per launch")
    }

    @Test func `hiding channel names narrows the column to a logo tile`() {
        let metrics = EPGMetrics.current
        let named = metrics.styled(GuideStyle())
        var logosOnly = GuideStyle()
        logosOnly.showsChannelNames = false
        let narrow = metrics.styled(logosOnly)
        #expect(named.channelColumnWidth == metrics.channelColumnWidth)
        #expect(narrow.channelColumnWidth == (metrics.rowHeight * 1.75).rounded())
        #if !os(tvOS)
            #expect(narrow.pointsPerMinute(forGuideWidth: 1000, span: .twoHours)
                > named.pointsPerMinute(forGuideWidth: 1000, span: .twoHours),
                "A narrower column leaves a wider track for the same span")
        #endif
    }
}
