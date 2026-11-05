//
//  MacHoverButtonStyles.swift
//  Streamen
//
//  The pointer's answer to tvOS focus: on macOS a card lifts under the
//  pointer and settles when pressed, and a list row takes a soft highlight,
//  so the browse screens read as clickable without a click.
//

#if os(macOS)

    import SwiftUI

    /// Posters and tiles: a small lift and shadow on hover, a press-in on click.
    struct MacCardButtonStyle: ButtonStyle {
        var hoverScale: CGFloat = 1.03

        func makeBody(configuration: Configuration) -> some View {
            HoverBody(configuration: configuration, hoverScale: hoverScale)
        }

        private struct HoverBody: View {
            let configuration: Configuration
            let hoverScale: CGFloat
            @State private var isHovered = false

            var body: some View {
                configuration.label
                    .scaleEffect(configuration.isPressed ? 0.97 : isHovered ? hoverScale : 1)
                    .shadow(color: .black.opacity(isHovered ? 0.25 : 0), radius: isHovered ? 12 : 0, y: isHovered ? 6 : 0)
                    // Above its neighbours while lifted, so the shadow isn't
                    // drawn under the next card.
                    .zIndex(isHovered ? 1 : 0)
                    .animation(.snappy(duration: 0.18), value: isHovered)
                    .animation(.snappy(duration: 0.12), value: configuration.isPressed)
                    .onHover { isHovered = $0 }
            }
        }
    }

    /// Full-width list rows: a rounded highlight under the pointer.
    struct MacRowButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            HoverBody(configuration: configuration)
        }

        private struct HoverBody: View {
            let configuration: Configuration
            @State private var isHovered = false

            var body: some View {
                configuration.label
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.primary.opacity(configuration.isPressed ? 0.12 : isHovered ? 0.06 : 0))
                            .padding(.horizontal, 6)
                    }
                    .animation(.easeOut(duration: 0.12), value: isHovered)
                    .onHover { isHovered = $0 }
            }
        }
    }

#endif
