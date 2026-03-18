import Foundation

struct Track: Identifiable {
    let id: UUID
    var album: String
    var albumArtist: String
    var totalTracks: String
    var tags: [String: String]
    var flacPicturesByType: [Int: Data]
    var sourceFileURL: URL?
    var securityScopedBookmarkData: Data?
    var latestFileSnapshot: TrackFileSnapshot?
    var externalDifferences: TrackExternalDifferences?
    var isLocked: Bool

    var isImportedFlacTrack: Bool {
        sourceFileURL?.pathExtension.lowercased() == "flac"
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

    init(
        id: UUID = UUID(),
        album: String? = nil,
        albumArtist: String? = nil,
        totalTracks: String? = nil,
        tags: [String: String],
        flacPicturesByType: [Int: Data] = [:],
        sourceFileURL: URL? = nil,
        securityScopedBookmarkData: Data? = nil,
        latestFileSnapshot: TrackFileSnapshot? = nil,
        externalDifferences: TrackExternalDifferences? = nil,
        isLocked: Bool = false
    ) {
        self.id = id
        self.album = Track.normalizedSharedValue(album ?? tags[TagKey.album] ?? "")
        self.albumArtist = Track.normalizedSharedValue(albumArtist ?? tags[TagKey.albumArtist] ?? tags["ALBUM ARTIST"] ?? "")
        self.totalTracks = Track.normalizedNumericValue(totalTracks ?? tags["TOTALTRACKS"] ?? tags["TRACKTOTAL"] ?? "")
        self.tags = tags
        self.flacPicturesByType = flacPicturesByType
        self.sourceFileURL = sourceFileURL
        self.securityScopedBookmarkData = securityScopedBookmarkData
        self.latestFileSnapshot = latestFileSnapshot
        self.externalDifferences = externalDifferences
        self.isLocked = isLocked
    }

    private static func normalizedSharedValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedNumericValue(_ value: String) -> String {
        let trimmedValue = normalizedSharedValue(value)
        return Int(trimmedValue).map(String.init) ?? trimmedValue
    }
}
