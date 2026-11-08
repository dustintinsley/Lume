//
//  ContentSyncManager+M3UPrune.swift
//  Streamen
//
//  The m3u import's post-import mark-and-sweep. Split from
//  ContentSyncManager+M3U.swift, which sits against SwiftLint's file-length
//  limit. The sweeps themselves live in ContentSyncManager+Prune.swift; this is
//  only the order they run in, the gate they are handed, and the point each
//  seen-set is released.
//

import Foundation
import SwiftData

extension ContentSyncManager {
    /// The post-import sweeps, one signpost each: at provider scale they are a
    /// multi-minute phase of their own and a single import number hides that.
    ///
    /// Every sweep goes through the guarded entry points, never `pruneStale*`
    /// directly. A total of zero means the download or parse produced nothing
    /// and nothing is swept at all; past that, the coverage gate is what stops a
    /// download cut mid-file — which parses into a perfectly valid short
    /// playlist — from deleting the rows its missing tail would have named.
    ///
    /// Each set is dropped as soon as its own sweep returns: they are only ever
    /// read once, and holding all five to the end of the last sweep is the peak
    /// this import is measured at.
    func pruneStaleM3URows(playlistId: UUID, state: M3UImportState) {
        let imported = state.totalImported
        Perf.measure(.m3uPruneLive) {
            pruneLiveStreams(playlistId: playlistId, seenHashes: state.seenLiveIds, importedCount: imported)
        }
        state.seenLiveIds = []
        Perf.measure(.m3uPruneMovies) {
            pruneMovies(playlistId: playlistId, seenHashes: state.seenMovieIds, importedCount: imported)
        }
        state.seenMovieIds = []
        Perf.measure(.m3uPruneEpisodes) {
            pruneEpisodes(playlistId: playlistId, seenHashes: state.seenEpisodeIds, importedCount: imported)
        }
        state.seenEpisodeIds = []
        Perf.measure(.m3uPruneSeries) {
            pruneSeries(playlistId: playlistId, seenHashes: state.seenSeriesIds, importedCount: imported)
        }
        state.seenSeriesIds = []
        Perf.measure(.m3uPruneCategories) {
            for type in CategoryType.allCases {
                let typePrefix = "\(type.rawValue)|"
                let seenApiIds = Set(
                    state.seenCategoryKeys
                        .filter { $0.hasPrefix(typePrefix) }
                        .map { String($0.dropFirst(typePrefix.count)) }
                )
                pruneCategories(
                    playlistId: playlistId, type: type, seenApiIds: seenApiIds, importedCount: imported
                )
            }
        }
        state.seenCategoryKeys = []
        Perf.measure(.m3uPruneCategories) {
            renumberM3UCategories(playlistId: playlistId, fileOrder: state.categoryFileOrder)
        }
        state.categoryFileOrder = [:]
    }

    /// Re-stamps every category's `sortOrder` with its group's position in
    /// this sync's file, so "Playlist order" follows the provider's current
    /// file the way Xtream's per-sync re-index does. Only changed values are
    /// written, so an unchanged file leaves the context clean and saves nothing.
    func renumberM3UCategories(playlistId: UUID, fileOrder: [String: [String]]) {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        for type in CategoryType.allCases {
            guard let names = fileOrder[type.rawValue], !names.isEmpty else { continue }
            let positions = Dictionary(names.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            let prefix = "\(playlistId.uuidString)-\(type.rawValue)-"
            let typeRaw = type.rawValue
            let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.typeRaw == typeRaw })
            for category in (try? context.fetch(descriptor)) ?? [] where category.id.hasPrefix(prefix) {
                guard let position = positions[category.apiId], category.sortOrder != position else { continue }
                category.sortOrder = position
            }
        }
        if context.hasChanges { try? context.save() }
    }
}
