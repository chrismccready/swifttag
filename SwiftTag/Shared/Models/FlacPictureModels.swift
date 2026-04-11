import Foundation

struct FlacPictureRecord {
    let type: Int
    let mimeType: String
    let description: String
    let width: Int
    let height: Int
    let depth: Int
    let colors: Int
    let data: Data

    init(
        type: Int,
        mimeType: String,
        description: String,
        width: Int = 0,
        height: Int = 0,
        depth: Int = 0,
        colors: Int = 0,
        data: Data
    ) {
        self.type = type
        self.mimeType = mimeType
        self.description = description
        self.width = width
        self.height = height
        self.depth = depth
        self.colors = colors
        self.data = data
    }
}

struct FlacWritablePictureRecord: Equatable {
    let type: Int
    let mimeType: String
    let description: String
    let data: Data
    let width: Int
    let height: Int
    let depth: Int
    let colors: Int

    init(
        type: Int,
        mimeType: String,
        description: String,
        data: Data,
        width: Int = 0,
        height: Int = 0,
        depth: Int = 0,
        colors: Int = 0
    ) {
        self.type = type
        self.mimeType = mimeType
        self.description = description
        self.data = data
        self.width = width
        self.height = height
        self.depth = depth
        self.colors = colors
    }
}
