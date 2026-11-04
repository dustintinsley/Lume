import Foundation
import StreamenCloudKit
import SwiftData

// MARK: - parentalPin

nonisolated extension SyncedParentalPIN: StreamenCloudPayloadMappable {
    static var streamenCloudType: String {
        "parentalPin"
    }

    var streamenCloudKey: String {
        StreamenCloudPayloadCodec.parentalPINKey
    }

    var streamenCloudFields: [String: JSONValue] {
        [
            "pinHash": .string(pinHash),
            "updatedAt": StreamenCloudPayloadCodec.wire(updatedAt)
        ]
    }

    static func streamenCloudKey(for _: StreamenCloudPayloadCodec.Fields) throws -> String {
        StreamenCloudPayloadCodec.parentalPINKey
    }

    func applyStreamenCloudFields(_ fields: StreamenCloudPayloadCodec.Fields) throws {
        let pinHash = try fields.string("pinHash")
        let updatedAt = try fields.date("updatedAt")

        self.pinHash = pinHash
        self.updatedAt = updatedAt
    }

    static func makeBlankForStreamenCloud() -> SyncedParentalPIN {
        SyncedParentalPIN(pinHash: "")
    }
}

// MARK: - categoryRestriction

nonisolated extension SyncedCategoryRestriction: StreamenCloudPayloadMappable {
    static var streamenCloudType: String {
        "categoryRestriction"
    }

    var streamenCloudKey: String {
        StreamenCloudPayloadCodec.categoryRestrictionKey(categoryID: categoryID)
    }

    var streamenCloudFields: [String: JSONValue] {
        [
            "categoryID": .string(categoryID),
            "isRestricted": .bool(isRestricted),
            "updatedAt": StreamenCloudPayloadCodec.wire(updatedAt)
        ]
    }

    static func streamenCloudKey(for fields: StreamenCloudPayloadCodec.Fields) throws -> String {
        try StreamenCloudPayloadCodec.categoryRestrictionKey(categoryID: fields.string("categoryID"))
    }

    func applyStreamenCloudFields(_ fields: StreamenCloudPayloadCodec.Fields) throws {
        let categoryID = try fields.string("categoryID")
        let isRestricted = try fields.bool("isRestricted")
        let updatedAt = try fields.date("updatedAt")

        self.categoryID = categoryID
        self.isRestricted = isRestricted
        self.updatedAt = updatedAt
    }

    static func makeBlankForStreamenCloud() -> SyncedCategoryRestriction {
        SyncedCategoryRestriction(categoryID: "")
    }
}

// MARK: - sportsFollow

nonisolated extension SyncedSportsFollow: StreamenCloudPayloadMappable {
    static var streamenCloudType: String {
        "sportsFollow"
    }

    var streamenCloudKey: String {
        StreamenCloudPayloadCodec.sportsFollowKey(profileID: profileID, key: key)
    }

    var streamenCloudFields: [String: JSONValue] {
        typealias Codec = StreamenCloudPayloadCodec
        return [
            "key": .string(key),
            "kindRaw": .string(kindRaw),
            "profileID": Codec.wire(profileID),
            "sortOrder": Codec.wire(sortOrder),
            "updatedAt": Codec.wire(updatedAt)
        ]
    }

    static func streamenCloudKey(for fields: StreamenCloudPayloadCodec.Fields) throws -> String {
        try StreamenCloudPayloadCodec.sportsFollowKey(
            profileID: fields.optionalUUID("profileID"),
            key: fields.string("key")
        )
    }

    func applyStreamenCloudFields(_ fields: StreamenCloudPayloadCodec.Fields) throws {
        let key = try fields.string("key")
        let kindRaw = try fields.string("kindRaw")
        let profileID = try fields.optionalUUID("profileID")
        let sortOrder = try fields.int("sortOrder")
        let updatedAt = try fields.date("updatedAt")

        self.key = key
        self.kindRaw = kindRaw
        self.profileID = profileID
        self.sortOrder = sortOrder
        self.updatedAt = updatedAt
    }

    static func makeBlankForStreamenCloud() -> SyncedSportsFollow {
        SyncedSportsFollow(key: "", profileID: nil)
    }
}

// MARK: - recordingServer

nonisolated extension SyncedRecordingServer: StreamenCloudPayloadMappable {
    static var streamenCloudType: String {
        "recordingServer"
    }

    var streamenCloudKey: String {
        StreamenCloudPayloadCodec.recordingServerKey(id: id)
    }

    /// `token` is a pairing credential; it only ever leaves the device inside
    /// the sealed envelope.
    var streamenCloudFields: [String: JSONValue] {
        typealias Codec = StreamenCloudPayloadCodec
        return [
            "id": Codec.wire(id),
            "kindRaw": .string(kindRaw),
            "name": .string(name),
            "baseURL": .string(baseURL),
            "serverID": Codec.wire(serverID),
            "deviceID": Codec.wire(deviceID),
            "token": .string(token),
            "isEnabled": .bool(isEnabled),
            "updatedAt": Codec.wire(updatedAt)
        ]
    }

    static func streamenCloudKey(for fields: StreamenCloudPayloadCodec.Fields) throws -> String {
        try StreamenCloudPayloadCodec.recordingServerKey(id: fields.uuid("id"))
    }

    func applyStreamenCloudFields(_ fields: StreamenCloudPayloadCodec.Fields) throws {
        let id = try fields.uuid("id")
        let kindRaw = try fields.string("kindRaw")
        let name = try fields.string("name")
        let baseURL = try fields.string("baseURL")
        let serverID = try fields.optionalUUID("serverID")
        let deviceID = try fields.optionalUUID("deviceID")
        let token = try fields.string("token")
        let isEnabled = try fields.bool("isEnabled")
        let updatedAt = try fields.date("updatedAt")

        self.id = id
        // Raw, not through `kind`: an unknown backend must survive to be written back.
        self.kindRaw = kindRaw
        self.name = name
        self.baseURL = baseURL
        self.serverID = serverID
        self.deviceID = deviceID
        self.token = token
        self.isEnabled = isEnabled
        self.updatedAt = updatedAt
    }

    static func makeBlankForStreamenCloud() -> SyncedRecordingServer {
        SyncedRecordingServer(name: "", baseURL: "")
    }
}

// MARK: - liveTVPrefs

nonisolated extension SyncedLiveTVPreferences: StreamenCloudPayloadMappable {
    static var streamenCloudType: String {
        "liveTVPrefs"
    }

    var streamenCloudKey: String {
        StreamenCloudPayloadCodec.liveTVPreferencesKey
    }

    var streamenCloudFields: [String: JSONValue] {
        [
            "showsFavorites": .bool(showsFavorites),
            "showsRecentlyWatched": .bool(showsRecentlyWatched),
            "updatedAt": StreamenCloudPayloadCodec.wire(updatedAt)
        ]
    }

    static func streamenCloudKey(for _: StreamenCloudPayloadCodec.Fields) throws -> String {
        StreamenCloudPayloadCodec.liveTVPreferencesKey
    }

    func applyStreamenCloudFields(_ fields: StreamenCloudPayloadCodec.Fields) throws {
        let showsFavorites = try fields.bool("showsFavorites")
        let showsRecentlyWatched = try fields.bool("showsRecentlyWatched")
        let updatedAt = try fields.date("updatedAt")

        self.showsFavorites = showsFavorites
        self.showsRecentlyWatched = showsRecentlyWatched
        self.updatedAt = updatedAt
    }

    static func makeBlankForStreamenCloud() -> SyncedLiveTVPreferences {
        SyncedLiveTVPreferences(
            showsFavorites: LiveTVRailSettings.showsFavoritesDefault,
            showsRecentlyWatched: LiveTVRailSettings.showsRecentlyWatchedDefault
        )
    }
}
