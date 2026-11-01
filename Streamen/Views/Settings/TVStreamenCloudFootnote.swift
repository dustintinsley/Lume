//
//  TVStreamenCloudFootnote.swift
//  Streamen
//

#if os(tvOS)

    import SwiftUI

    extension View {
        /// The Streamen Cloud steps' explanatory or error line under a row, inset
        /// to line up with the row labels.
        func tvStreamenCloudFootnote(isError: Bool = false) -> some View {
            font(.system(size: 22))
                .foregroundStyle(isError ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .padding(.horizontal, TVSettingsMetrics.rowHPadding)
        }
    }

#endif
