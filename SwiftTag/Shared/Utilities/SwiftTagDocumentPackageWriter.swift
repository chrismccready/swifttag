import Foundation

private struct SwiftTagDocumentAssetCandidate {
    let hash: String
    let flacType: Int
    let mimeType: String
    let fileExtension: String
    let specifications: PictureDataSpecifications
    let data: Data
}

enum SwiftTagDocumentPackageWriter {
    static func save(
        tracks: [SwiftTagDocumentExportTrack],
        state: SwiftTagDocumentSaveState,
        to destinationURL: URL,
        fileManager: FileManager = .default
    ) throws -> SwiftTagDocumentSaveResult {
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

    static func trackTagsAndPicturesFingerprint(
        tags: [String: String],
        pictures: [FlacWritablePictureRecord]
    ) throws -> String {
        let normalizedTags = canonicalTags(tags)
        let normalizedPictures = try canonicalPictures(for: pictures)
        let manifestPictures = try normalizedPictures.map { picture in
            let candidate = try assetCandidate(for: picture)
            let fileName = "\(candidate.flacType)-\(candidate.hash).\(candidate.fileExtension)"

            return SwiftTagDocumentManifestPicture(
                file: fileName,
                flacType: picture.type,
                mimeType: candidate.mimeType,
                description: picture.description,
                width: picture.width,
                height: picture.height,
                depth: picture.depth,
                colors: picture.colors
            )
        }

        return fingerprint(
            lines: trackFingerprintLines(
                normalizedTags: normalizedTags,
                manifestPictures: manifestPictures
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

            let normalizedTags = canonicalTags(track.tags)
            let trackFingerprint = fingerprint(
                lines: trackFingerprintLines(
                    normalizedTags: normalizedTags,
                    manifestPictures: manifestPictures
                )
            )

            manifestTracks.append(
                SwiftTagDocumentManifestTrack(
                    fingerprint: trackFingerprint,
                    flacFileURL: normalizedFileURLString(track.sourceFileURL),
                    flacFileBookmark: track.securityScopedBookmarkData,
                    flacFingerprint: normalizedOptionalString(track.flacFingerprint),
                    sampleRate: TrackSampleRateFormatter.string(from: track.sampleRate),
                    totalSamples: track.totalSamples,
                    bitsPerSample: track.bitsPerSample,
                    channels: track.channels,
                    duration: track.duration,
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
            tracks: manifestTracks,
            swiftTags: .default
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

        return UUID()
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

    private static func trackFingerprintLines(
        normalizedTags: [String: String],
        manifestPictures: [SwiftTagDocumentManifestPicture]
    ) -> [String] {
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
    }

    private static func fingerprint(lines: [String]) -> String {
        let canonicalString = lines.joined(separator: "\n")
        return PictureDataUtilities.sha256Hex(of: Data(canonicalString.utf8))
    }

    private static func trimmedHashValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
