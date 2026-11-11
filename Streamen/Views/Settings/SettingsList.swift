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
        #else
            List {
                content
            }
        #endif
    }
}
