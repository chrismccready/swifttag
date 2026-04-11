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
    let tags: [String: String]
    let pictures: [FlacWritablePictureRecord]
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
