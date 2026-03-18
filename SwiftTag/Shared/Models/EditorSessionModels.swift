import Foundation

enum AppSceneID {
    static let editor = "editor"
    static let diffTools = "diff-tools"
}

struct ImportedTrackReference: Codable, Hashable, Identifiable {
    let id: UUID
    let filePath: String
    let securityScopedBookmarkData: Data?

    init(
        id: UUID = UUID(),
        filePath: String,
        securityScopedBookmarkData: Data?
    ) {
        self.id = id
        self.filePath = filePath
        self.securityScopedBookmarkData = securityScopedBookmarkData
    }
}

struct EditorSessionValue: Codable, Identifiable, Hashable {
    let sessionID: UUID
    var reopenRecordID: UUID?

    var id: UUID { sessionID }

    init(
        sessionID: UUID = UUID(),
        reopenRecordID: UUID? = nil
    ) {
        self.sessionID = sessionID
        self.reopenRecordID = reopenRecordID
    }

    static func == (lhs: EditorSessionValue, rhs: EditorSessionValue) -> Bool {
        lhs.sessionID == rhs.sessionID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sessionID)
    }
}

struct SaveReopenRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let sourceSessionID: UUID
    let payload: SavePayloadOption
    let fingerprint: String
    let trackReferences: [ImportedTrackReference]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceSessionID: UUID,
        payload: SavePayloadOption,
        fingerprint: String,
        trackReferences: [ImportedTrackReference],
        createdAt: Date = .now
    ) {
        self.id = id
        self.sourceSessionID = sourceSessionID
        self.payload = payload
        self.fingerprint = fingerprint
        self.trackReferences = trackReferences
        self.createdAt = createdAt
    }

    var trackCount: Int {
        trackReferences.count
    }
}

struct SaveNotificationPayload: Codable, Hashable {
    let reopenRecordID: UUID
    let sourceSessionID: UUID
    let payload: SavePayloadOption
    let fingerprint: String
    let trackCount: Int
}

struct SaveOperationResult: Hashable {
    let sourceSessionID: UUID
    let payload: SavePayloadOption
    let trackReferences: [ImportedTrackReference]
    let fingerprint: String

    var trackCount: Int {
        trackReferences.count
    }

    var reopenRecord: SaveReopenRecord {
        SaveReopenRecord(
            sourceSessionID: sourceSessionID,
            payload: payload,
            fingerprint: fingerprint,
            trackReferences: trackReferences
        )
    }
}

enum TrackSetFingerprint {
    static func normalizedPaths(from filePaths: [String]) -> [String] {
        filePaths
            .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
            .sorted()
    }

    static func normalizedPaths(from references: [ImportedTrackReference]) -> [String] {
        normalizedPaths(from: references.map(\.filePath))
    }

    static func make(fromNormalizedPaths normalizedPaths: [String]) -> String {
        normalizedPaths.joined(separator: "\n")
    }

    static func make(from filePaths: [String]) -> String {
        make(fromNormalizedPaths: normalizedPaths(from: filePaths))
    }

    static func make(from references: [ImportedTrackReference]) -> String {
        make(fromNormalizedPaths: normalizedPaths(from: references))
    }
}
