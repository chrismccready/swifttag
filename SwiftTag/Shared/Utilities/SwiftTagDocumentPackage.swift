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
    case noTracks
    case unsupportedPictureFormat(mimeType: String)
    case invalidDestination
    case failedToWritePackage(message: String)
    case unsupportedVersion(version: String)
    case invalidDocumentID
    case missingPictureAsset(fileName: String)
    case failedToReadPackage(message: String)

    var errorDescription: String? {
        switch self {
        case .noTracks:
            return "There are no loaded tracks available to save into a SwiftTag document."
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

private struct SwiftTagDocumentManifest: Codable, Equatable {
    let id: String
    let version: String
    let fingerprint: String
    let tracks: [SwiftTagDocumentManifestTrack]

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case version = "Version"
        case fingerprint = "Fingerprint"
        case tracks = "Tracks"
    }
}

private struct SwiftTagDocumentManifestTrack: Codable, Equatable {
    let fingerprint: String
    let flacFileURL: String
    let flacFileBookmark: Data?
    let flacFingerprint: String?
    let tags: [String: String]
    let pictures: [SwiftTagDocumentManifestPicture]

    enum CodingKeys: String, CodingKey {
        case fingerprint = "Fingerprint"
        case flacFileURL = "FLAC File URL"
        case flacFileBookmark = "FLAC File Bookmark"
        case flacFingerprint = "FLAC Fingerprint"
        case tags = "Tags"
        case pictures = "Pictures"
    }
}

private struct SwiftTagDocumentManifestPicture: Codable, Equatable {
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

private struct SwiftTagDocumentAssetCandidate {
    let hash: String
    let flacType: Int
    let mimeType: String
    let fileExtension: String
    let specifications: PictureDataSpecifications
    let data: Data
}

private struct SwiftTagDocumentPackage {
    let manifest: SwiftTagDocumentManifest
    let assetsByFileName: [String: Data]
    let documentID: UUID
}

private enum SwiftTagDocumentPackageConstants {
    static let infoPlistFileName = "Info.plist"
    static let picturesDirectoryName = "Pictures"
}

enum SwiftTagDocumentPackageReader {
    static func read(
        from documentURL: URL,
        fileManager: FileManager = .default
    ) throws -> SwiftTagDocumentImportResult {
        let normalizedDocumentURL = documentURL.standardizedFileURL

        do {
            let package = try loadPackage(at: normalizedDocumentURL, fileManager: fileManager)
            let tracks = try package.manifest.tracks.map { manifestTrack in
                SwiftTagDocumentImportTrack(
                    documentTrackFingerprint: manifestTrack.fingerprint,
                    sourceFileURL: normalizedFileURL(from: manifestTrack.flacFileURL),
                    securityScopedBookmarkData: manifestTrack.flacFileBookmark,
                    flacFingerprint: normalizedOptionalString(manifestTrack.flacFingerprint),
                    tags: manifestTrack.tags,
                    pictures: try manifestTrack.pictures.map { manifestPicture in
                        FlacWritablePictureRecord(
                            type: manifestPicture.flacType,
                            mimeType: manifestPicture.mimeType,
                            description: manifestPicture.description,
                            data: try assetData(
                                named: manifestPicture.file,
                                from: package.assetsByFileName
                            ),
                            width: manifestPicture.width,
                            height: manifestPicture.height,
                            depth: manifestPicture.depth,
                            colors: manifestPicture.colors
                        )
                    }
                )
            }

            return SwiftTagDocumentImportResult(
                documentURL: normalizedDocumentURL,
                documentID: package.documentID,
                fingerprint: package.manifest.fingerprint,
                tracks: tracks,
                securityScopedBookmarkData: try? normalizedDocumentURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            )
        } catch let error as SwiftTagDocumentPackageError {
            throw error
        } catch {
            throw SwiftTagDocumentPackageError.failedToReadPackage(
                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    private static func loadPackage(
        at documentURL: URL,
        fileManager: FileManager
    ) throws -> SwiftTagDocumentPackage {
        let infoPlistURL = documentURL
            .appendingPathComponent(SwiftTagDocumentPackageConstants.infoPlistFileName)
        let picturesDirectoryURL = documentURL
            .appendingPathComponent(SwiftTagDocumentPackageConstants.picturesDirectoryName, isDirectory: true)

        let manifestData = try Data(contentsOf: infoPlistURL)
        let manifest = try PropertyListDecoder.swiftTagDocumentDecoder.decode(
            SwiftTagDocumentManifest.self,
            from: manifestData
        )

        guard manifest.version == SwiftTagDocumentType.version else {
            throw SwiftTagDocumentPackageError.unsupportedVersion(version: manifest.version)
        }

        guard let documentID = UUID(uuidString: manifest.id) else {
            throw SwiftTagDocumentPackageError.invalidDocumentID
        }

        let pictureFileNames = Set(manifest.tracks.flatMap(\.pictures).map(\.file))
        var assetsByFileName: [String: Data] = [:]

        for fileName in pictureFileNames {
            let assetURL = picturesDirectoryURL.appendingPathComponent(fileName)
            guard assetURL.lastPathComponent == fileName,
                  fileManager.fileExists(atPath: assetURL.path) else {
                throw SwiftTagDocumentPackageError.missingPictureAsset(fileName: fileName)
            }
            assetsByFileName[fileName] = try Data(contentsOf: assetURL)
        }

        return SwiftTagDocumentPackage(
            manifest: manifest,
            assetsByFileName: assetsByFileName,
            documentID: documentID
        )
    }

    private static func assetData(
        named fileName: String,
        from assetsByFileName: [String: Data]
    ) throws -> Data {
        guard let assetData = assetsByFileName[fileName] else {
            throw SwiftTagDocumentPackageError.missingPictureAsset(fileName: fileName)
        }

        return assetData
    }

    private static func normalizedFileURL(from rawValue: String) -> URL? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        if let fileURL = URL(string: trimmedValue), fileURL.isFileURL {
            return fileURL.standardizedFileURL
        }

        return URL(fileURLWithPath: trimmedValue).standardizedFileURL
    }

    private static func normalizedOptionalString(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : value
    }
}

enum SwiftTagDocumentPackageWriter {
    static func save(
        tracks: [SwiftTagDocumentExportTrack],
        state: SwiftTagDocumentSaveState,
        to destinationURL: URL,
        fileManager: FileManager = .default
    ) throws -> SwiftTagDocumentSaveResult {
        guard !tracks.isEmpty else {
            throw SwiftTagDocumentPackageError.noTracks
        }

        let normalizedDestinationURL = normalizedDestinationURL(destinationURL)
        guard !normalizedDestinationURL.lastPathComponent.isEmpty else {
            throw SwiftTagDocumentPackageError.invalidDestination
        }

        let documentID = resolvedDocumentID(
            state: state,
            destinationURL: normalizedDestinationURL,
            fileManager: fileManager
        )
        let package = try buildPackage(tracks: tracks, documentID: documentID)
        try write(package: package, to: normalizedDestinationURL, fileManager: fileManager)

        return SwiftTagDocumentSaveResult(
            destinationURL: normalizedDestinationURL,
            documentID: package.documentID,
            fingerprint: package.manifest.fingerprint,
            securityScopedBookmarkData: try? normalizedDestinationURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        )
    }

    private static func buildPackage(
        tracks: [SwiftTagDocumentExportTrack],
        documentID: UUID
    ) throws -> SwiftTagDocumentPackage {
        let sortedTracks = tracks.sorted { lhs, rhs in
            if lhs.sortKey != rhs.sortKey {
                return lhs.sortKey.localizedStandardCompare(rhs.sortKey) == .orderedAscending
            }

            let lhsTitle = lhs.tags[TagKey.title]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let rhsTitle = rhs.tags[TagKey.title]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return lhsTitle.localizedStandardCompare(rhsTitle) == .orderedAscending
        }

        var assetCandidatesByHash: [String: SwiftTagDocumentAssetCandidate] = [:]
        var manifestTracks: [SwiftTagDocumentManifestTrack] = []

        for track in sortedTracks {
            let normalizedPictures = try canonicalPictures(for: track.pictures)
            for picture in normalizedPictures {
                let candidate = try assetCandidate(for: picture)
                if let existingCandidate = assetCandidatesByHash[candidate.hash] {
                    if assetSortTuple(candidate) < assetSortTuple(existingCandidate) {
                        assetCandidatesByHash[candidate.hash] = candidate
                    }
                } else {
                    assetCandidatesByHash[candidate.hash] = candidate
                }
            }
        }

        let assetFileNameByHash = Dictionary(
            uniqueKeysWithValues: assetCandidatesByHash.values.map { candidate in
                (candidate.hash, "\(candidate.flacType)-\(candidate.hash).\(candidate.fileExtension)")
            }
        )

        for track in sortedTracks {
            let normalizedTags = canonicalTags(track.tags)
            let normalizedPictures = try canonicalPictures(for: track.pictures)
            let manifestPictures = try normalizedPictures.map { picture in
                let candidate = try assetCandidate(for: picture)
                guard let fileName = assetFileNameByHash[candidate.hash] else {
                    throw SwiftTagDocumentPackageError.failedToWritePackage(
                        message: "Failed to resolve a pooled picture asset filename during SwiftTag document export."
                    )
                }

                return SwiftTagDocumentManifestPicture(
                    file: fileName,
                    flacType: picture.type,
                    mimeType: picture.mimeType,
                    description: picture.description,
                    width: picture.width,
                    height: picture.height,
                    depth: picture.depth,
                    colors: picture.colors
                )
            }

            let trackFingerprint = fingerprint(
                lines:
                    normalizedTags.keys.sorted().map { key in
                        "TAG\t\(trimmedHashValue(key))\t\(trimmedHashValue(normalizedTags[key] ?? ""))"
                    }
                    + manifestPictures.map { picture in
                        [
                            "PIC",
                            picture.file,
                            String(picture.flacType),
                            trimmedHashValue(picture.mimeType),
                            trimmedHashValue(picture.description),
                            String(picture.width),
                            String(picture.height),
                            String(picture.depth),
                            String(picture.colors)
                        ].joined(separator: "\t")
                    }
            )

            manifestTracks.append(
                SwiftTagDocumentManifestTrack(
                    fingerprint: trackFingerprint,
                    flacFileURL: normalizedFileURLString(track.sourceFileURL),
                    flacFileBookmark: track.securityScopedBookmarkData,
                    flacFingerprint: normalizedOptionalString(track.flacFingerprint),
                    tags: normalizedTags,
                    pictures: manifestPictures
                )
            )
        }

        let documentFingerprint = fingerprint(
            lines: manifestTracks
                .map(\.fingerprint)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .sorted()
        )

        let manifest = SwiftTagDocumentManifest(
            id: documentID.uuidString,
            version: SwiftTagDocumentType.version,
            fingerprint: documentFingerprint,
            tracks: manifestTracks
        )

        let assetFilePairs: [(String, Data)] = assetCandidatesByHash.values.compactMap { candidate in
            guard let fileName = assetFileNameByHash[candidate.hash] else {
                return nil
            }

            return (fileName, candidate.data)
        }
        let assetsByFileName = Dictionary(
            uniqueKeysWithValues: assetFilePairs
        )

        return SwiftTagDocumentPackage(
            manifest: manifest,
            assetsByFileName: assetsByFileName,
            documentID: documentID
        )
    }

    private static func write(
        package: SwiftTagDocumentPackage,
        to destinationURL: URL,
        fileManager: FileManager
    ) throws {
        let tempContainerURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let tempPackageURL = tempContainerURL.appendingPathComponent(destinationURL.lastPathComponent, isDirectory: true)
        let tempPicturesDirectoryURL = tempPackageURL.appendingPathComponent(
            SwiftTagDocumentPackageConstants.picturesDirectoryName,
            isDirectory: true
        )
        defer {
            try? fileManager.removeItem(at: tempContainerURL)
        }

        do {
            try fileManager.createDirectory(at: tempPicturesDirectoryURL, withIntermediateDirectories: true)

            let plistData = try PropertyListEncoder.swiftTagDocumentEncoder.encode(package.manifest)
            try plistData.write(
                to: tempPackageURL.appendingPathComponent(SwiftTagDocumentPackageConstants.infoPlistFileName),
                options: .atomic
            )

            for assetFileName in package.assetsByFileName.keys.sorted() {
                guard let assetData = package.assetsByFileName[assetFileName] else {
                    continue
                }

                try assetData.write(
                    to: tempPicturesDirectoryURL.appendingPathComponent(assetFileName),
                    options: .atomic
                )
            }

            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: tempPackageURL)
            } else {
                try fileManager.moveItem(at: tempPackageURL, to: destinationURL)
            }
        } catch {
            throw SwiftTagDocumentPackageError.failedToWritePackage(
                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    private static func canonicalTags(_ tags: [String: String]) -> [String: String] {
        var normalizedTags: [String: String] = [:]

        for (rawKey, rawValue) in tags {
            let normalizedKey = TagNormalization.normalizeTagKey(rawKey)
            guard !normalizedKey.isEmpty, normalizedKey != TagKey.filename else {
                continue
            }

            if normalizedKey == TagKey.compilation {
                if CompilationTag.normalizedValue(rawValue) != nil {
                    normalizedTags[normalizedKey] = rawValue
                }
                continue
            }

            let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedValue.isEmpty else {
                continue
            }

            normalizedTags[normalizedKey] = rawValue
        }

        return normalizedTags
    }

    private static func canonicalPictures(for pictures: [FlacWritablePictureRecord]) throws -> [FlacWritablePictureRecord] {
        PictureRecordCanonicalizer.canonicalize(pictures)
    }

    private static func assetCandidate(for picture: FlacWritablePictureRecord) throws -> SwiftTagDocumentAssetCandidate {
        guard let assetDetails = PictureDataUtilities.supportedAssetDetails(
            mimeType: picture.mimeType,
            data: picture.data
        ) else {
            throw SwiftTagDocumentPackageError.unsupportedPictureFormat(mimeType: picture.mimeType)
        }

        return SwiftTagDocumentAssetCandidate(
            hash: PictureDataUtilities.sha256Hex(of: picture.data),
            flacType: picture.type,
            mimeType: assetDetails.mimeType,
            fileExtension: assetDetails.fileExtension,
            specifications: assetDetails.specifications,
            data: picture.data
        )
    }

    private static func assetSortTuple(_ candidate: SwiftTagDocumentAssetCandidate) -> String {
        [
            String(format: "%04d", candidate.flacType),
            candidate.mimeType,
            candidate.fileExtension,
            candidate.hash
        ].joined(separator: "|")
    }

    private static func normalizedDestinationURL(_ destinationURL: URL) -> URL {
        let standardizedURL = destinationURL.standardizedFileURL
        guard standardizedURL.pathExtension.localizedCaseInsensitiveCompare(SwiftTagDocumentType.fileExtension) != .orderedSame else {
            return standardizedURL
        }

        return standardizedURL.appendingPathExtension(SwiftTagDocumentType.fileExtension)
    }

    private static func resolvedDocumentID(
        state: SwiftTagDocumentSaveState,
        destinationURL: URL,
        fileManager: FileManager
    ) -> UUID {
        if let stateURL = state.destinationURL?.standardizedFileURL,
           stateURL == destinationURL,
           let rememberedDocumentID = state.documentID {
            return rememberedDocumentID
        }

        if let existingDocumentID = existingDocumentID(at: destinationURL, fileManager: fileManager) {
            return existingDocumentID
        }

        return state.documentID ?? UUID()
    }

    private static func existingDocumentID(at destinationURL: URL, fileManager: FileManager) -> UUID? {
        SwiftTagDocumentPackageIdentity.documentID(at: destinationURL, fileManager: fileManager)
    }

    private static func normalizedFileURLString(_ url: URL?) -> String {
        guard let url else {
            return ""
        }

        return url.standardizedFileURL.absoluteString
    }

    private static func normalizedOptionalString(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : value
    }

    private static func fingerprint(lines: [String]) -> String {
        let canonicalString = lines.joined(separator: "\n")
        return PictureDataUtilities.sha256Hex(of: Data(canonicalString.utf8))
    }

    private static func trimmedHashValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension PropertyListEncoder {
    static var swiftTagDocumentEncoder: PropertyListEncoder {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return encoder
    }
}

private extension PropertyListDecoder {
    static var swiftTagDocumentDecoder: PropertyListDecoder {
        PropertyListDecoder()
    }
}
