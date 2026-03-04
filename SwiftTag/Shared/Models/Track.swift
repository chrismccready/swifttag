import Foundation

struct Track: Identifiable {
    let id: UUID
    var tags: [String: String]

    init(id: UUID = UUID(), tags: [String: String]) {
        self.id = id
        self.tags = tags
    }
}
