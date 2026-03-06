import Foundation

struct Track: Identifiable {
    let id: UUID
    var tags: [String: String]
    var flacPicturesByType: [Int: Data]
    var sourceFileURL: URL?
    var securityScopedBookmarkData: Data?

    var isImportedFlacTrack: Bool {
        sourceFileURL?.pathExtension.lowercased() == "flac"
    }

    init(
        id: UUID = UUID(),
        tags: [String: String],
        flacPicturesByType: [Int: Data] = [:],
        sourceFileURL: URL? = nil,
        securityScopedBookmarkData: Data? = nil
    ) {
        self.id = id
        self.tags = tags
        self.flacPicturesByType = flacPicturesByType
        self.sourceFileURL = sourceFileURL
        self.securityScopedBookmarkData = securityScopedBookmarkData
    }
}
