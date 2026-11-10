//
//  TeamPaletteTests.swift
//  StreamenTests
//
//  ESPN hands the Sports Hub a team's brand colours as raw hex. Near-white and
//  near-black ones would glare or vanish over the hub's dark cards, and bright
//  ones (Lakers gold) would wash out white text. These tests pin the hex
//  parser's accepted shapes and the relative-luminance contrast floor that
//  deepens a bright colour or swaps an unusable one for the neutral tint.
//

@testable import Streamen
import SwiftUI
import Testing

@MainActor
struct TeamPaletteTests {
    @Test func `parses plain and hashed RRGGBB and RRGGBBAA`() {
        #expect(Color(hex: "C8102E") != nil)
        #expect(Color(hex: "#C8102E") != nil)
        #expect(Color(hex: "c8102e") != nil)
        #expect(Color(hex: "C8102E80") != nil)
        #expect(Color(hex: "#C8102E80") != nil)
    }

    @Test func `rejects malformed hex`() {
        #expect(Color(hex: "") == nil)
        #expect(Color(hex: "GGGGGG") == nil)
        #expect(Color(hex: "12345") == nil)
        #expect(Color(hex: "1234567") == nil)
        #expect(Color(hex: "#12") == nil)
    }

    @Test func `near-white colour fails the contrast floor`() {
        #expect(TeamPalette.usableTint(fromHex: "FFFFFF") == nil)
        #expect(TeamPalette.usableTint(fromHex: "EEEEEE") == nil)
    }

    @Test func `bright colour with a clear hue is deepened, not dropped`() throws {
        // Lakers gold: too bright for white text, but clearly gold.
        let gold = try #require(TeamPalette.usableRGB(fromHex: "FDB927"))
        #expect(gold.contrastAgainstWhite >= 3)
        #expect(gold.red > gold.green && gold.green > gold.blue)
    }

    @Test func `near-black colour fails the contrast floor`() {
        #expect(TeamPalette.usableTint(fromHex: "000000") == nil)
        #expect(TeamPalette.usableTint(fromHex: "030303") == nil)
    }

    @Test func `mid-range brand colour survives the contrast floor`() {
        #expect(TeamPalette.usableTint(fromHex: "C8102E") != nil)
        #expect(TeamPalette.usableTint(fromHex: "004C54") != nil)
    }

    @Test func `unusable hex falls back to the neutral tint`() {
        #expect(TeamPalette(primaryHex: "FFFFFF").primary == TeamPalette.neutral.primary)
        #expect(TeamPalette(primaryHex: "000000").primary == TeamPalette.neutral.primary)
        #expect(TeamPalette(primaryHex: nil).primary == TeamPalette.neutral.primary)
    }

    @Test func `usable hex is kept and a missing secondary mirrors the primary`() {
        let palette = TeamPalette(primaryHex: "C8102E")
        #expect(palette.primary != TeamPalette.neutral.primary)
        #expect(palette.secondary == palette.primary)
    }
}
