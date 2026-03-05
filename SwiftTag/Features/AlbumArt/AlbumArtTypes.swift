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
