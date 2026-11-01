//
//  StreamenCloudMovedNotice.swift
//  Streamen
//
//  The one-time "Sync moved to Streamen Cloud" alert, raised at the root after
//  another Apple device moved this one to Streamen Cloud
//  (`SyncedBackendChoiceWatcher` queues it). Older builds on the user's other
//  devices stay on iCloud, so it asks for an update there.
//
//  Waits for the safe moment `RootNoticeGate` defines.
//

import SwiftUI

extension View {
    /// Shows the queued "Sync moved to Streamen Cloud" alert once. A no-op outside
    /// CloudKit builds, which never hand off between Apple devices.
    func streamenCloudMovedNotice() -> some View {
        modifier(StreamenCloudMovedNoticeModifier(isEnabled: StreamenApp.isCloudKitEnvironment))
    }
}

private struct StreamenCloudMovedNoticeModifier: ViewModifier {
    let isEnabled: Bool

    @AppStorage(StreamenCloudSettings.Key.movedNoticePending) private var isPending = false
    @AppStorage(StreamenCloudSettings.Key.movedNoticeShown) private var wasShown = false
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .alert("Sync moved to Streamen Cloud", isPresented: $isPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Update Streamen on your other devices so they keep syncing.")
            }
            .rootNoticeGate(canShow: isEnabled && isPending && !wasShown, isPresented: $isPresented) {
                wasShown = true
                isPending = false
            }
    }
}
