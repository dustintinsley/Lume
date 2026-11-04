import Foundation
import StreamenCloudKit

/// A mirror model whose conflicting edits the Streamen Cloud transport resolves with
/// the collection's `CloudSyncMerge` value policy — the same policy the iCloud
/// engine applies, so a conflict resolves alike on either backend.
nonisolated protocol StreamenCloudConflictMerging: StreamenCloudPayloadMappable {
    /// Resolves a conflict in place: `self` holds the local value, `remote` the
    /// server's. Both are uninserted scratch copies.
    func mergeStreamenCloudConflict(with remote: Self) throws
}

private nonisolated extension StreamenCloudConflictMerging {
    /// For whole-record policies, whose merge always picks one side: takes every
    /// field of `remote` when it won, and keeps `self` otherwise.
    func adopt<Values: Equatable>(_ merged: Values, ifRemote remoteValues: Values, from remote: Self) throws {
        guard merged == remoteValues else { return }
        try applyStreamenCloudFields(StreamenCloudPayloadCodec.Fields(remote.streamenCloudFields))
    }
}

nonisolated extension StreamenCloudPayloadCodec {
    /// The conflict-merging model a record `type` maps to; nil for a type this
    /// build doesn't know.
    static func mergingModelType(forRecordType type: String) -> (any StreamenCloudConflictMerging.Type)? {
        modelType(forRecordType: type) as? any StreamenCloudConflictMerging.Type
    }
}

nonisolated extension SyncedPlaylist: StreamenCloudConflictMerging {
    func mergeStreamenCloudConflict(with remote: SyncedPlaylist) throws {
        let remoteValues = CloudSyncEngine.values(from: remote)
        let merged = PlaylistConfigValues.mergeConflict(local: CloudSyncEngine.values(from: self), cloud: remoteValues)
        try adopt(merged, ifRemote: remoteValues, from: remote)
    }
}

nonisolated extension UserContentState: StreamenCloudConflictMerging {
    func mergeStreamenCloudConflict(with remote: UserContentState) throws {
        let merged = ContentStateValues.mergeConflict(
            local: CloudSyncEngine.values(from: self),
            cloud: CloudSyncEngine.values(from: remote)
        )
        watchProgress = merged.watchProgress
        isWatched = merged.isWatched
        lastWatchedDate = merged.lastWatchedDate
        isFavorite = merged.isFavorite
        addedToWatchlistDate = merged.addedToWatchlistDate
        favoriteOrder = merged.favoriteOrder
        recommendationVoteRaw = merged.recommendationVoteRaw
        isHidden = merged.isHidden
        customOrder = merged.customOrder
        updatedAt = max(updatedAt, remote.updatedAt)
    }
}

nonisolated extension UserProfile: StreamenCloudConflictMerging {
    func mergeStreamenCloudConflict(with remote: UserProfile) throws {
        let merged = ProfileValues.mergeConflict(
            local: CloudSyncEngine.values(from: self),
            cloud: CloudSyncEngine.values(from: remote)
        )
        name = merged.name
        symbolName = merged.symbolName
        colorRaw = merged.colorRaw
        createdAt = merged.createdAt
        sortOrder = merged.sortOrder
        isChild = merged.isChild
        updatedAt = merged.updatedAt
    }
}

nonisolated extension SyncedEPGSource: StreamenCloudConflictMerging {
    func mergeStreamenCloudConflict(with remote: SyncedEPGSource) throws {
        let remoteValues = CloudSyncEngine.values(from: remote)
        let merged = EPGSourceValues.mergeConflict(local: CloudSyncEngine.values(from: self), cloud: remoteValues)
        try adopt(merged, ifRemote: remoteValues, from: remote)
    }
}

nonisolated extension SyncedParentalPIN: StreamenCloudConflictMerging {
    func mergeStreamenCloudConflict(with remote: SyncedParentalPIN) throws {
        let remoteValues = ParentalPINValues(hash: remote.pinHash)
        let merged = ParentalPINValues.mergeConflict(local: ParentalPINValues(hash: pinHash), cloud: remoteValues)
        try adopt(merged, ifRemote: remoteValues, from: remote)
    }
}

nonisolated extension SyncedCategoryRestriction: StreamenCloudConflictMerging {
    func mergeStreamenCloudConflict(with remote: SyncedCategoryRestriction) throws {
        let remoteValues = CategoryRestrictionValues(isRestricted: remote.isRestricted)
        let merged = CategoryRestrictionValues.mergeConflict(
            local: CategoryRestrictionValues(isRestricted: isRestricted),
            cloud: remoteValues
        )
        try adopt(merged, ifRemote: remoteValues, from: remote)
    }
}

nonisolated extension SyncedSportsFollow: StreamenCloudConflictMerging {
    func mergeStreamenCloudConflict(with remote: SyncedSportsFollow) throws {
        let remoteValues = CloudSyncEngine.values(from: remote)
        let merged = SportsFollowValues.mergeConflict(local: CloudSyncEngine.values(from: self), cloud: remoteValues)
        try adopt(merged, ifRemote: remoteValues, from: remote)
    }
}

nonisolated extension SyncedRecordingServer: StreamenCloudConflictMerging {
    func mergeStreamenCloudConflict(with remote: SyncedRecordingServer) throws {
        let remoteValues = CloudSyncEngine.values(from: remote)
        let merged = RecordingServerValues.mergeConflict(local: CloudSyncEngine.values(from: self), cloud: remoteValues)
        try adopt(merged, ifRemote: remoteValues, from: remote)
    }
}

nonisolated extension SyncedLiveTVPreferences: StreamenCloudConflictMerging {
    func mergeStreamenCloudConflict(with remote: SyncedLiveTVPreferences) throws {
        let remoteValues = LiveTVPreferenceValues(
            showsFavorites: remote.showsFavorites,
            showsRecentlyWatched: remote.showsRecentlyWatched
        )
        let merged = LiveTVPreferenceValues.mergeConflict(
            local: LiveTVPreferenceValues(showsFavorites: showsFavorites, showsRecentlyWatched: showsRecentlyWatched),
            cloud: remoteValues
        )
        try adopt(merged, ifRemote: remoteValues, from: remote)
    }
}
