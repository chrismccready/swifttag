import Foundation

struct TrackFileSnapshot: Equatable {
    var tags: [String: String]
    var picturesByType: [Int: Data]
}

struct TrackExternalDifferences: Equatable {
    var isDeleted: Bool
    var fileValuesByTag: [String: String]
    var hasPictureDifference: Bool

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
