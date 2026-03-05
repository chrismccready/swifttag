import Foundation

struct Track: Identifiable {
    let id: UUID
    var tags: [String: String]
    var flacPicturesByType: [Int: Data]

    init(id: UUID = UUID(), tags: [String: String], flacPicturesByType: [Int: Data] = [:]) {
        self.id = id
        self.tags = tags
        self.flacPicturesByType = flacPicturesByType
    }
}
