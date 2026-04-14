import Foundation

struct TrackFileSnapshot: Equatable {
    var tags: [String: String]
    var picturesByType: [Int: Data]
    var pictureRecords: [FlacWritablePictureRecord]
    var fingerprint: String?

    init(
        tags: [String: String],
        picturesByType: [Int: Data],
        pictureRecords: [FlacWritablePictureRecord] = [],
        fingerprint: String? = nil
    ) {
        self.tags = tags
        self.picturesByType = picturesByType
        self.pictureRecords = pictureRecords
        self.fingerprint = fingerprint
    }
}

struct TrackExternalDifferences: Equatable {
    var isDeleted: Bool
    var fileValuesByTag: [String: String]
    var hasPictureDifference: Bool
    var externallyModifiedPictureTypes: Set<Int> = []

    var hasExternallyModifiedPictureDifference: Bool {
        !externallyModifiedPictureTypes.isEmpty
    }

    var hasStatusPresentationDifferences: Bool {
        isDeleted || !fileValuesByTag.isEmpty || hasExternallyModifiedPictureDifference
    }

    var hasDifferences: Bool {
        isDeleted || !fileValuesByTag.isEmpty || hasPictureDifference
    }
}

struct TrackStatusPresentation: Equatable {
    let systemImageName: String
    let help: String?
}

struct TrackFileMonitorEvent {
    let trackID: UUID
    let currentPath: String?
}
