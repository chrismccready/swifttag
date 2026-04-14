import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum AlbumArtSlot: Hashable {
    case other
    case pngIcon
    case otherIcon
    case frontCover
    case backCover
    case leaflet
    case media
    case leadArtist
    case artist
    case conductor
    case band
    case composer
    case lyricist
    case recordingStudioOrLocation
    case recordingSession
    case performance
    case captureFromMovieOrVideo
    case brightlyColoredFish
    case illustration
    case bandLogo
    case publisherLogo
}

extension AlbumArtSlot {
    var accessibilityIdentifierComponent: String {
        switch self {
        case .other:
            "other"
        case .pngIcon:
            "pngIcon"
        case .otherIcon:
            "otherIcon"
        case .frontCover:
            "frontCover"
        case .backCover:
            "backCover"
        case .leaflet:
            "leaflet"
        case .media:
            "media"
        case .leadArtist:
            "leadArtist"
        case .artist:
            "artist"
        case .conductor:
            "conductor"
        case .band:
            "band"
        case .composer:
            "composer"
        case .lyricist:
            "lyricist"
        case .recordingStudioOrLocation:
            "recordingStudioOrLocation"
        case .recordingSession:
            "recordingSession"
        case .performance:
            "performance"
        case .captureFromMovieOrVideo:
            "captureFromMovieOrVideo"
        case .brightlyColoredFish:
            "brightlyColoredFish"
        case .illustration:
            "illustration"
        case .bandLogo:
            "bandLogo"
        case .publisherLogo:
            "publisherLogo"
        }
    }
}

struct AlbumArtType: Identifiable {
    let flacPictureType: Int
    let flacDescription: String
    let navigationLinkName: String
    let slot: AlbumArtSlot

    var id: AlbumArtSlot { slot }
}

struct AlbumArtImageAsset {
    let image: NSImage
    let type: UTType
    let data: Data
}

struct AlbumArtPoolItem: Identifiable, Equatable {
    let id: UUID
    let data: Data
    let image: NSImage
}

struct AlbumArtTrackReference: Identifiable, Equatable {
    let id: UUID
    let poolItemID: UUID
    let slot: AlbumArtSlot
    let mimeType: String
    let description: String

    init(
        id: UUID = UUID(),
        poolItemID: UUID,
        slot: AlbumArtSlot,
        mimeType: String,
        description: String
    ) {
        self.id = id
        self.poolItemID = poolItemID
        self.slot = slot
        self.mimeType = mimeType
        self.description = description
    }
    
    func poolItemIDShort() -> String {
        return String(self.poolItemID.uuidString.prefix(8))
    }
}

struct AlbumArtExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png, .jpeg] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
