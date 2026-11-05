//
//  GoMenuCommands.swift
//  Streamen
//
//  The macOS Go menu: jump between the main window's tabs from the menu bar
//  or with ⌘1–⌘5 and ⌘F. The window that has focus hands the menu its
//  router through a focused value, so the commands follow whichever main
//  window is in front and grey out when none is.
//

import SwiftUI

/// What the Go menu drives: the focused window's router and which tabs its
/// active playlist shows.
struct GoMenuTarget {
    let router: DeepLinkRouter
    let isAvailable: (AppTab) -> Bool
}

extension FocusedValues {
    @Entry var goMenuTarget: GoMenuTarget?
}

extension View {
    /// Offers this window's tabs to the Go menu while it has focus. A no-op
    /// off macOS.
    func goMenuSource(_ router: DeepLinkRouter, isAvailable: @escaping (AppTab) -> Bool) -> some View {
        #if os(macOS)
            focusedSceneValue(\.goMenuTarget, GoMenuTarget(router: router, isAvailable: isAvailable))
        #else
            self
        #endif
    }
}

#if os(macOS)

    struct GoMenuCommands: Commands {
        @FocusedValue(\.goMenuTarget) private var target

        var body: some Commands {
            CommandMenu("Go") {
                item("Home", tab: .home, key: "1")
                item("Movies", tab: .movies, key: "2")
                item("Series", tab: .series, key: "3")
                item("Live TV", tab: .liveTV, key: "4")
                item("Sports", tab: .sports, key: "5")
                Divider()
                item("Search", tab: .search, key: "f")
            }
        }

        private func item(_ title: LocalizedStringKey, tab: AppTab, key: KeyEquivalent) -> some View {
            Button(title) {
                target?.router.selectedTab = tab
            }
            .keyboardShortcut(key, modifiers: .command)
            .disabled(target?.isAvailable(tab) != true)
        }
    }

#endif
