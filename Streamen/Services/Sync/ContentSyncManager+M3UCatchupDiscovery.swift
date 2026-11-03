//
//  ContentSyncManager+M3UCatchupDiscovery.swift
//  Streamen
//
//  Catch-up for m3u playlists that don't declare it.
//
//  An m3u exported from an Xtream panel (`get.php?…&type=m3u_plus`) often
//  carries no catch-up attributes at all, while the panel itself records an
//  archive for many channels — so the importer, which only trusts what the file
//  says (`ContentSyncManager+M3UCatchup`), leaves those channels without one.
//  Their stream URLs still name the panel and the account
//  (`…/live/{user}/{pass}/{id}.ts`), so after each import this asks every such
//  panel once for its live list (`get_live_streams`, the request an Xtream
//  playlist sync already makes) and gives the channels it archives the `xc`
//  dialect, whose URL builder already serves m3u channels.
//
//  Only fills gaps: a channel the importer gave catch-up keeps its own, the
//  playlist itself is never rewritten, and a panel that fails or answers
//  partially changes nothing. Re-runs after every sync, because an import that
//  rewrites a channel resets its catch-up columns to what the file declares.
//
//  Account credentials are in every candidate URL: never log one.
//

import Foundation
import OSLog
import SwiftData

extension ContentSyncManager {
    /// Fills in catch-up an m3u playlist's file didn't declare, from each
    /// channel's own Xtream panel. Best-effort: a panel that can't be reached
    /// is skipped and the sync carries on.
    func discoverM3UCatchup(playlistId: UUID) async {
        let candidates = m3uCatchupCandidates(playlistId: playlistId)
        // Counts only, here and below: the accounts are credentials.
        let channelCount = candidates.values.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } }
        Logger.database.info(
            "m3u catch-up discovery: \(channelCount) channels without catch-up on \(candidates.count) Xtream panels"
        )
        guard !candidates.isEmpty else { return }

        var archives: [XtreamStreamAddress.Account: [Int: Int]] = [:]
        for account in candidates.keys {
            guard !Task.isCancelled else { return }
            do {
                // The manager's client: its session is the one an Xtream sync
                // uses, capped at one connection per provider.
                let streams = try await xtreamClient.getLiveStreams(
                    serverURL: account.serverURL, username: account.username, password: account.password
                )
                let archived = Self.archivedStreams(in: streams)
                archives[account] = archived
                Logger.database.info(
                    "m3u catch-up discovery: panel listed \(streams.count) live streams, \(archived.count) with an archive"
                )
            } catch {
                Logger.database.info("m3u catch-up discovery: panel did not answer (\(Self.redactedReason(error)))")
            }
        }

        let enabled = applyDiscoveredCatchup(archives, candidates: candidates)
        Logger.database.info("m3u catch-up discovery: enabled catch-up on \(enabled) channels")
    }

    /// Why a panel request failed, without the request URL — every error the
    /// client throws can carry it, and it holds the account.
    nonisolated static func redactedReason(_ error: Error) -> String {
        switch error {
        case let xtream as XtreamError:
            switch xtream {
            case .invalidURL: "invalid URL"
            case .authenticationFailed: "auth failed"
            case let .networkError(inner): "network \((inner as? URLError)?.code.rawValue ?? 0)"
            case .decodingError: "not JSON"
            case .invalidResponse: "invalid response"
            case let .serverError(status): "HTTP \(status)"
            }
        case let url as URLError:
            "network \(url.code.rawValue)"
        case is CancellationError:
            "cancelled"
        default:
            "error"
        }
    }

    /// The provider stream ids a panel archives, with their depth in days
    /// (0 when the panel doesn't say).
    nonisolated static func archivedStreams(in streams: [XtreamLiveStream]) -> [Int: Int] {
        var archived: [Int: Int] = [:]
        for stream in streams {
            guard let id = stream.streamId, (stream.tvArchive ?? 0) > 0 else { continue }
            archived[id] = max(stream.tvArchiveDuration ?? 0, 0)
        }
        return archived
    }

    // MARK: - Store

    /// The playlist's channels with no catch-up of their own whose stream URL is
    /// an Xtream `…/live/{user}/{pass}/{id}` address, grouped by panel account
    /// and then by provider stream id — several rows may share one stream.
    private func m3uCatchupCandidates(
        playlistId: UUID
    ) -> [XtreamStreamAddress.Account: [Int: [String]]] {
        let context = ModelContext(modelContainer)
        let prefix = playlistId.uuidString
        let descriptor = FetchDescriptor<LiveStream>(predicate: #Predicate {
            $0.id.starts(with: prefix) && $0.tvArchive == 0 && $0.catchupTypeRaw == nil && $0.directURL != nil
        })
        let rows = (try? context.fetch(descriptor)) ?? []

        var candidates: [XtreamStreamAddress.Account: [Int: [String]]] = [:]
        var skipped = 0
        for row in rows {
            guard let address = Self.discoverableAddress(row.directURL) else {
                skipped += 1
                continue
            }
            candidates[address.account, default: [:]][address.streamId, default: []].append(row.id)
        }
        if skipped > 0 {
            Logger.database.info("m3u catch-up discovery: \(skipped) channels without catch-up have no Xtream-shaped URL")
        }
        return candidates
    }

    /// Gives every candidate its panel archives the `xc` dialect, re-reading each
    /// row first so a concurrent change (another sync, a user edit) wins.
    /// Returns how many channels gained catch-up.
    private func applyDiscoveredCatchup(
        _ archives: [XtreamStreamAddress.Account: [Int: Int]],
        candidates: [XtreamStreamAddress.Account: [Int: [String]]]
    ) -> Int {
        var updates: [String: Int] = [:]
        for (account, archived) in archives {
            for (streamId, ids) in candidates[account] ?? [:] {
                guard let days = archived[streamId] else { continue }
                for id in ids {
                    updates[id] = days
                }
            }
        }
        guard !updates.isEmpty else { return 0 }

        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        let ids = Array(updates.keys)
        let rows = (try? context.fetch(FetchDescriptor<LiveStream>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        var enabled = 0
        for row in rows {
            guard let days = updates[row.id],
                  row.tvArchive == 0, row.catchupTypeRaw == nil,
                  Self.discoverableAddress(row.directURL) != nil
            else { continue }
            row.tvArchive = 1
            row.tvArchiveDuration = days
            row.catchupTypeRaw = CatchupType.xc.rawValue
            row.catchupSource = nil
            enabled += 1
        }
        if context.hasChanges { try? context.save() }
        return enabled
    }

    /// An m3u channel URL worth asking a panel about: Xtream-shaped with the
    /// `live` segment. The `live`-less form is too generic to call an API on.
    nonisolated static func discoverableAddress(_ url: String?) -> XtreamStreamAddress? {
        guard let url, let liveURL = URL(string: url),
              let address = XtreamStreamAddress(liveURL: liveURL), address.hasLiveSegment
        else { return nil }
        return address
    }
}
