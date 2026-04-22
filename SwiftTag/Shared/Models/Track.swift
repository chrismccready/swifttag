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
    var duration: TimeInterval?
    var sampleRate: UInt32?
    var totalSamples: UInt64?
    var bitsPerSample: UInt32?
    var channels: UInt32?
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
                    .map(Self.pictureRecord(type:data:))
            }
        }
    }

    var fingerprintDisplayValue: String {
        return fingerprint ?? "NA"
    }

    var sampleRateDisplayValue: String {
        TrackSampleRateFormatter.string(from: sampleRate) ?? ""
    }

    var displayFileName: String {
        if let sourceFileURL {
            return sourceFileURL.lastPathComponent
        }

        return tags[TagKey.filename]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
        duration: TimeInterval? = nil,
        sampleRate: UInt32? = nil,
        totalSamples: UInt64? = nil,
        bitsPerSample: UInt32? = nil,
        channels: UInt32? = nil,
        isLocked: Bool = false,
        preservesEditorStateDuringFileRefresh: Bool = false
    ) {
        self.id = id
        self.album = Track.normalizedSharedValue(album ?? tags[TagKey.album] ?? "")
        self.albumArtist = Track.normalizedSharedValue(albumArtist ?? tags[TagKey.albumArtist] ?? "")
        self.totalTracks = Track.normalizedNumericValue(totalTracks ?? tags["TOTALTRACKS"] ?? tags["TRACKTOTAL"] ?? "")
        self.tags = tags
        self.storedFlacPicturesByType = flacPicturesByType
        self.flacPictureRecords = flacPictureRecords.isEmpty
            ? flacPicturesByType
                .sorted { $0.key < $1.key }
                .map(Self.pictureRecord(type:data:))
            : flacPictureRecords
        self.sourceFileURL = sourceFileURL
        self.securityScopedBookmarkData = securityScopedBookmarkData
        self.latestFileSnapshot = latestFileSnapshot
        self.externalDifferences = externalDifferences
        self.fingerprint = Track.normalizedOptionalValue(fingerprint)
        self.duration = Track.normalizedDuration(duration)
        self.sampleRate = Track.normalizedPositiveValue(sampleRate)
        self.totalSamples = Track.normalizedPositiveValue(totalSamples)
        self.bitsPerSample = Track.normalizedPositiveValue(bitsPerSample)
        self.channels = Track.normalizedPositiveValue(channels)
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

    private static func normalizedDuration(_ value: TimeInterval?) -> TimeInterval? {
        guard let value,
              value.isFinite,
              value >= 0 else {
            return nil
        }

        return value
    }

    private static func normalizedPositiveValue(_ value: UInt32?) -> UInt32? {
        guard let value, value > 0 else {
            return nil
        }

        return value
    }

    private static func normalizedPositiveValue(_ value: UInt64?) -> UInt64? {
        guard let value, value > 0 else {
            return nil
        }

        return value
    }

    nonisolated private static func pictureRecord(type: Int, data: Data) -> FlacWritablePictureRecord {
        let assetDetails = PictureDataUtilities.supportedAssetDetails(mimeType: "", data: data)
        let specifications = assetDetails?.specifications ?? .zero

        return FlacWritablePictureRecord(
            type: type,
            mimeType: assetDetails?.mimeType ?? "application/octet-stream",
            description: "",
            data: data,
            width: specifications.width,
            height: specifications.height,
            depth: specifications.depth,
            colors: specifications.colors
        )
    }
}
