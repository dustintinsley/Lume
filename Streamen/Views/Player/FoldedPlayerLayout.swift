//
//  FoldedPlayerLayout.swift
//  Streamen
//
//  iPhone Duo support for the player: while the phone stands half-folded with
//  the fold running across the screen, the video moves to the upper screen
//  and the controls to the lower one, with a reflection of the picture
//  behind them (`FoldedReflectionView`). Opt-in under Settings ▸ Player ▸
//  Folded Screen Reflection; every engine supplies the reflection its frames
//  through a `ReflectionFrameSource`.
//
//  `FullScreenPlayerView` hosts a `HingeFoldReader` and publishes the fold
//  through `\.playerFold`; the engines place their layers with
//  `foldedAboveHinge` / `foldedBelowHinge`. With no fold (the setting off,
//  another device, or the phone flat or closed) both modifiers are no-ops.
//

import SwiftUI

/// Where the fold crosses the screen, in window coordinates (points from the
/// top of the full-screen player).
struct PlayerFold: Equatable {
    /// Top edge of the hinge's division region: the upper screen ends here.
    var upperEdge: CGFloat
    /// Bottom edge of the division region: the lower screen starts here.
    var lowerEdge: CGFloat
    /// Full height of the window the regions were measured in.
    var windowHeight: CGFloat

    var upperHeight: CGFloat {
        upperEdge
    }

    var lowerHeight: CGFloat {
        max(0, windowHeight - lowerEdge)
    }
}

extension EnvironmentValues {
    /// Set by `FullScreenPlayerView` while the reflection setting is on and the
    /// phone is half-folded; nil otherwise.
    @Entry var playerFold: PlayerFold?
}

/// Publishes `\.playerFold` to the player's engines while the setting is on.
/// Applied once, on `FullScreenPlayerView`.
struct PlayerFoldTracking: ViewModifier {
    @AppStorage(PlayerSettings.FoldedReflection.enabledKey)
    private var enabled = PlayerSettings.FoldedReflection.enabledDefault
    @State private var fold: PlayerFold?

    func body(content: Content) -> some View {
        #if os(iOS)
            content
                .background {
                    if enabled {
                        HingeFoldReader { fold = $0 }
                            .ignoresSafeArea()
                    }
                }
                .environment(\.playerFold, enabled ? fold : nil)
                .animation(.easeInOut(duration: 0.3), value: fold)
        #else
            content
        #endif
    }
}

extension View {
    /// Confines a full-bleed player layer (the video surface, its subtitles) to
    /// the upper screen while folded. Replaces the layer's own
    /// `.ignoresSafeArea()`.
    func foldedAboveHinge(_ fold: PlayerFold?) -> some View {
        padding(.bottom, fold.map { $0.windowHeight - $0.upperEdge } ?? 0)
            .ignoresSafeArea()
    }

    /// Keeps a layer that respects the safe area (subtitles) on the upper
    /// screen with the video while folded. The bottom inset is replaced by the
    /// fold.
    @ViewBuilder
    func foldedAboveHingeInSafeArea(_ fold: PlayerFold?) -> some View {
        if let fold {
            padding(.bottom, fold.windowHeight - fold.upperEdge)
                .ignoresSafeArea(edges: .bottom)
        } else {
            self
        }
    }

    /// Moves a layer that respects the safe area (the controls) onto the lower
    /// screen while folded. The top inset is replaced by the fold; the side and
    /// bottom insets still apply.
    @ViewBuilder
    func foldedBelowHinge(_ fold: PlayerFold?) -> some View {
        if let fold {
            padding(.top, fold.lowerEdge)
                .ignoresSafeArea(edges: .top)
        } else {
            self
        }
    }
}

#if os(iOS)
    import UIKit

    /// Invisible probe that reports the fold. Sits behind the player, sized to
    /// the window, and re-measures whenever the hinge moves or the layout
    /// changes (rotation, size).
    struct HingeFoldReader: UIViewRepresentable {
        var onChange: (PlayerFold?) -> Void

        func makeUIView(context _: Context) -> HingeProbeView {
            let view = HingeProbeView()
            view.onChange = onChange
            return view
        }

        func updateUIView(_ view: HingeProbeView, context _: Context) {
            view.onChange = onChange
        }
    }

    final class HingeProbeView: UIView {
        var onChange: ((PlayerFold?) -> Void)?
        private var isHalfOpen = false
        private var lastFold: PlayerFold?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear
            if #available(iOS 27.1, *) {
                addInteraction(UIHingeInteraction { [weak self] _, update in
                    // A nil hinge: the hierarchy has none (any non-foldable
                    // device) or the view left the window.
                    self?.isHalfOpen = update.hinge?.status == .partiallyOpen
                    self?.measure()
                })
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            measure()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            measure()
        }

        private func measure() {
            let fold = currentFold()
            guard fold != lastFold else { return }
            lastFold = fold
            onChange?(fold)
        }

        private func currentFold() -> PlayerFold? {
            #if DEBUG
                // `-simulate-fold`: pretend the phone stands half-folded with
                // the fold across the middle of a landscape window, so the
                // layout can be tried where no hinge can be moved.
                if CommandLine.arguments.contains("-simulate-fold"), let window,
                   window.bounds.width > window.bounds.height
                {
                    let middle = window.bounds.height / 2
                    return PlayerFold(upperEdge: middle - 6, lowerEdge: middle + 6, windowHeight: window.bounds.height)
                }
            #endif
            guard isHalfOpen, let window else { return nil }
            guard #available(iOS 27.1, *) else { return nil }
            let division = window.reservedRegions(kind: .division)
                .first { $0.isActive }
            // Only a fold running across the screen (the phone stood up like a
            // laptop) splits the picture into upper and lower halves; held the
            // other way the fold is vertical and the player stays as it is.
            guard let rect = division?.frame, rect.width > rect.height else { return nil }
            let bounds = window.bounds
            // Guard against a region that leaves too little room on either
            // side to be worth splitting.
            guard rect.minY > bounds.height * 0.25, rect.maxY < bounds.height * 0.75 else { return nil }
            return PlayerFold(upperEdge: rect.minY, lowerEdge: rect.maxY, windowHeight: bounds.height)
        }
    }
#endif
