//
//  TMDBTitleMatch.swift
//  Streamen
//
//  Finds the TMDB id of a title its provider didn't identify, when its detail
//  page opens. m3u playlists never carry one, so until now a title only got
//  details (plot, cast, trailers) once the background indexer reached it — and
//  on an iPhone, which suspends the app long before a large catalog is done,
//  most titles never did. The search is the indexer's own: the cleaned title,
//  with the provider's year first and then without it.
//

import Foundation
import SwiftData

enum TMDBTitleMatch {
    /// The movie's TMDB id, searching for it (and storing it) when absent.
    static func movieID(for movie: Movie, context: ModelContext) async -> Int? {
        if let id = movie.tmdbId { return id }
        let client = TMDBClient.shared
        guard client.isConfigured else { return nil }
        let query = ContentIndexText.searchQuery(for: movie.name)
        let year = ContentIndexText.year(fromReleaseDate: movie.releaseDate) ?? query.year
        guard let id = await search(year: year, { try await client.searchMovieID(query: query.title, year: $0) })
        else { return nil }
        movie.tmdbId = id
        try? context.save()
        return id
    }

    /// The series' TMDB id, searching for it (and storing it) when absent.
    static func seriesID(for series: Series, context: ModelContext) async -> Int? {
        if let id = series.tmdbId { return id }
        let client = TMDBClient.shared
        guard client.isConfigured else { return nil }
        let query = ContentIndexText.searchQuery(for: series.name)
        let year = ContentIndexText.year(fromReleaseDate: series.releaseDate) ?? query.year
        guard let id = await search(year: year, { try await client.searchTVID(query: query.title, year: $0) })
        else { return nil }
        series.tmdbId = id
        try? context.save()
        return id
    }

    /// Provider years are often wrong, so a miss with the year retries without.
    private static func search(year: Int?, _ request: (Int?) async throws -> Int?) async -> Int? {
        if let id = try? await request(year) { return id }
        guard year != nil else { return nil }
        return try? await request(nil)
    }

    /// How long full details stay fresh before a detail page refetches them.
    private static let freshFor: TimeInterval = 14 * 24 * 3600
    /// How long *thin* details (no cast, plot or backdrop) stay fresh. A new
    /// release often has little on TMDB when first fetched; refetching the
    /// next day rather than in two weeks is what fills it in.
    private static let thinFreshFor: TimeInterval = 12 * 3600

    /// Whether a title's TMDB details should be fetched (again) now.
    static func isStale(enrichedAt: Date?, isThin: Bool) -> Bool {
        guard let enrichedAt else { return true }
        let age = Date().timeIntervalSince(enrichedAt)
        return age >= (isThin ? thinFreshFor : freshFor)
    }

    /// Whether a detail page will look the title up when it opens: TMDB is
    /// set up, and the title has no id yet or its details are stale.
    static func willLookUp(tmdbId: Int?, enrichedAt: Date?, isThin: Bool) -> Bool {
        guard TMDBClient.shared.isConfigured else { return false }
        if tmdbId == nil { return enrichedAt == nil }
        return isStale(enrichedAt: enrichedAt, isThin: isThin)
    }
}

extension Movie {
    /// Enriched, but missing what a detail page shows most: cast, plot or a
    /// backdrop (see `TMDBTitleMatch.isStale`).
    var hasThinDetails: Bool {
        castMembers.isEmpty || (plot ?? "").isEmpty || backdropPath == nil
    }
}

extension Series {
    /// See `Movie.hasThinDetails`.
    var hasThinDetails: Bool {
        castMembers.isEmpty || (plot ?? "").isEmpty || backdropPath == nil
    }
}
