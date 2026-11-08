//
//  DetailLoadingRow.swift
//  Streamen
//
//  The small "Loading details…" line a movie or series page shows under its
//  hero while TMDB details are still on their way. The page itself is up from
//  the start; this only says more is coming.
//

import SwiftUI

struct DetailLoadingRow: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            #if !os(tvOS)
                .controlSize(.small)
            #endif
            Text("Loading details…")
                .foregroundStyle(.secondary)
        }
        #if os(tvOS)
        .font(.system(size: 26))
        #else
        .font(.subheadline)
        #endif
        .transition(.opacity)
    }
}
