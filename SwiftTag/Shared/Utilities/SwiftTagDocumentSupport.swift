import Foundation
import UniformTypeIdentifiers

enum SwiftTagDocumentType {
    static let identifier = "com.toowalks.swifttag-document"
    static let fileExtension = "swifttag"
    static let version = "1.0.0"
}

extension UTType {
    static let swiftTagDocument = UTType(exportedAs: SwiftTagDocumentType.identifier, conformingTo: .package)
}

enum TrackDurationFormatter {
    static func string(from duration: TimeInterval?) -> String {
        guard let duration,
              duration.isFinite,
              duration >= 0,
              duration <= Double(Int.max) else {
            return ""
        }

        let totalSeconds = Int(duration.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

enum TrackSampleRateFormatter {
    static func string(from sampleRate: UInt32?) -> String? {
        guard let sampleRate, sampleRate > 0 else {
            return nil
        }

        let wholeKilohertz = sampleRate / 1_000
        let fractionalHertz = sampleRate % 1_000
        guard fractionalHertz > 0 else {
            return "\(wholeKilohertz) kHz"
        }

        var fractionalComponent = String(format: "%03u", fractionalHertz)
        while fractionalComponent.last == "0" {
            fractionalComponent.removeLast()
        }

        return "\(wholeKilohertz).\(fractionalComponent) kHz"
    }

    static func hertz(from displayString: String?) -> UInt32? {
        guard let displayString else {
            return nil
        }

        let trimmedDisplayString = displayString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplayString.isEmpty else {
            return nil
        }

        let normalizedDisplayString = trimmedDisplayString.lowercased()
        guard normalizedDisplayString.hasSuffix("khz") else {
            return nil
        }

        let numberPortion = normalizedDisplayString
            .dropLast(3)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !numberPortion.isEmpty else {
            return nil
        }

        let components = numberPortion.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count <= 2,
              let wholeKilohertz = UInt64(components[0]) else {
            return nil
        }

        var fractionalHertz: UInt64 = 0
        if components.count == 2 {
            let fractionalComponent = String(components[1])
            guard !fractionalComponent.isEmpty,
                  fractionalComponent.allSatisfy(\.isNumber),
                  fractionalComponent.count <= 3 else {
                return nil
            }

            let paddedFractionalComponent = fractionalComponent.padding(toLength: 3, withPad: "0", startingAt: 0)
            guard let parsedFractionalHertz = UInt64(paddedFractionalComponent) else {
                return nil
            }

            fractionalHertz = parsedFractionalHertz
        }

        let sampleRate = wholeKilohertz * 1_000 + fractionalHertz
        guard sampleRate > 0, sampleRate <= UInt64(UInt32.max) else {
            return nil
        }

        return UInt32(sampleRate)
    }
}

struct SwiftTagDocumentSaveState: Equatable {
    var destinationURL: URL?
    var documentID: UUID?
    var securityScopedBookmarkData: Data?
    var lastKnownDisplayName: String?
    var availability: SwiftTagDocumentAvailability = .available

    var liveDestinationURL: URL? {
        guard availability == .available else {
            return nil
        }

        return destinationURL?.standardizedFileURL
    }

    var navigationDocumentURL: URL? {
        destinationURL?.standardizedFileURL
    }

    var documentDisplayName: String? {
        if let liveName = liveDestinationURL?.lastPathComponent,
           !liveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return liveName
        }

        if let lastKnownDisplayName,
           !lastKnownDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return lastKnownDisplayName
        }

        if let destinationName = destinationURL?.lastPathComponent,
           !destinationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return destinationName
        }

        return nil
    }

    var hasReferencedDocument: Bool {
        liveDestinationURL != nil ||
            navigationDocumentURL != nil ||
            documentID != nil ||
            securityScopedBookmarkData != nil ||
            documentDisplayName != nil
    }

    var isDeleted: Bool {
        availability == .deleted
    }
}

enum SwiftTagDocumentAvailability: String, Codable, Equatable {
    case available
    case deleted
}

struct SwiftTagDocumentSaveResult: Equatable {
    let destinationURL: URL
    let documentID: UUID
    let fingerprint: String
    let securityScopedBookmarkData: Data?

    init(
        destinationURL: URL,
        documentID: UUID,
        fingerprint: String,
        securityScopedBookmarkData: Data? = nil
    ) {
        self.destinationURL = destinationURL
        self.documentID = documentID
        self.fingerprint = fingerprint
        self.securityScopedBookmarkData = securityScopedBookmarkData
    }
}

struct SwiftTagDocumentImportTrack: Equatable {
    let documentTrackFingerprint: String
    let sourceFileURL: URL?
    let securityScopedBookmarkData: Data?
    let flacFingerprint: String?
    let sampleRate: UInt32?
    let totalSamples: UInt64?
    let bitsPerSample: UInt32?
    let channels: UInt32?
    let duration: TimeInterval?
    let tags: [String: String]
    let pictures: [FlacWritablePictureRecord]

    init(
        documentTrackFingerprint: String,
        sourceFileURL: URL?,
        securityScopedBookmarkData: Data?,
        flacFingerprint: String?,
        sampleRate: UInt32? = nil,
        totalSamples: UInt64? = nil,
        bitsPerSample: UInt32? = nil,
        channels: UInt32? = nil,
        duration: TimeInterval? = nil,
        tags: [String: String],
        pictures: [FlacWritablePictureRecord]
    ) {
        self.documentTrackFingerprint = documentTrackFingerprint
        self.sourceFileURL = sourceFileURL
        self.securityScopedBookmarkData = securityScopedBookmarkData
        self.flacFingerprint = flacFingerprint
        self.sampleRate = sampleRate
        self.totalSamples = totalSamples
        self.bitsPerSample = bitsPerSample
        self.channels = channels
        self.duration = duration
        self.tags = tags
        self.pictures = pictures
    }
}

struct SwiftTagDocumentImportResult: Equatable {
    let documentURL: URL
    let documentID: UUID
    let fingerprint: String
    let tracks: [SwiftTagDocumentImportTrack]
    let securityScopedBookmarkData: Data?

    init(
        documentURL: URL,
        documentID: UUID,
        fingerprint: String,
        tracks: [SwiftTagDocumentImportTrack],
        securityScopedBookmarkData: Data? = nil
    ) {
        self.documentURL = documentURL
        self.documentID = documentID
        self.fingerprint = fingerprint
        self.tracks = tracks
        self.securityScopedBookmarkData = securityScopedBookmarkData
    }
}

enum SwiftTagDocumentPackageIdentity {
    static func documentID(
        at documentURL: URL,
        fileManager: FileManager = .default
    ) -> UUID? {
        guard fileManager.fileExists(atPath: documentURL.path) else {
            return nil
        }

        let infoPlistURL = documentURL
            .appendingPathComponent(SwiftTagDocumentPackageConstants.infoPlistFileName)
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
              let dictionary = plist as? [String: Any],
              let rawID = dictionary["Id"] as? String else {
            return nil
        }

        return UUID(uuidString: rawID)
    }
}

struct SwiftTagDocumentExportTrack: Equatable {
    let sortKey: String
    let tags: [String: String]
    let pictures: [FlacWritablePictureRecord]
    let sourceFileURL: URL?
    let securityScopedBookmarkData: Data?
    let flacFingerprint: String?
    let sampleRate: UInt32?
    let totalSamples: UInt64?
    let bitsPerSample: UInt32?
    let channels: UInt32?
    let duration: TimeInterval?

    init(
        sortKey: String,
        tags: [String: String],
        pictures: [FlacWritablePictureRecord],
        sourceFileURL: URL?,
        securityScopedBookmarkData: Data?,
        flacFingerprint: String?,
        sampleRate: UInt32? = nil,
        totalSamples: UInt64? = nil,
        bitsPerSample: UInt32? = nil,
        channels: UInt32? = nil,
        duration: TimeInterval? = nil
    ) {
        self.sortKey = sortKey
        self.tags = tags
        self.pictures = pictures
        self.sourceFileURL = sourceFileURL
        self.securityScopedBookmarkData = securityScopedBookmarkData
        self.flacFingerprint = flacFingerprint
        self.sampleRate = sampleRate
        self.totalSamples = totalSamples
        self.bitsPerSample = bitsPerSample
        self.channels = channels
        self.duration = duration
    }
}

enum SwiftTagDocumentPackageError: LocalizedError {
    case unsupportedPictureFormat(mimeType: String)
    case invalidDestination
    case failedToWritePackage(message: String)
    case unsupportedVersion(version: String)
    case invalidDocumentID
    case missingPictureAsset(fileName: String)
    case failedToReadPackage(message: String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedPictureFormat(mimeType):
            if mimeType.isEmpty {
                return "SwiftTag document export supports only JPEG and PNG picture assets."
            }

            return "SwiftTag document export supports only JPEG and PNG picture assets. Found \(mimeType)."
        case .invalidDestination:
            return "The selected SwiftTag document destination is invalid."
        case let .failedToWritePackage(message):
            return message
        case let .unsupportedVersion(version):
            return "SwiftTag document version \(version) is not supported."
        case .invalidDocumentID:
            return "The SwiftTag document contains an invalid document identifier."
        case let .missingPictureAsset(fileName):
            return "The SwiftTag document is missing picture asset \(fileName)."
        case let .failedToReadPackage(message):
            return message
        }
    }
}

enum SwiftTagDocumentPackageConstants {
    static let infoPlistFileName = "Info.plist"
    static let picturesDirectoryName = "Pictures"
}
