//
//  LiveChannelCatchupTests.swift
//  StreamenTests
//
//  The List layout's Catch Up sheet: day headings and the airing it plays.
//

import Foundation
@testable import Streamen
import Testing

@MainActor
struct LiveChannelCatchupTests {
    @Test func `days read as Today, Yesterday, then a date`() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let earlier = try #require(calendar.date(byAdding: .day, value: -3, to: today))
        #expect(CatchupProgrammeList.dayTitle(today) == String(localized: "Today"))
        #expect(CatchupProgrammeList.dayTitle(yesterday) == String(localized: "Yesterday"))
        #expect(CatchupProgrammeList.dayTitle(earlier) == earlier.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
    }

    @Test func `a listing becomes the cell the catch-up player takes`() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let listing = EPGWindowListing(
            id: "l1", title: "The Tonight Show", detail: "Guests", start: start, end: start.addingTimeInterval(3600)
        )
        let cell = CatchupProgrammeList.cell(for: listing)
        #expect(cell.title == "The Tonight Show")
        #expect(cell.start == start)
        #expect(cell.end == listing.end)
        #expect(cell.listingID == "l1")
        #expect(!cell.isGap)
    }

    @Test func `the panel's archive listing decodes base64 text and epoch times`() throws {
        let json = Data(#"""
        {"epg_listings":[
          {"id":"1","title":"TmV3cyBhdCA2","description":"TG9jYWwgbmV3cw==","start_timestamp":"1700000000","stop_timestamp":"1700001800"},
          {"id":"2","title":"","start_timestamp":"1700001800","stop_timestamp":"1700003600"},
          {"id":"3","title":"Plain","start_timestamp":1700003600,"end_timestamp":1700005400}
        ]}
        """#.utf8)
        struct Wrapper: Decodable {
            let epg_listings: [XtreamDataTableEPG] // swiftlint:disable:this identifier_name
        }
        let airings = try JSONDecoder().decode(Wrapper.self, from: json).epg_listings
        let listings = CatchupArchiveSource.listings(from: airings)
        #expect(listings.map(\.title) == ["News at 6", "Plain"])
        #expect(listings.first?.detail == "Local news")
        #expect(listings.first?.start == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(listings.last?.end == Date(timeIntervalSince1970: 1_700_005_400))
    }

    @Test func `the stored guide keeps its airings and the panel fills the earlier days`() {
        let today = Date(timeIntervalSince1970: 1_700_100_000)
        let yesterday = today.addingTimeInterval(-86400)
        let stored = [EPGWindowListing(id: "s", title: "Stored", detail: "", start: today, end: today.addingTimeInterval(1800))]
        let panel = [
            EPGWindowListing(id: "p1", title: "Panel copy", detail: "", start: today.addingTimeInterval(20), end: today.addingTimeInterval(1800)),
            EPGWindowListing(id: "p2", title: "Yesterday", detail: "", start: yesterday, end: yesterday.addingTimeInterval(1800))
        ]
        let merged = CatchupProgrammeList.merged(stored: stored, panel: panel)
        #expect(merged.map(\.title) == ["Stored", "Yesterday"])
    }
}
