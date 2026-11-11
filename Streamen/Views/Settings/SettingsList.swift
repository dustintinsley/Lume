//
//  SettingsList.swift
//  Streamen
//

import SwiftUI

/// A settings page's list. On macOS it takes System Settings' grouped look,
/// each section a rounded box with separators only between its rows, rather
/// than a table's edge-to-edge lines; elsewhere it is the platform's list.
struct SettingsList<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        #if os(macOS)
            Form {
                content
            }
            .formStyle(.grouped)
            .settingsBackButton()
        #else
            List {
                content
            }
        #endif
    }
}

extension View {
    /// A page pushed inside the Mac Settings window gets its Back button in
    /// the page: the system one lands in the window toolbar among the tabs,
    /// where it shows as a tab and doesn't go back. A no-op elsewhere and on
    /// a tab's first page.
    func settingsBackButton() -> some View {
        #if os(macOS)
            modifier(SettingsBackButton())
        #else
            self
        #endif
    }
}

#if os(macOS)
    extension EnvironmentValues {
        /// Set on each Mac Settings tab's first page, which has nothing to go
        /// back to: `isPresented` is true there too, the Settings window
        /// counting as presented.
        @Entry var isSettingsRootPage = false
    }

    private struct SettingsBackButton: ViewModifier {
        @Environment(\.isPresented) private var isPresented
        @Environment(\.isSettingsRootPage) private var isRootPage
        @Environment(\.dismiss) private var dismiss

        func body(content: Content) -> some View {
            if isPresented, !isRootPage {
                content
                    .navigationBarBackButtonHidden(true)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Label("Back", systemImage: "chevron.backward")
                            }
                            .buttonStyle(.borderless)
                            .keyboardShortcut("[", modifiers: .command)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
            } else {
                content
            }
        }
    }
#endif
