//
//  LiveChannelCatchup.swift
//  Streamen
//
//  Catch-up from a channel's long-press menu, for the List layout, which has
//  no timeline to tap a past programme on: "Watch from Start" restarts the
//  programme on now, and "Catch Up…" opens the channel's past programmes by
//  day. Both reuse the Guide's rules — `PlayableMedia.isCatchupCapable`, the
//  archive window and `isCatchupAvailable` — so they offer exactly what the
//  Guide would.
//
//  The sheet lists the stored guide merged with what the channel's Xtream
//  panel reports (`get_simple_data_table`): a panel's XMLTV feed usually
//  starts today, so the stored guide alone has no earlier days to offer.
//
//  The host installs the actions with `catchupChannelFlow(play:)`; the menu
//  items read them from the environment, like the Record item, so the many
//  places that build a channel menu needn't each be handed a callback. Where
//  no flow is installed the items hide.
//

import OSLog
import SwiftData
import SwiftUI

/// What a channel menu needs to offer catch-up: play one airing, or list them.
struct CatchupChannelAction {
    let play: (LiveStream, EPGProgramCell) -> Void
    let showList: (LiveStream) -> Void
}

extension EnvironmentValues {
    @Entry var catchupChannel: CatchupChannelAction?
}

extension View {
    /// Offers catch-up from the channel menus below this view, playing a
    /// chosen airing with `play`. Owns the programme list sheet; a channel's
    /// archive listing is asked of whichever of `playlists` owns it, so a
    /// combined library's channels each reach their own account.
    func catchupChannelFlow(
        playlists: [Playlist],
        play: @escaping (LiveStream, EPGProgramCell) -> Void
    ) -> some View {
        modifier(CatchupChannelFlow(playlists: playlists, play: play))
    }
}

private struct CatchupChannelFlow: ViewModifier {
    let playlists: [Playlist]
    let play: (LiveStream, EPGProgramCell) -> Void
    @State private var listedStream: LiveStream?

    func body(content: Content) -> some View {
        content
            .environment(\.catchupChannel, CatchupChannelAction(play: play, showList: { listedStream = $0 }))
            .sheet(item: $listedStream) { stream in
                CatchupProgrammeList(stream: stream, archive: CatchupArchiveSource(stream: stream, playlist: playlists.owner(ofContentID: stream.id))) { cell in
                    listedStream = nil
                    play(stream, cell)
                }
            }
    }
}

// MARK: - Menu items

/// "Watch from Start" and "Catch Up…", for a catch-up channel under a
/// `catchupChannelFlow`. Its own view so the now-programme lookup runs only
/// when the menu is built.
struct LiveChannelCatchupItems: View {
    let stream: LiveStream
    @Environment(\.catchupChannel) private var catchup
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let catchup, PlayableMedia.isCatchupCapable(stream: stream) {
            if let onNow = programmeOnNow() {
                Button {
                    catchup.play(stream, onNow)
                } label: {
                    Label("Watch from Start", systemImage: "backward.end")
                }
            }
            Button {
                catchup.showList(stream)
            } label: {
                Label("Catch Up…", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    /// The programme airing now, when its start is still inside the archive.
    private func programmeOnNow() -> EPGProgramCell? {
        guard let channelId = stream.epgChannelId, !channelId.isEmpty else { return nil }
        let now = Date()
        var descriptor = FetchDescriptor<EPGListing>(
            predicate: #Predicate { $0.channelId == channelId && $0.start <= now && $0.end > now }
        )
        descriptor.fetchLimit = 1
        guard let listing = try? modelContext.fetch(descriptor).first,
              PlayableMedia.isCatchupAvailable(stream: stream, start: listing.start, now: now)
        else { return nil }
        return CatchupProgrammeList.cell(
            for: EPGWindowListing(
                id: listing.id, title: listing.title, detail: listing.listingDescription,
                start: listing.start, end: listing.end
            )
        )
    }
}

// MARK: - Programme list

/// A channel's replayable programmes, newest first, grouped by day: the
/// archive window up to the programme on now.
struct CatchupProgrammeList: View {
    let stream: LiveStream
    let archive: CatchupArchiveSource?
    let onPlay: (EPGProgramCell) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var days: [Day]?

    struct Day: Identifiable {
        let date: Date
        let programmes: [EPGProgramCell]
        var id: Date {
            date
        }
    }

    var body: some View {
        NavigationStack {
            content
                .platformNavigationTitle("Catch Up")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        // A macOS sheet sizes to its content, and a List has none to offer:
        // without a floor the sheet opens collapsed and the list looks empty.
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 480, idealHeight: 600)
        #endif
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let days {
            if days.isEmpty {
                ContentUnavailableView(
                    "No Past Programmes",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("The guide has no programmes for this channel inside its catch-up window.")
                )
            } else {
                List {
                    Section {
                        Text(stream.name).font(.headline)
                    }
                    ForEach(days) { day in
                        Section {
                            ForEach(day.programmes) { programme in
                                row(programme)
                            }
                        } header: {
                            Text(Self.dayTitle(day.date))
                        }
                    }
                }
            }
        } else {
            ProgressView()
        }
    }

    private func row(_ programme: EPGProgramCell) -> some View {
        Button {
            onPlay(programme)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(programme.start, format: .dateTime.hour().minute())
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 64, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(programme.title)
                        .foregroundStyle(.primary)
                    if programme.isLive(at: Date()) {
                        Text("On Now")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LiveTVPalette.accent)
                    } else if !programme.detail.isEmpty {
                        Text(programme.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Fetches the archive window off the main thread, merges in the panel's
    /// listing, keeps what is still replayable, and groups it by day.
    private func load() async {
        let container = modelContext.container
        let now = Date()
        let windowStart = now.addingTimeInterval(-Double(PlayableMedia.guideArchiveWindowDays(for: stream)) * 86400)
        var stored: [EPGWindowListing] = []
        if let channelId = stream.epgChannelId, !channelId.isEmpty {
            stored = await Task.detached(priority: .userInitiated) {
                EPGGuideLoader.load(container: container, channelIds: [channelId], windowStart: windowStart, windowEnd: now)
            }.value[channelId] ?? []
        }
        let fromPanel = await archive?.listings() ?? []
        Logger.network.info(
            "catch-up list: \(stored.count) stored listings, panel \(archive == nil ? "not asked" : "asked", privacy: .public)"
        )

        let playable = Self.merged(stored: stored, panel: fromPanel)
            .filter { $0.start < now && PlayableMedia.isCatchupAvailable(stream: stream, start: $0.start, now: now) }
            .sorted { $0.start > $1.start }
            .map(Self.cell(for:))
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: playable) { calendar.startOfDay(for: $0.start) }
        days = grouped.keys.sorted(by: >).map { Day(date: $0, programmes: grouped[$0] ?? []) }
    }

    /// The stored guide plus the panel's airings it lacks, matched by start
    /// minute; the stored listing wins, as it is what the Guide shows.
    static func merged(stored: [EPGWindowListing], panel: [EPGWindowListing]) -> [EPGWindowListing] {
        let minute = { (date: Date) in Int(date.timeIntervalSince1970 / 60) }
        let storedStarts = Set(stored.map { minute($0.start) })
        return stored + panel.filter { !storedStarts.contains(minute($0.start)) }
    }

    /// The airing as the cell the catch-up player takes; it needs only the
    /// title and the window.
    static func cell(for listing: EPGWindowListing) -> EPGProgramCell {
        EPGProgramCell(
            id: listing.id, title: listing.title, detail: listing.detail,
            start: listing.start, end: listing.end, listingID: listing.id, isGap: false, width: 0
        )
    }

    /// "Today", "Yesterday", then the weekday and date.
    static func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

// MARK: - Panel archive listing

/// The Xtream account that can list a channel's archive: an Xtream playlist's
/// own, or the panel named in an m3u channel's Xtream-shaped URL. Holds
/// credentials: never log one.
struct CatchupArchiveSource {
    let serverURL: String
    let username: String
    let password: String
    let streamId: Int

    init?(stream: LiveStream, playlist: Playlist?) {
        if let playlist, playlist.sourceType == .xtream {
            self.init(serverURL: playlist.serverURL, username: playlist.username, password: playlist.password, streamId: stream.streamId)
        } else if let address = ContentSyncManager.discoverableAddress(stream.directURL) {
            self.init(serverURL: address.serverURL, username: address.username, password: address.password, streamId: address.streamId)
        } else {
            return nil
        }
    }

    init(serverURL: String, username: String, password: String, streamId: Int) {
        self.serverURL = serverURL
        self.username = username
        self.password = password
        self.streamId = streamId
    }

    /// The panel's airings for the channel; empty when the panel can't say.
    func listings() async -> [EPGWindowListing] {
        do {
            let airings = try await XtreamClient().getFullEPG(
                serverURL: serverURL, username: username, password: password, streamId: streamId
            )
            let listings = Self.listings(from: airings)
            // Counts only: the request carries the account.
            Logger.network.info("catch-up list: panel sent \(airings.count) airings, \(listings.count) usable")
            return listings
        } catch {
            Logger.network.info("catch-up list: panel did not answer (\(ContentSyncManager.redactedReason(error), privacy: .public))")
            return []
        }
    }

    static func listings(from airings: [XtreamDataTableEPG]) -> [EPGWindowListing] {
        airings.compactMap { airing in
            guard let start = airing.start, let end = airing.end, end > start,
                  let title = airing.title, !title.isEmpty
            else { return nil }
            return EPGWindowListing(
                id: "panel-\(Int(start.timeIntervalSince1970))",
                title: title,
                detail: airing.description ?? "",
                start: start,
                end: end
            )
        }
    }
}
