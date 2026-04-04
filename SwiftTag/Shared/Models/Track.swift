import Foundation

struct Track: Identifiable {
    let id: UUID
    var album: String
    var albumArtist: String
    var totalTracks: String
    var tags: [String: String]
    private var storedFlacPicturesByType: [Int: Data]
    var flacPictureRecords: [FlacWritablePictureRecord]
    var sourceFileURL: URL?
    var securityScopedBookmarkData: Data?
    var latestFileSnapshot: TrackFileSnapshot?
    var externalDifferences: TrackExternalDifferences?
    var fingerprint: String?
    var isLocked: Bool
    var preservesEditorStateDuringFileRefresh: Bool

    var isImportedFlacTrack: Bool {
        sourceFileURL?.pathExtension.lowercased() == "flac"
    }

    var isDeletedInTable: Bool {
        externalDifferences?.isDeleted ?? false
    }

    var importedTrackReference: ImportedTrackReference? {
        guard let sourceFileURL else {
            return nil
        }

        return ImportedTrackReference(
            filePath: sourceFileURL.path,
            securityScopedBookmarkData: securityScopedBookmarkData
        )
    }

    var flacPicturesByType: [Int: Data] {
        get {
            if !flacPictureRecords.isEmpty {
                var byType: [Int: Data] = [:]
                for record in flacPictureRecords where byType[record.type] == nil {
                    byType[record.type] = record.data
                }
                return byType
            }
            return storedFlacPicturesByType
        }
        set {
            storedFlacPicturesByType = newValue
            if flacPictureRecords.isEmpty {
                flacPictureRecords = newValue
                    .sorted { $0.key < $1.key }
                    .map { type, data in
                        FlacWritablePictureRecord(
                            type: type,
                            mimeType: "image/png",
                            description: "",
                            data: data
                        )
                    }
            }
        }
    }

    var fingerprintDisplayValue: String {
        return fingerprint ?? "NA"
    }

    init(
        id: UUID = UUID(),
        album: String? = nil,
        albumArtist: String? = nil,
        totalTracks: String? = nil,
        tags: [String: String],
        flacPicturesByType: [Int: Data] = [:],
        flacPictureRecords: [FlacWritablePictureRecord] = [],
        sourceFileURL: URL? = nil,
        securityScopedBookmarkData: Data? = nil,
        latestFileSnapshot: TrackFileSnapshot? = nil,
        externalDifferences: TrackExternalDifferences? = nil,
        fingerprint: String? = nil,
        isLocked: Bool = false,
        preservesEditorStateDuringFileRefresh: Bool = false
    ) {
        self.id = id
        self.album = Track.normalizedSharedValue(album ?? tags[TagKey.album] ?? "")
        self.albumArtist = Track.normalizedSharedValue(albumArtist ?? tags[TagKey.albumArtist] ?? tags["ALBUM ARTIST"] ?? "")
        self.totalTracks = Track.normalizedNumericValue(totalTracks ?? tags["TOTALTRACKS"] ?? tags["TRACKTOTAL"] ?? "")
        self.tags = tags
        self.storedFlacPicturesByType = flacPicturesByType
        self.flacPictureRecords = flacPictureRecords.isEmpty
            ? flacPicturesByType
                .sorted { $0.key < $1.key }
                .map { type, data in
                    FlacWritablePictureRecord(
                        type: type,
                        mimeType: "image/png",
                        description: "",
                        data: data
                    )
                }
            : flacPictureRecords
        self.sourceFileURL = sourceFileURL
        self.securityScopedBookmarkData = securityScopedBookmarkData
        self.latestFileSnapshot = latestFileSnapshot
        self.externalDifferences = externalDifferences
        self.fingerprint = Track.normalizedOptionalValue(fingerprint)
        self.isLocked = isLocked
        self.preservesEditorStateDuringFileRefresh = preservesEditorStateDuringFileRefresh
    }

    private static func normalizedSharedValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedNumericValue(_ value: String) -> String {
        let trimmedValue = normalizedSharedValue(value)
        return Int(trimmedValue).map(String.init) ?? trimmedValue
    }

    private static func normalizedOptionalValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = normalizedSharedValue(value)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
