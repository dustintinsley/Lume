import Foundation
import StreamenCloudKit
import SwiftData

/// Recorded user deletions: the only source of the tombstones a push sends.
extension StreamenCloudTransport {
    /// Records that the user deleted the record under `logicalKey`: removes its
    /// mirror row and queues a tombstone for the next push. The only way a push
    /// deletes a server record. A key this build can't parse, or a record that
    /// never synced, queues nothing.
    func recordDeletion(logicalKey: String) async throws {
        try await recordDeletions(logicalKeys: [logicalKey])
    }

    /// `recordDeletion(logicalKey:)` for several records in one store write.
    func recordDeletions(logicalKeys: [String]) async throws {
        guard !logicalKeys.isEmpty else { return }
        try await serialized { transport in
            transport.liftQuotaHold()
            if try transport.performRecordDeletions(logicalKeys: logicalKeys) {
                await transport.postMirrorDidChange()
            }
        }
    }

    /// Queues a tombstone for each key in `logicalKeys` whose mirror row
    /// another writer deleted on purpose (`SyncMirrorDeletionLog`). Unlike
    /// `recordDeletions`, it deletes no row: a key whose row exists again — an
    /// un-favorite undone before the pass — queues nothing.
    func recordRemovals(logicalKeys: [String]) async throws {
        guard !logicalKeys.isEmpty else { return }
        try await serialized { transport in
            try transport.performRecordRemovals(logicalKeys: logicalKeys)
        }
    }

    /// The logical keys of every synced record, not already queued for
    /// deletion, whose key contains any of `fragments`. Callers still match
    /// the parsed key: a fragment only narrows the read.
    func syncedLogicalKeys(containing fragments: [String]) async throws -> [String] {
        try await serialized { transport in
            let context = transport.makeContext()
            var keys: Set<String> = []
            for fragment in fragments {
                var descriptor = FetchDescriptor<StreamenCloudRecordState>(
                    predicate: #Predicate {
                        !$0.isDeletionPending && $0.lastSyncedPayload != nil && $0.logicalKey.contains(fragment)
                    }
                )
                descriptor.propertiesToFetch = [\.logicalKey]
                try keys.formUnion(context.fetch(descriptor).map(\.logicalKey))
            }
            return Array(keys)
        }
    }

    private func performRecordDeletions(logicalKeys: [String]) throws -> Bool {
        var keysByModel: [ObjectIdentifier: (model: any StreamenCloudPayloadMappable.Type, keys: Set<String>)] = [:]
        for logicalKey in logicalKeys {
            guard let key = StreamenCloudLogicalKey(logicalKey) else { continue }
            let modelType = key.modelType
            keysByModel[ObjectIdentifier(modelType), default: (modelType, [])].keys.insert(logicalKey)
        }
        guard !keysByModel.isEmpty else { return false }
        let context = makeContext()
        var deletedRow = false
        for entry in keysByModel.values {
            deletedRow = try deleteRows(under: entry.keys, as: entry.model, in: context) || deletedRow
        }
        let rids = keysByModel.values.flatMap(\.keys).map { keys.recordID(for: $0) }
        let descriptor = FetchDescriptor<StreamenCloudRecordState>(predicate: #Predicate { rids.contains($0.rid) })
        for state in try context.fetch(descriptor) where state.lastSyncedPayload != nil {
            update(state, \.isDeletionPending, to: true)
            update(state, \.isDirty, to: true)
        }
        if context.hasChanges {
            try context.save()
        }
        return deletedRow
    }

    private func performRecordRemovals(logicalKeys: [String]) throws {
        let context = makeContext()
        var removed: [String] = []
        var keysByModel: [ObjectIdentifier: (model: any StreamenCloudPayloadMappable.Type, keys: Set<String>)] = [:]
        for logicalKey in logicalKeys {
            guard let key = StreamenCloudLogicalKey(logicalKey) else { continue }
            let modelType = key.modelType
            keysByModel[ObjectIdentifier(modelType), default: (modelType, [])].keys.insert(logicalKey)
        }
        for entry in keysByModel.values {
            let present = try presentKeys(entry.keys, as: entry.model, in: context)
            removed += entry.keys.subtracting(present)
        }
        guard !removed.isEmpty else { return }
        liftQuotaHold()
        let rids = removed.map { keys.recordID(for: $0) }
        let descriptor = FetchDescriptor<StreamenCloudRecordState>(predicate: #Predicate { rids.contains($0.rid) })
        for state in try context.fetch(descriptor) where state.lastSyncedPayload != nil && !state.isUndecodable {
            update(state, \.isDeletionPending, to: true)
            update(state, \.isDirty, to: true)
        }
        if context.hasChanges {
            try context.save()
        }
    }

    private func presentKeys<Model: StreamenCloudPayloadMappable>(
        _ keys: Set<String>,
        as _: Model.Type,
        in context: ModelContext
    ) throws -> Set<String> {
        try Set(mirrorRows(Model.self, withKeys: keys, in: context).map(\.streamenCloudKey)).intersection(keys)
    }

    private func deleteRows<Model: StreamenCloudPayloadMappable>(
        under keys: Set<String>,
        as _: Model.Type,
        in context: ModelContext
    ) throws -> Bool {
        let rows = try mirrorRows(Model.self, withKeys: keys, in: context).filter { keys.contains($0.streamenCloudKey) }
        for row in rows {
            context.delete(row)
        }
        return !rows.isEmpty
    }
}
