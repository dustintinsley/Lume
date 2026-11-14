//
//  ContentIndexer+Lookup.swift
//  Streamen
//
//  The index pass's network phase: TMDB lookups for a chunk of pending titles,
//  several in flight at once, working only on value snapshots so no SwiftData
//  object is touched across a suspension point. Split from ContentIndexer.swift
//  to keep that file within SwiftLint's length limit.
//

import Foundation

extension ContentIndexer {
    /// Resolves `pending` with up to `concurrentLookups` lookups in flight.
    /// On a transient failure or cancellation no further lookups start, but
    /// those already in flight finish and everything resolved is returned, so
    /// the caller still writes it and progress isn't lost.
    func resolveConcurrently(_ pending: [PendingItem]) async -> ([IndexResult], Error?) {
        var resolved: [IndexResult] = []
        var failure: Error?
        var next = 0
        await withTaskGroup(of: Result<IndexResult, Error>.self) { group in
            func startNext() {
                guard failure == nil, next < pending.count, !Task.isCancelled else { return }
                let item = pending[next]
                next += 1
                group.addTask { await self.resolvePaced(item) }
            }
            for _ in 0 ..< concurrentLookups {
                startNext()
            }
            for await outcome in group {
                switch outcome {
                case let .success(result): resolved.append(result)
                case let .failure(error): failure = failure ?? error
                }
                startNext()
            }
        }
        if failure == nil, Task.isCancelled {
            failure = CancellationError()
        }
        return (resolved, failure)
    }

    /// One lookup, then this lane's `itemPause` when it touched TMDB.
    func resolvePaced(_ item: PendingItem) async -> Result<IndexResult, Error> {
        do {
            try Task.checkCancellation()
            let result = try await resolve(item)
            if result.usedNetwork {
                try await Task.sleep(for: itemPause)
            }
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    /// Resolves an item's TMDB id (searching when absent) and detail payload
    /// (when not yet enriched) over the network, working only on values.
    func resolve(_ item: PendingItem) async throws -> IndexResult {
        guard tmdbClient.isConfigured else {
            return IndexResult(
                item: item, resolvedTMDBId: item.existingTMDBId, details: nil, usedNetwork: false
            )
        }

        // A row that adopted its title's `tmdb:` group is indexed as it is:
        // its siblings carry the id and the details, and adoption never writes
        // a tmdbId of its own.
        if item.existingTMDBId == nil, TitleGroupKey.tmdbId(groupKey: item.groupKey) != nil {
            return IndexResult(item: item, resolvedTMDBId: nil, details: nil, usedNetwork: false)
        }

        var usedNetwork = false
        var tmdbId = item.existingTMDBId
        if tmdbId == nil {
            (tmdbId, usedNetwork) = try await searchID(for: item)
        }

        var details: TMDBTitleDetails?
        if item.needsEnrichment, let tmdbId {
            let fetched = try await fetchDetails(kind: item.kind, tmdbId: tmdbId)
            details = fetched.details
            usedNetwork = usedNetwork || fetched.usedNetwork
        }

        return IndexResult(
            item: item, resolvedTMDBId: tmdbId, details: details, usedNetwork: usedNetwork
        )
    }

    /// The item's TMDB id from this pass's memo, else from a search.
    func searchID(for item: PendingItem) async throws -> (id: Int?, usedNetwork: Bool) {
        let key = SearchKey(kind: item.kind, title: item.title, year: item.year)
        if let memo = searchMemo[key] {
            return (memo, false)
        }
        let id = try await skippingPermanentFailures {
            switch item.kind {
            case .movie: try await self.searchMovieID(query: item.title, year: item.year)
            case .series: try await self.searchTVID(query: item.title, year: item.year)
            }
        }
        if searchMemo.count >= searchMemoLimit { searchMemo.removeAll() }
        searchMemo[key] = id
        return (id, true)
    }

    /// The title's TMDB details from this pass's memo, else from TMDB.
    func fetchDetails(kind: ItemKind, tmdbId: Int) async throws -> (details: TMDBTitleDetails?, usedNetwork: Bool) {
        let key = DetailsKey(kind: kind, tmdbId: tmdbId)
        if let memo = detailsMemo[key] {
            return (memo, false)
        }
        let details = try await skippingPermanentFailures {
            switch kind {
            case .movie: try await self.tmdbClient.movieDetails(tmdbId)
            case .series: try await self.tmdbClient.tvDetails(tmdbId)
            }
        }
        if detailsMemo.count >= detailsMemoLimit { detailsMemo.removeAll() }
        detailsMemo[key] = details
        return (details, true)
    }

    // MARK: - TMDB search with year fallback

    /// Provider year tags are often wrong, so a year-constrained search that
    /// finds nothing is retried without the year.
    func searchMovieID(query: String, year: Int?) async throws -> Int? {
        if let id = try await tmdbClient.searchMovieID(query: query, year: year) {
            return id
        }
        guard year != nil else { return nil }
        return try await tmdbClient.searchMovieID(query: query, year: nil)
    }

    func searchTVID(query: String, year: Int?) async throws -> Int? {
        if let id = try await tmdbClient.searchTVID(query: query, year: year) {
            return id
        }
        guard year != nil else { return nil }
        return try await tmdbClient.searchTVID(query: query, year: nil)
    }

    /// Runs a TMDB request, converting *permanent* failures (no match, bad
    /// payload) into nil so the item proceeds without TMDB data. Transient
    /// failures (offline, 5xx, rate limit) rethrow and end the run — the next
    /// kick retries those items.
    func skippingPermanentFailures<T>(_ request: () async throws -> T?) async throws -> T? {
        do {
            return try await request()
        } catch let error as TMDBError {
            switch error {
            case let .serverError(code) where code == 404:
                return nil
            case .decodingError, .invalidURL, .missingToken:
                return nil
            case .serverError, .invalidResponse:
                throw error
            }
        }
    }
}
