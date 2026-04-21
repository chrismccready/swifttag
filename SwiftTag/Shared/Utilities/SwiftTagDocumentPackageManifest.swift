import Foundation

struct SwiftTagDocumentManifest: Codable, Equatable {
    let id: String
    let version: String
    let fingerprint: String
    let tracks: [SwiftTagDocumentManifestTrack]
    let swiftTags: SwiftTagDocumentMetadata

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case version = "Version"
        case fingerprint = "Fingerprint"
        case tracks = "Tracks"
        case swiftTags = "SwiftTags"
    }
}

struct SwiftTagDocumentMetadata: Codable, Equatable {
    let author: String

    static let `default` = SwiftTagDocumentMetadata(author: "SwiftTag")

    enum CodingKeys: String, CodingKey {
        case author = "Author"
    }
}

struct SwiftTagDocumentManifestTrack: Codable, Equatable {
    let fingerprint: String
    let flacFileURL: String
    let flacFileBookmark: Data?
    let flacFingerprint: String?
    let sampleRate: String?
    let totalSamples: UInt64?
    let bitsPerSample: UInt32?
    let channels: UInt32?
    let duration: TimeInterval?
    let tags: [String: String]
    let pictures: [SwiftTagDocumentManifestPicture]

    enum CodingKeys: String, CodingKey {
        case fingerprint = "Fingerprint"
        case flacFileURL = "FLAC File URL"
        case flacFileBookmark = "FLAC File Bookmark"
        case flacFingerprint = "FLAC Fingerprint"
        case sampleRate = "Sample Rate"
        case totalSamples = "Total Samples"
        case bitsPerSample = "Bits Per Sample"
        case channels = "Channels"
        case duration = "Duration"
        case tags = "Tags"
        case pictures = "Pictures"
    }
}

struct SwiftTagDocumentManifestPicture: Codable, Equatable {
    let file: String
    let flacType: Int
    let mimeType: String
    let description: String
    let width: Int
    let height: Int
    let depth: Int
    let colors: Int

    enum CodingKeys: String, CodingKey {
        case file = "File"
        case flacType = "FLAC Type"
        case mimeType = "MIME Type"
        case description = "Description"
        case width = "Width"
        case height = "Height"
        case depth = "Depth"
        case colors = "Colors"
    }
}

struct SwiftTagDocumentPackage {
    let manifest: SwiftTagDocumentManifest
    let assetsByFileName: [String: Data]
    let documentID: UUID
}

extension PropertyListEncoder {
    static var swiftTagDocumentEncoder: PropertyListEncoder {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return encoder
    }
}

extension PropertyListDecoder {
    static var swiftTagDocumentDecoder: PropertyListDecoder {
        PropertyListDecoder()
    }
}
