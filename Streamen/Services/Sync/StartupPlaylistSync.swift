//
//  StartupPlaylistSync.swift
//  Streamen
//
//  Runs automatic refreshes ("Sync at Startup" and the scheduled sync) without
//  the blocking sync cover. A playlist that has synced before already has a
//  catalog to browse, so its refresh happens in the background, one playlist at a time, and the library
//  toolbar (a corner badge on tvOS) shows a spinner while it runs. A playlist
//  that has never synced still goes through the cover — there is nothing to
//  browse until it finishes.
//

import SwiftData
import SwiftUI

@Observable
final class StartupPlaylistSync {
    static let shared = StartupPlaylistSync()

    /// Name of the playlist syncing right now; nil while idle.
    private(set) var currentName: String?
    /// The last background refresh that failed, until the viewer looks at it.
    private(set) var failedPlaylistID: UUID?
    private(set) var failedPlaylistName: String?

    private var queue: [Playlist] = []
    private var worker: Task<Void, Never>?

    var isSyncing: Bool {
        currentName != nil
    }

    /// Takes a due playlist off the cover's hands when it already has a
    /// catalog to browse. Returns the playlist when it still belongs in the
    /// cover queue (never synced), nil when it was queued here instead. Manual
    /// syncs never come through here, so they keep the cover.
    func claim(_ playlist: Playlist, in container: ModelContainer) -> Playlist? {
        let quiet = playlist.lastSyncDate != nil
        let noted = playlist.notingStartupSync()
        guard quiet else { return noted }
        queue.append(noted)
        if worker == nil {
            worker = Task { await drain(container) }
        }
        return nil
    }

    func clearFailure() {
        failedPlaylistID = nil
        failedPlaylistName = nil
    }

    private func drain(_ container: ModelContainer) async {
        while !queue.isEmpty {
            let playlist = queue.removeFirst()
            currentName = playlist.name
            await sync(playlist, in: container)
        }
        currentName = nil
        worker = nil
    }

    /// The same run as the cover's `SyncProgressView.startSync`, minus the UI:
    /// paired guide-refresh notifications, a background-activity assertion,
    /// and a fresh indexing pass on success.
    private func sync(_ playlist: Playlist, in container: ModelContainer) async {
        let epgSync = EPGSyncService.shared
        epgSync.contentSyncDidStart()
        var succeeded = false
        defer { epgSync.contentSyncDidFinish(succeeded: succeeded) }
        do {
            let manager = ContentSyncManager(modelContainer: container)
            try await BackgroundActivity.perform("Playlist sync") {
                try await manager.syncPlaylist(playlist)
            }
            succeeded = true
            ContentIndexingService.shared.kick(after: .seconds(3))
        } catch {
            failedPlaylistID = playlist.id
            failedPlaylistName = playlist.name
        }
    }
}

// MARK: - Indicators

/// Toolbar spinner while a startup refresh or a TV guide refresh runs, and a
/// warning button after a startup refresh fails (tapping it opens the active playlist's sync sheet when it was that
/// playlist). iOS and macOS only — tvOS uses `startupSyncBadge()`.
struct StartupSyncToolbarItem: ToolbarContent {
    let activePlaylistID: UUID?
    @Binding var showingSync: Bool

    var body: some ToolbarContent {
        let sync = StartupPlaylistSync.shared
        if let name = sync.currentName {
            ToolbarItem(placement: .automatic) {
                ToolbarSpinner(title: "Syncing \(name)")
                    .help("Syncing \(name)…")
            }
        } else if let failedID = sync.failedPlaylistID {
            ToolbarItem(placement: .automatic) {
                Button {
                    sync.clearFailure()
                    if failedID == activePlaylistID { showingSync = true }
                } label: {
                    Label(
                        "Couldn't sync \(sync.failedPlaylistName ?? "playlist")",
                        systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                    )
                }
                .tint(.orange)
            }
        } else if EPGSyncService.shared.isSyncing {
            ToolbarItem(placement: .automatic) {
                ToolbarSpinner(title: "Updating the TV guide")
                    .help("Updating the TV guide…")
            }
        }
    }
}

/// A spinner shaped like the toolbar's icon buttons — Settings beside it — so
/// it gets the same round glass. A bare `ProgressView` item stretches across
/// the item instead, and its glass turns into a pill. It does nothing when
/// clicked; VoiceOver reads it as status, not a button.
private struct ToolbarSpinner: View {
    let title: LocalizedStringKey

    var body: some View {
        Button {} label: {
            Label {
                Text(title)
            } icon: {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .accessibilityRemoveTraits(.isButton)
    }
}

extension View {
    /// tvOS has no library toolbar, so a startup refresh shows as a small
    /// spinner badge in the top-trailing corner instead.
    @ViewBuilder
    func startupSyncBadge() -> some View {
        #if os(tvOS)
            overlay(alignment: .topTrailing) {
                if let name = StartupPlaylistSync.shared.currentName {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Syncing \(name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .padding(40)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .animation(.default, value: StartupPlaylistSync.shared.currentName)
        #else
            self
        #endif
    }
}
