//
//  EPGComponents+Chrome.swift
//  Streamen
//
//  The guide's chrome around the programme blocks: the channel cell, the time
//  ruler with its now pill, the date over the channel column, and (tvOS) the
//  hint under the guide.
//

import SwiftUI

// MARK: - Channel cell

/// How focus touches a channel's row.
enum EPGChannelCellHighlight {
    case none
    /// A programme in the row is focused.
    case row
    /// The channel itself — the hub — is focused or pressed.
    case hub
}

/// The channel column entry: logo tile, name and the catch-up glyph. The hub
/// is the same card as a focused programme; while one of the row's
/// programmes is focused the cell lifts to mark the row.
struct EPGChannelCell: View {
    let row: EPGChannelRow
    let metrics: EPGMetrics
    var highlight = EPGChannelCellHighlight.none
    @Environment(\.epgStyle) private var style

    private var isHub: Bool {
        highlight == .hub
    }

    var body: some View {
        if style.showsChannelNames {
            namedCell
        } else {
            logoOnlyCell
        }
    }

    /// Settings › Live TV › Guide › Show Channel Names off: the whole cell is
    /// the logo tile, after UHF, with the catch-up glyph in its corner.
    private var logoOnlyCell: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.channelCornerRadius, style: .continuous)
        return EPGLogoTile(
            url: row.logoURL,
            side: metrics.rowHeight,
            cornerRadius: metrics.channelCornerRadius,
            padding: metrics.rowHeight * 0.14,
            glyphSize: metrics.rowHeight * 0.36,
            width: metrics.channelColumnWidth,
            isOnCard: isHub,
            lightFill: fill
        )
        .overlay(alignment: .topTrailing) {
            if row.catchupCapable {
                CatchupBadge(days: nil)
                    .font(metrics.catchupGlyphFont)
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(.black.opacity(0.35), in: Circle())
                    .padding(4)
            }
        }
        .overlay {
            shape.strokeBorder(highlight == .none ? .clear : border, lineWidth: isHub ? 3 : 2)
        }
        .accessibilityLabel(Text(row.name))
    }

    private var namedCell: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.channelCornerRadius, style: .continuous)
        return HStack(spacing: metrics.channelCellSpacing) {
            logo
            Text(row.name)
                .font(metrics.channelNameFont)
                .foregroundStyle(isHub ? EPGColors.cardText : .primary)
                .lineLimit(metrics.channelNameLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
            if row.catchupCapable {
                CatchupBadge(days: nil)
                    .font(metrics.catchupGlyphFont)
                    .foregroundStyle(isHub ? EPGColors.cardText : LiveTVPalette.accent)
            }
        }
        .padding(.horizontal, metrics.channelCellPadding)
        .frame(width: metrics.channelColumnWidth, height: metrics.rowHeight, alignment: .leading)
        .background(fill, in: shape)
        .overlay {
            shape.strokeBorder(border, lineWidth: 1)
        }
    }

    private var fill: Color {
        switch highlight {
        case .hub: EPGColors.cardFill
        case .row: .primary.opacity(0.15)
        case .none: .primary.opacity(0.05)
        }
    }

    private var border: Color {
        switch highlight {
        case .hub: EPGColors.cardBorder
        case .row: .primary.opacity(0.24)
        case .none: .primary.opacity(0.08)
        }
    }

    /// Dark on the hub card and in dark mode, so a white logo stays visible;
    /// on the light guide background it shows the cell's own fill.
    private var logo: some View {
        let side = metrics.logoSide
        return EPGLogoTile(
            url: row.logoURL, side: side, cornerRadius: side * 0.26, padding: side * 0.11, glyphSize: side * 0.39,
            isOnCard: isHub
        )
    }
}

#if !os(tvOS)
    /// Draws a channel button as its cell: the hub card while pressed or under
    /// keyboard focus.
    struct EPGChannelButtonStyle: ButtonStyle {
        let row: EPGChannelRow
        let metrics: EPGMetrics

        func makeBody(configuration: Configuration) -> some View {
            StyleBody(row: row, metrics: metrics, isPressed: configuration.isPressed)
        }

        private struct StyleBody: View {
            let row: EPGChannelRow
            let metrics: EPGMetrics
            let isPressed: Bool
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                let highlighted = isFocused || isPressed
                EPGChannelCell(row: row, metrics: metrics, highlight: highlighted ? .hub : .none)
                    .contentShape(Rectangle())
                    .animation(.easeOut(duration: 0.15), value: highlighted)
            }
        }
    }
#endif

/// A channel's logo tile. Dark in dark mode and on the light-mode hub card,
/// so a white logo stays visible. In light mode it otherwise takes
/// `lightFill`, the guide's own background, and a logo that would melt into
/// it — a white one, mostly — gets a one-pixel dark edge around its shape.
/// Never an `EmptyView` in any phase: the image loads from a `.task` on its
/// content.
struct EPGLogoTile: View {
    let url: URL?
    let side: CGFloat
    let cornerRadius: CGFloat
    let padding: CGFloat
    let glyphSize: CGFloat
    /// Wider than `side` for the logo-only channel column; square otherwise.
    var width: CGFloat?
    /// On the hub card, which is dark in light mode too.
    var isOnCard = false
    /// The tile's fill in light mode off the card.
    var lightFill: Color = .clear
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    /// The logo's most common colour, read only while it sits on the light background.
    @State private var logoColour: TeamPaletteRGB?

    /// The light guide background a logo is compared with.
    private static let lightBackdrop = TeamPaletteRGB(red: 0.95, green: 0.95, blue: 0.95)

    private var isLight: Bool {
        colorScheme == .light && !isOnCard
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        CachedAsyncImage(url: url, maxPixelSize: LiveTVLogo.pixelSize) { phase in
            switch phase {
            case let .success(image):
                logo(image).padding(padding)
            case .failure:
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: glyphSize))
                    .foregroundStyle(isLight ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white.opacity(0.6)))
            default:
                Color.clear
            }
        }
        .frame(width: width ?? side, height: side)
        .background(isLight ? lightFill : Color(white: 0.16), in: shape)
        .clipShape(shape)
        // Remembered per logo for the session (`TeamCrestColourCache`), so a
        // logo is analysed once however often its row is realized.
        .task(id: isLight ? url : nil) {
            guard isLight, let url else { return }
            logoColour = await TeamCrestColourCache.shared.prevailingRGB(for: url)
        }
    }

    @ViewBuilder
    private func logo(_ image: Image) -> some View {
        let fitted = image.resizable().scaledToFit()
        if isLight, let outline = TeamCrestOutline.color(crest: logoColour, backdrop: Self.lightBackdrop) {
            fitted.silhouetteOutline(outline, width: 1 / displayScale)
        } else {
            fitted
        }
    }
}

// MARK: - Time ruler

/// The time ruler, shifted to mirror the grid's horizontal position.
struct EPGRulerStrip: View {
    let timeline: EPGTimeline
    let metrics: EPGMetrics
    let sync: EPGScrollSync

    var body: some View {
        EPGTimeRuler(timeline: timeline, metrics: metrics, sync: sync)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: metrics.headerHeight)
            .clipped()
    }
}

/// The time axis: a label every half hour; a new day adds its short date
/// so a 24-hour window stays unambiguous. Only the labels near the visible
/// window, each placed relative to the mirror: offsetting a ruler as wide as
/// the whole day (tens of thousands of points) — or a container holding
/// labels that far out — left tvOS's animated moves uncommitted, so it
/// trailed the grid.
struct EPGTimeRuler: View {
    let timeline: EPGTimeline
    let metrics: EPGMetrics
    /// Observed for `mirror` (moves) and `window` (block crossings).
    let sync: EPGScrollSync

    var body: some View {
        let mirrorX = sync.mirror.x
        let ticks = timeline.halfHourTicks(from: sync.window.start - metrics.pointsPerMinute * 30, to: sync.window.end)
        // Moves with the now line, which ticks every minute; the labels the
        // pill would cover step aside with it.
        TimelineView(.everyMinute) { context in
            ZStack(alignment: .leading) {
                ForEach(ticks, id: \.self) { tick in
                    label(tick)
                        .opacity(EPGTimeline.tickIsCoveredByNowPill(tick, now: context.date) ? 0 : 1)
                        .offset(x: timeline.x(for: tick) - mirrorX)
                }
                EPGNowPill(date: context.date, metrics: metrics)
                    .offset(x: timeline.x(for: context.date) - mirrorX)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func label(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isMidnight = calendar.component(.hour, from: date) == 0 && calendar.component(.minute, from: date) == 0
        return HStack(spacing: 8) {
            Text(date, format: .dateTime.hour().minute())
            if isMidnight {
                Text(date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .foregroundStyle(.primary.opacity(0.45))
            }
        }
        .font(metrics.rulerFont)
        .foregroundStyle(.primary.opacity(0.62))
        .lineLimit(1)
    }
}

/// The current time in the accent, centred over the now line.
struct EPGNowPill: View {
    let date: Date
    let metrics: EPGMetrics

    var body: some View {
        Text(date, format: .dateTime.hour().minute())
            .font(metrics.nowPillFont)
            .foregroundStyle(EPGColors.onAccent)
            .padding(.horizontal, metrics.headerHeight * 0.28)
            .padding(.vertical, metrics.headerHeight * 0.11)
            .background(Capsule().fill(LiveTVPalette.accent))
            .fixedSize()
            .frame(height: metrics.headerHeight)
            // Zero-width and centred on its point: an alignment guide
            // would widen the ruler's stack leftwards by half the pill
            // and push every label off its tick.
            .frame(width: 0)
    }
}

/// "Today · Fri 2 Oct" over the channel column.
struct EPGRulerCorner: View {
    let date: Date
    let metrics: EPGMetrics

    var body: some View {
        Text("Today · \(date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))")
            .font(metrics.cornerFont)
            .foregroundStyle(.primary.opacity(0.7))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.leading, metrics.channelCellPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Hint

#if os(tvOS)
    /// What the channel hub's long press offers, which nothing on screen
    /// would otherwise reveal. Never focusable.
    struct EPGGuideHint: View {
        let playlistID: UUID?
        @Environment(\.recordChannel) private var recordChannel

        /// The long press offers Record where the paired server records the
        /// guide's playlist, behind the crown if Streamen Pro has lapsed, so Pro
        /// doesn't change the hint.
        private var offersRecording: Bool {
            guard let recordChannel, let playlistID else { return false }
            return recordChannel.offersRecording(inPlaylist: playlistID)
        }

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "smallcircle.filled.circle")
                    .font(.system(size: 16))
                    .accessibilityHidden(true)
                if offersRecording {
                    Text("Hold a channel to add it to Favorites or Multi-View, or to record it")
                } else {
                    Text("Hold a channel to add it to Favorites or Multi-View")
                }
            }
            .font(.system(size: 17))
            .foregroundStyle(.white.opacity(0.5))
            .lineLimit(1)
            .padding(.leading, 16)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
#endif
