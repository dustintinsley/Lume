//
//  EPGHeroInfo.swift
//  Streamen
//
//  The tvOS Guide hero's left-hand block: what the focused channel is airing
//  now — its title, time, progress and description. It follows the focused row on every press, while
//  the picture beside it waits for the preview to settle.
//

#if os(tvOS)
    import SwiftUI

    /// The only reader of `GuideHeroModel.focusedRow`, so a press
    /// re-renders this block and nothing above it.
    struct EPGHeroInfo: View {
        let hero: GuideHeroModel?
        /// Described while focus is outside the guide.
        let settled: EPGChannelRow?

        @Environment(\.epgHeroLayout) private var layout

        var body: some View {
            if let channel = hero?.focusedRow ?? settled {
                TimelineView(.everyMinute) { context in
                    EPGHeroInfoContent(channel: channel, now: context.date, isCompact: layout.isCompact)
                }
            }
        }
    }

    private struct EPGHeroInfoContent: View {
        let channel: EPGChannelRow
        let now: Date
        /// The small hero: a smaller title, no separate time line (the
        /// progress row still places the programme in time) and a shorter
        /// description.
        let isCompact: Bool

        private static let description = Color.white.opacity(0.62)
        private static let meta = Color.white.opacity(0.7)

        var body: some View {
            let current = GuidePreviewPolicy.currentProgramme(in: channel.cells, at: now)

            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let current {
                        Text(current.title)
                    } else {
                        Text("No programme information")
                    }
                }
                .font(.system(size: isCompact ? 32 : 40, weight: .bold))
                .tracking(-0.4)
                .lineLimit(1)
                .truncationMode(.tail)

                if let current {
                    if !isCompact {
                        Text(current.start ..< current.end, format: .interval.hour().minute())
                            .font(.system(size: 24))
                            .foregroundStyle(Self.meta)
                            .lineLimit(1)
                            .padding(.top, 10)
                    }

                    progress(of: current)
                        .padding(.top, isCompact ? 14 : 18)

                    if !current.detail.isEmpty {
                        Text(current.detail)
                            .font(.system(size: 22))
                            .foregroundStyle(Self.description)
                            .lineLimit(isCompact ? 2 : 4)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, isCompact ? 12 : 16)
                    }
                }
            }
            .foregroundStyle(.white)
        }

        private func progress(of programme: EPGProgramCell) -> some View {
            HStack(spacing: 16) {
                EPGProgressBar(
                    progress: programme.progress(at: now),
                    track: .white.opacity(0.18),
                    fill: LiveTVPalette.accent,
                    height: 6
                )
                .frame(width: 360)

                Text("\(GuidePreviewPolicy.minutesLeft(of: programme, at: now)) min left")
                    .font(.system(size: 20))
                    .foregroundStyle(Self.meta)
                    .lineLimit(1)
            }
        }
    }
#endif
