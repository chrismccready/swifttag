import Foundation

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
                    duration: manifestTrack.duration,
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
