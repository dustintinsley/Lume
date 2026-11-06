//
//  MacPlayerControlBar.swift
//  Streamen
//
//  The macOS player's controls as one floating glass bar near the bottom, in
//  the style of the Mac's own media apps: transport, scrubber and the track
//  controls in a single row, the title just above. Replaces the iPhone
//  layout's large transport circles over the middle of the picture. Every
//  engine's overlay hands it its own timeline and track controls, so the bar
//  is shared and the overlays stay engine-specific.
//

import SwiftUI

#if !os(tvOS)

    struct MacPlayerControlBar<Title: View, Timeline: View, Trailing: View>: View {
        let isPlaying: Bool
        /// Live streams have no skip buttons.
        let canSkip: Bool
        let neighbours: PlayerItemNavigation.Neighbours
        let onTogglePlay: () -> Void
        let onSkip: (Double) -> Void
        let onStepItem: ((PlayerMediaSwapper.Step) -> Void)?
        let onResetHideTimer: () -> Void
        @ViewBuilder let title: Title
        @ViewBuilder let timeline: Timeline
        @ViewBuilder let trailing: Trailing

        static var skipInterval: Double {
            15
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)

                HStack(spacing: 10) {
                    transport
                    timeline
                        .frame(maxWidth: .infinity)
                    trailing
                }
                .padding(.leading, 8)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
                .glassEffectCompat(.regularInteractive, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .frame(maxWidth: 960)
        }

        private var transport: some View {
            HStack(spacing: 0) {
                if neighbours.axis != nil {
                    navButton(.previous)
                }
                if canSkip {
                    button("gobackward.15", label: "Skip back 15 seconds") { onSkip(-Self.skipInterval) }
                }
                button(isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? "Pause" : "Play", size: 20) {
                    onTogglePlay()
                }
                if canSkip {
                    button("goforward.15", label: "Skip forward 15 seconds") { onSkip(Self.skipInterval) }
                }
                if neighbours.axis != nil {
                    navButton(.next)
                }
            }
            .timelineLayoutDirection()
        }

        private func navButton(_ step: PlayerMediaSwapper.Step) -> some View {
            PlayerItemNavButton(
                step: step,
                neighbours: neighbours,
                onStep: { onStepItem?($0) },
                onResetHideTimer: onResetHideTimer,
                isCompact: true
            )
        }

        private func button(
            _ systemName: String,
            label: LocalizedStringKey,
            size: CGFloat = 16,
            action: @escaping () -> Void
        ) -> some View {
            Button {
                action()
                onResetHideTimer()
            } label: {
                MacPlayerBarGlyph.image(systemName, size: size)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        }
    }

    enum MacPlayerBarGlyph {
        /// A white glyph for a control inside `MacPlayerControlBar`. No glass
        /// of its own: the bar is the one glass surface.
        static func image(_ systemName: String, size: CGFloat = 16, dimmed: Bool = false) -> some View {
            Image(systemName: systemName)
                .symbolReplaceTransition(value: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(dimmed ? .white.opacity(0.55) : .white)
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
    }

    extension View {
        /// The track controls' grouped glass pill. On macOS they sit inside
        /// `MacPlayerControlBar`, which is already glass, so the pill draws none.
        @ViewBuilder
        func trackPillGlass() -> some View {
            #if os(macOS)
                self
            #else
                glassEffectCompat(.regularInteractive, in: Capsule())
            #endif
        }
    }

#endif
