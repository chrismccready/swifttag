import Foundation

enum TrackTableSortMode: Equatable {
    case number
    case filename

    var nextSortMenuTitle: String {
        switch self {
        case .number:
            "Sort Tracks by Filename"
        case .filename:
            "Sort Tracks by Number"
        }
    }

    var toggled: TrackTableSortMode {
        switch self {
        case .number:
            .filename
        case .filename:
            .number
        }
    }
}

struct Track: Identifiable {
    let id: UUID
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

    var album: String {
        get {
            Track.normalizedSharedValue(tagValue(for: [TagKey.album]) ?? "")
        }
        set {
            setTagValue(newValue, for: TagKey.album)
        }
    }

    var albumArtist: String {
        get {
            Track.normalizedSharedValue(tagValue(for: [TagKey.albumArtist]) ?? "")
        }
        set {
            setTagValue(newValue, for: TagKey.albumArtist)
        }
    }

    var totalTracks: String {
        get {
            Track.normalizedNumericValue(tagValue(for: ["TOTALTRACKS", "TRACKTOTAL"]) ?? "")
        }
        set {
            setTotalTracksValue(newValue)
        }
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

        normalizeTagBackedValues(
            album: album,
            albumArtist: albumArtist,
            totalTracks: totalTracks
        )
    }

    mutating func setTagValue(_ value: String, for key: String) {
        let normalizedKey = TagNormalization.normalizeTagKey(key)
        guard !normalizedKey.isEmpty else {
            return
        }

        removeTagValues(for: [normalizedKey])
        tags[normalizedKey] = Track.normalizedSharedValue(value)
    }

    mutating func removeTagValues(for keys: [String]) {
        let normalizedKeys = Set(keys.map { TagNormalization.normalizeTagKey($0) }.filter { !$0.isEmpty })
        guard !normalizedKeys.isEmpty else {
            return
        }

        for key in Array(tags.keys) where normalizedKeys.contains(TagNormalization.normalizeTagKey(key)) {
            tags.removeValue(forKey: key)
        }
    }

    private mutating func normalizeTagBackedValues(
        album explicitAlbum: String?,
        albumArtist explicitAlbumArtist: String?,
        totalTracks explicitTotalTracks: String?
    ) {
        if let albumValue = explicitAlbum ?? tagValue(for: [TagKey.album]) {
            album = albumValue
        }

        if let albumArtistValue = explicitAlbumArtist ?? tagValue(for: [TagKey.albumArtist]) {
            albumArtist = albumArtistValue
        }

        if let totalTracksValue = explicitTotalTracks ?? tagValue(for: ["TOTALTRACKS", "TRACKTOTAL"]) {
            totalTracks = totalTracksValue
        }
    }

    private func tagValue(for keys: [String]) -> String? {
        for key in keys {
            let normalizedKey = TagNormalization.normalizeTagKey(key)
            guard !normalizedKey.isEmpty else {
                continue
            }

            if let value = tags[normalizedKey] {
                return value
            }

            if let match = tags.first(where: { TagNormalization.normalizeTagKey($0.key) == normalizedKey }) {
                return match.value
            }
        }

        return nil
    }

    private mutating func setTotalTracksValue(_ value: String) {
        removeTagValues(for: ["TOTALTRACKS", "TRACKTOTAL"])
        tags["TOTALTRACKS"] = Track.normalizedNumericValue(value)
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

extension Array where Element == Track {
    func sortedForTrackTableDisplay(sortMode: TrackTableSortMode = .number) -> [Track] {
        enumerated()
            .sorted { lhs, rhs in
                let comparison = Self.trackTableComparison(lhs.element, rhs.element, sortMode: sortMode)
                if let comparison {
                    return comparison
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func trackTableComparison(
        _ lhs: Track,
        _ rhs: Track,
        sortMode: TrackTableSortMode
    ) -> Bool? {
        switch sortMode {
        case .number:
            if let numberComparison = numericTrackNumberComparison(lhs, rhs) {
                return numberComparison
            }
            return filenameComparison(lhs, rhs)
        case .filename:
            if let filenameComparison = filenameComparison(lhs, rhs) {
                return filenameComparison
            }
            return numericTrackNumberComparison(lhs, rhs)
        }
    }

    private static func numericTrackNumberComparison(_ lhs: Track, _ rhs: Track) -> Bool? {
        let lhsNumber = Int(lhs.tags[TagKey.trackNumber] ?? "")
        let rhsNumber = Int(rhs.tags[TagKey.trackNumber] ?? "")
        switch (lhsNumber, rhsNumber) {
        case let (lhs?, rhs?):
            return lhs == rhs ? nil : lhs < rhs
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return nil
        }
    }

    private static func filenameComparison(_ lhs: Track, _ rhs: Track) -> Bool? {
        switch lhs.displayFileName.localizedStandardCompare(rhs.displayFileName) {
        case .orderedAscending:
            return true
        case .orderedDescending:
            return false
        case .orderedSame:
            return nil
        }
    }
}
