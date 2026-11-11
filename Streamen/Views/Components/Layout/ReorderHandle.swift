//
//  ReorderHandle.swift
//  Streamen
//

import SwiftUI

extension View {
    /// The three-line grip iOS shows on a reorderable row in edit mode. A Mac
    /// list drags `onMove` rows without one, so nothing would say they move;
    /// elsewhere the system draws its own. `shown` is false while the rows
    /// can't move (a filtered list), so no grip promises a drag.
    func reorderHandle(_ shown: Bool = true) -> some View {
        #if os(macOS)
            HStack(spacing: 8) {
                self
                if shown {
                    Spacer(minLength: 0)
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        #else
            self
        #endif
    }
}
