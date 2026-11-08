//
//  StartOverButton.swift
//  Streamen
//
//  Start from Beginning, under a movie's or episode's Resume button.
//

import SwiftUI

/// The detail pages' second play button, under Resume: plays from the start.
struct StartOverButton: View {
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Start from Beginning", systemImage: "arrow.counterclockwise")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(!isEnabled)
    }
}
