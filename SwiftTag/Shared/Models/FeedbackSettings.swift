import AppKit
import SwiftUI

enum SaveNotificationMode: String, CaseIterable, Identifiable, Codable {
    case always
    case whenNotFrontmost
    case never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .always:
            return "Always"
        case .whenNotFrontmost:
            return "When Not Frontmost"
        case .never:
            return "Never"
        }
    }
}

enum AppThemePreference: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum DiffTagIdentifier: String, CaseIterable, Identifiable, Codable {
    case title
    case album
    case albumArtist
    case totalTracks
    case totalDiscs
    case trackNumber
    case discNumber
    case genre
    case artist
    case composer
    case location
    case date
    case description
    case misc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .title:
            return "Title"
        case .album:
            return "Album"
        case .albumArtist:
            return "Album Artist"
        case .totalTracks:
            return "Total Tracks"
        case .totalDiscs:
            return "Total Discs"
        case .trackNumber:
            return "Number"
        case .discNumber:
            return "Disc"
        case .genre:
            return "Genre"
        case .artist:
            return "Artist"
        case .composer:
            return "Composer"
        case .location:
            return "Location"
        case .date:
            return "Date"
        case .description:
            return "Description"
        case .misc:
            return "Misc"
        }
    }
}

enum FeedbackSettingsKey {
    static let saveNotificationMode = "settings.feedback.saveNotificationMode"
    static let themePreference = "settings.feedback.themePreference"
    static let trackToTrackDiffColor = "settings.feedback.trackToTrackDiffColor"
    static let trackToFileDiffColor = "settings.feedback.trackToFileDiffColor"
    static let externallyModifiedDiffColor = "settings.feedback.externallyModifiedDiffColor"
    static let trackDiscTotalMismatchColor = "settings.feedback.trackDiscTotalMismatchColor"
    static let pictureStatusOverlayColor = "settings.feedback.pictureStatusOverlayColor"
    static let formatOnTrackToFileDiff = "settings.diffTools.formatOnTrackToFileDiff"
    static let formatOnTrackToTrackDiff = "settings.diffTools.formatOnTrackToTrackDiff"
    static let formatOnExternallyModifiedDiff = "settings.diffTools.formatOnExternallyModifiedDiff"
    static let formatOnTrackTotalMismatch = "settings.diffTools.formatOnTrackTotalMismatch"
    static let formatOnDiscTotalMismatch = "settings.diffTools.formatOnDiscTotalMismatch"
    static let formatOnDuplicatePicture = "settings.diffTools.formatOnDuplicatePicture"
}

enum FeedbackSettingsDefaults {
    static let saveNotificationMode = SaveNotificationMode.whenNotFrontmost
    static let themePreference = AppThemePreference.system
    static let trackToTrackDiffColor = AppColorStorage.archive(Color.orange, fallback: .systemOrange)
    static let trackToFileDiffColor = AppColorStorage.archive(Color.primary, fallback: .labelColor)
    static let externallyModifiedDiffColor = AppColorStorage.archive(Color.red, fallback: .systemRed)
    static let trackDiscTotalMismatchColor = AppColorStorage.archive(Color.red, fallback: .systemRed)
    static let pictureStatusOverlayColor = AppColorStorage.archive(Color.orange, fallback: .systemOrange)
    static let formatOnTrackToFileDiff = true
    static let formatOnTrackToTrackDiff = true
    static let formatOnExternallyModifiedDiff = true
    static let formatOnTrackTotalMismatch = true
    static let formatOnDiscTotalMismatch = true
    static let formatOnDuplicatePicture = true
}

enum AppColorStorage {
    static func archive(_ color: Color, fallback: NSColor) -> String {
        let resolvedColor = NSColor(color).usingColorSpace(.deviceRGB)
            ?? fallback.usingColorSpace(.deviceRGB)
            ?? fallback

        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: resolvedColor,
            requiringSecureCoding: true
        ) else {
            return ""
        }

        return data.base64EncodedString()
    }

    static func color(from rawValue: String, fallback: NSColor) -> Color {
        guard
            let data = Data(base64Encoded: rawValue),
            let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        else {
            return Color(nsColor: fallback)
        }

        return Color(nsColor: color)
    }

    static func binding(
        rawValue: Binding<String>,
        fallback: NSColor
    ) -> Binding<Color> {
        Binding(
            get: {
                color(from: rawValue.wrappedValue, fallback: fallback)
            },
            set: { newValue in
                rawValue.wrappedValue = archive(newValue, fallback: fallback)
            }
        )
    }
}
