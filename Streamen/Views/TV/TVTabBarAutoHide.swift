//
//  TVTabBarAutoHide.swift
//  Streamen
//
//  Fades the tvOS tab bar out whenever focus is anywhere but the bar, and
//  back in the moment focus reaches it. Faded rather than hidden: the bar
//  stays in the layout and focusable, so Up from a screen's top row and Menu
//  from its top level still land on it the way they always have, and nothing
//  on the screen moves when it comes and goes.
//

#if os(tvOS)
    import SwiftUI
    import UIKit

    @MainActor
    final class TVTabBarAutoHider {
        static let shared = TVTabBarAutoHider()

        /// Low enough to read as gone, above the 0.01 below which UIKit stops
        /// treating a view as visible and the focus engine skips it.
        private static let fadedAlpha: CGFloat = 0.011
        private static let fadeDuration: TimeInterval = 0.25

        private weak var tabBar: UITabBar?
        private var observer: NSObjectProtocol?

        func start() {
            guard observer == nil else { return }
            observer = NotificationCenter.default.addObserver(
                forName: UIFocusSystem.didUpdateNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                let context = note.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext
                let next = context?.nextFocusedItem
                MainActor.assumeIsolated {
                    self?.focusDidMove(to: next)
                }
            }
        }

        /// SwiftUI content reports its focus items as plain `UIFocusItem`s,
        /// not views; only the tab bar's own buttons are views inside it.
        private func focusDidMove(to item: UIFocusItem?) {
            guard item != nil, let window = Self.keyWindow, let tabBar = tabBar(in: window) else { return }
            let inTabBar = (item as? UIView)?.isDescendant(of: tabBar) ?? false
            let target: CGFloat = inTabBar ? 1 : Self.fadedAlpha
            guard tabBar.alpha != target else { return }
            UIView.animate(withDuration: Self.fadeDuration, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                tabBar.alpha = target
            }
        }

        private static var keyWindow: UIWindow? {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first
        }

        /// The root tab bar, found once per window and kept weakly.
        private func tabBar(in window: UIWindow) -> UITabBar? {
            if let tabBar, tabBar.window === window { return tabBar }
            let found = Self.firstTabBar(under: window)
            tabBar = found
            return found
        }

        private static func firstTabBar(under view: UIView) -> UITabBar? {
            if let tabBar = view as? UITabBar { return tabBar }
            for subview in view.subviews {
                if let tabBar = firstTabBar(under: subview) { return tabBar }
            }
            return nil
        }
    }

    extension View {
        /// Starts the tab bar's auto-hide (see `TVTabBarAutoHider`). Idempotent,
        /// so every tab's content can carry it.
        func tvAutoHidingTabBar() -> some View {
            onAppear { TVTabBarAutoHider.shared.start() }
        }
    }
#endif
