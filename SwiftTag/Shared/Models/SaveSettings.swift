import Foundation

enum SavePayloadOption: String, CaseIterable, Identifiable, Codable {
    case writeTags
    case writePictures
    case writeTagsAndPictures

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .writeTags:
            return "Tags"
        case .writePictures:
            return "Pictures"
        case .writeTagsAndPictures:
            return "Tags & Pictures"
        }
    }

    var writesTags: Bool {
        switch self {
        case .writeTags, .writeTagsAndPictures:
            return true
        case .writePictures:
            return false
        }
    }

    var writesPictures: Bool {
        switch self {
        case .writePictures, .writeTagsAndPictures:
            return true
        case .writeTags:
            return false
        }
    }
}

enum SaveScopeOption: String, CaseIterable, Identifiable, Codable {
    case selectedTracks
    case allTracks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .selectedTracks:
            return "Selected Tracks"
        case .allTracks:
            return "All Tracks"
        }
    }
}

enum TrackCountKeyStrategy: String, CaseIterable, Identifiable, Codable {
    case totalTracks
    case trackTotal
    case both
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .totalTracks:
            return "TOTALTRACKS"
        case .trackTotal:
            return "TRACKTOTAL"
        case .both:
            return "TOTALTRACKS and TRACKTOTAL"
        case .none:
            return "don't write key"
        }
    }
}

enum DiscCountKeyStrategy: String, CaseIterable, Identifiable, Codable {
    case totalDiscs
    case discTotal
    case both
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .totalDiscs:
            return "TOTALDISCS"
        case .discTotal:
            return "DISCTOTAL"
        case .both:
            return "TOTALDISCS and DISCTOTAL"
        case .none:
            return "don't write key"
        }
    }
}

enum SaveSettingsKey {
    static let defaultSavePayload = "settings.defaultSavePayload"
    static let defaultSaveScope = "settings.defaultSaveScope"
    static let zeroPadTrackNumber = "settings.zeroPadTrackNumber"
    static let trackCountKeyStrategy = "settings.trackCountKeyStrategy"
    static let zeroPadDiscNumber = "settings.zeroPadDiscNumber"
    static let discCountKeyStrategy = "settings.discCountKeyStrategy"
    static let autoUpdateTrackTotal = "settings.autoUpdateTrackTotal"
    static let updateTrackTotalOnLockedTracks = "settings.updateTrackTotalOnLockedTracks"
}

enum SaveSettingsDefaults {
    static let defaultSavePayload = SavePayloadOption.writeTagsAndPictures
    static let defaultSaveScope = SaveScopeOption.allTracks
    static let zeroPadTrackNumber = true
    static let trackCountKeyStrategy = TrackCountKeyStrategy.both
    static let zeroPadDiscNumber = true
    static let discCountKeyStrategy = DiscCountKeyStrategy.totalDiscs
    static let autoUpdateTrackTotal = false
    static let updateTrackTotalOnLockedTracks = false
}

struct TagWriteOptions {
    let zeroPadTrackNumber: Bool
    let trackCountKeyStrategy: TrackCountKeyStrategy
    let zeroPadDiscNumber: Bool
    let discCountKeyStrategy: DiscCountKeyStrategy
}

struct SaveSettingsSnapshot {
    let payload: SavePayloadOption
    let scope: SaveScopeOption
    let tagWriteOptions: TagWriteOptions
}
