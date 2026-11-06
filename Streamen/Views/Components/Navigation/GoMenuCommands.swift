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
    /// Offers this window's tabs to the Go menu while it has focus, and
    /// presents the Settings sheet the app menu's Settings… item asks for. A
    /// no-op off macOS.
    func goMenuSource(_ router: DeepLinkRouter, isAvailable: @escaping (AppTab) -> Bool) -> some View {
        #if os(macOS)
            modifier(GoMenuSource(router: router, isAvailable: isAvailable))
        #else
            self
        #endif
    }
}

#if os(macOS)
    private struct GoMenuSource: ViewModifier {
        @Bindable var router: DeepLinkRouter
        let isAvailable: (AppTab) -> Bool

        func body(content: Content) -> some View {
            content
                .focusedSceneValue(\.goMenuTarget, GoMenuTarget(router: router, isAvailable: isAvailable))
                // The same sheet the toolbar gear opens, reporting itself the
                // way that one does (see `LibraryToolbarModifier`).
                .sheet(
                    isPresented: $router.isMenuSettingsPresented,
                    onDismiss: { ScreenOccupancy.shared.noteBlockingSheetDismissed() },
                    content: {
                        SettingsView()
                            .onAppear { ScreenOccupancy.shared.noteBlockingSheetAppeared() }
                    }
                )
        }
    }
#endif

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

    /// Streamen › Settings… (⌘,): the Settings sheet over the focused
    /// main window, in place of the system's own item.
    struct SettingsCommands: Commands {
        @FocusedValue(\.goMenuTarget) private var target

        var body: some Commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { target?.router.isMenuSettingsPresented = true }
                    .keyboardShortcut(",", modifiers: .command)
                    .disabled(target == nil)
            }
        }
    }

#endif
