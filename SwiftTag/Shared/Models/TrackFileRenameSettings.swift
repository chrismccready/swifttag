import Foundation

enum TrackFileRenameInvalidReplacementText: String, CaseIterable, Identifiable {
    case hyphen
    case underscore
    case period
    case space

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hyphen:
            return "-"
        case .underscore:
            return "_"
        case .period:
            return "."
        case .space:
            return "space"
        }
    }

    var replacement: String {
        switch self {
        case .hyphen:
            return "-"
        case .underscore:
            return "_"
        case .period:
            return "."
        case .space:
            return " "
        }
    }
}

enum TrackFileRenameSpaceReplacement: String, CaseIterable, Identifiable {
    case hyphen
    case underscore
    case period
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hyphen:
            return "-"
        case .underscore:
            return "_"
        case .period:
            return "."
        case .none:
            return "none"
        }
    }

    var replacement: String? {
        switch self {
        case .hyphen:
            return "-"
        case .underscore:
            return "_"
        case .period:
            return "."
        case .none:
            return nil
        }
    }
}

enum TrackFileRenameSettingsKey {
    static let format = "settings.trackFileRename.format"
    static let invalidReplacementText = "settings.trackFileRename.invalidReplacementText"
    static let spaceReplacement = "settings.trackFileRename.spaceReplacement"
    static let strict = "settings.trackFileRename.strict"
}

enum TrackFileRenameSettingsDefaults {
    static let format = "|TRACKNUMBER| |TITLE|"
    static let invalidReplacementText = TrackFileRenameInvalidReplacementText.hyphen
    static let spaceReplacement = TrackFileRenameSpaceReplacement.none
    static let strict = false
}

struct TrackFileRenameConfiguration: Equatable {
    var format: String
    var invalidReplacementText: TrackFileRenameInvalidReplacementText
    var spaceReplacement: TrackFileRenameSpaceReplacement
    var strict: Bool

    static let defaults = Self(
        format: TrackFileRenameSettingsDefaults.format,
        invalidReplacementText: TrackFileRenameSettingsDefaults.invalidReplacementText,
        spaceReplacement: TrackFileRenameSettingsDefaults.spaceReplacement,
        strict: TrackFileRenameSettingsDefaults.strict
    )
}

enum TrackFileRenameScope: Equatable {
    case selectedTracks
    case allTracks
}
