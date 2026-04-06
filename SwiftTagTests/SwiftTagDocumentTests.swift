import AppKit
import Foundation
import Testing
import zlib
@testable import SwiftTag

struct SwiftTagDocumentTests {
    private static var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTagTestFiles")
            .appendingPathComponent("test.flac")
    }

    private static var defaultTagWriteOptions: TagWriteOptions {
        TagWriteOptions(
            zeroPadTrackNumber: SaveSettingsDefaults.zeroPadTrackNumber,
            trackCountKeyStrategy: SaveSettingsDefaults.trackCountKeyStrategy,
            zeroPadDiscNumber: SaveSettingsDefaults.zeroPadDiscNumber,
            discCountKeyStrategy: SaveSettingsDefaults.discCountKeyStrategy
        )
    }

    private static func tempFixtureCopyURL(name: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent(name)
        try FileManager.default.copyItem(at: fixtureURL, to: fileURL)
        return fileURL
    }

    @MainActor
    private static func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        pollIntervalNanoseconds: UInt64 = 25_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        return condition()
    }

    @MainActor
    private static func writeLiveTitle(_ title: String, to fileURL: URL) async throws {
        let metadata = try FlacMetadataService.readTags(for: fileURL)
        var tags = metadata.tags
        tags["TITLE"] = title

        try FlacMetadataService.writeMetadata(
            tags: tags,
            to: fileURL,
            writeTags: true,
            writePictures: false
        )
    }

    @MainActor
    private static func writeLivePictures(_ pictures: [FlacWritablePictureRecord], to fileURL: URL) throws {
        _ = try FlacMetadataService.writeMetadata(
            tags: [:],
            pictures: pictures,
            to: fileURL,
            writeTags: false,
            writePictures: true
        )
    }

    private static func pngData(color: NSColor) throws -> Data {
        let imageSize = NSSize(width: 2, height: 2)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRepresentation.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SwiftTagDocumentTests", code: 1)
        }

        return pngData
    }

    private static func jpegData(color: NSColor) throws -> Data {
        let imageSize = NSSize(width: 2, height: 2)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRepresentation.representation(using: .jpeg, properties: [:]) else {
            throw NSError(domain: "SwiftTagDocumentTests", code: 2)
        }

        return jpegData
    }

    private static func indexedPNGData(
        palette: [(UInt8, UInt8, UInt8)],
        pixelRows: [[UInt8]],
        bitDepth: UInt8 = 8
    ) throws -> Data {
        guard let rowWidth = pixelRows.first?.count, !pixelRows.isEmpty else {
            throw NSError(domain: "SwiftTagDocumentTests", code: 3)
        }

        guard pixelRows.allSatisfy({ $0.count == rowWidth }) else {
            throw NSError(domain: "SwiftTagDocumentTests", code: 4)
        }

        var rawImageData = Data()
        for row in pixelRows {
            rawImageData.append(0) // No filter.
            rawImageData.append(contentsOf: row)
        }

        let compressedImageData = try zlibCompressed(rawImageData)
        var pngData = Data([137, 80, 78, 71, 13, 10, 26, 10])

        var ihdrData = Data()
        ihdrData.append(contentsOf: UInt32(rowWidth).bigEndianBytes)
        ihdrData.append(contentsOf: UInt32(pixelRows.count).bigEndianBytes)
        ihdrData.append(bitDepth)
        ihdrData.append(3) // Indexed-color PNG.
        ihdrData.append(0)
        ihdrData.append(0)
        ihdrData.append(0)

        let paletteData = Data(
            palette.flatMap { color in
                [color.0, color.1, color.2]
            }
        )

        pngData.append(pngChunk(type: "IHDR", data: ihdrData))
        pngData.append(pngChunk(type: "PLTE", data: paletteData))
        pngData.append(pngChunk(type: "IDAT", data: compressedImageData))
        pngData.append(pngChunk(type: "IEND", data: Data()))
        return pngData
    }

    private static func pngChunk(type: String, data: Data) -> Data {
        let typeData = Data(type.utf8)
        var chunk = Data()
        chunk.append(contentsOf: UInt32(data.count).bigEndianBytes)
        chunk.append(typeData)
        chunk.append(data)

        let checksum = typeData.withUnsafeBytes { typeBuffer in
            data.withUnsafeBytes { dataBuffer in
                let typePointer = typeBuffer.bindMemory(to: Bytef.self).baseAddress
                let dataPointer = dataBuffer.bindMemory(to: Bytef.self).baseAddress
                let typeChecksum = crc32(0, typePointer, uInt(typeData.count))
                return crc32(typeChecksum, dataPointer, uInt(data.count))
            }
        }
        chunk.append(contentsOf: UInt32(checksum).bigEndianBytes)
        return chunk
    }

    private static func zlibCompressed(_ data: Data) throws -> Data {
        let sourceData = data.isEmpty ? Data([0]) : data
        let destinationCapacity = Int(compressBound(uLong(sourceData.count)))
        var destination = Data(count: destinationCapacity)
        var compressedLength = uLongf(destinationCapacity)

        let status = destination.withUnsafeMutableBytes { destinationBuffer in
            sourceData.withUnsafeBytes { sourceBuffer in
                compress2(
                    destinationBuffer.bindMemory(to: Bytef.self).baseAddress,
                    &compressedLength,
                    sourceBuffer.bindMemory(to: Bytef.self).baseAddress,
                    uLong(sourceData.count),
                    Z_BEST_COMPRESSION
                )
            }
        }

        guard status == Z_OK else {
            throw NSError(domain: "SwiftTagDocumentTests", code: 5)
        }

        destination.removeSubrange(Int(compressedLength) ..< destination.count)
        return destination
    }

    private static func tempPackageURL(name: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent(name).appendingPathExtension(SwiftTagDocumentType.fileExtension)
    }

    private static func plistDictionary(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try #require(plist as? [String: Any])
    }

    @Test
    func swiftTagDocumentWriterWritesPackageAndDeduplicatesPictures() throws {
        let sharedPNG = try Self.pngData(color: .systemRed)
        let sharedPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Cover (front)",
            data: sharedPNG
        ).withComputedPictureMetadata()
        let secondPicture = FlacWritablePictureRecord(
            type: 4,
            mimeType: "image/jpeg",
            description: "Back",
            data: try Self.jpegData(color: .systemBlue)
        ).withComputedPictureMetadata()

        let destinationURL = try Self.tempPackageURL(name: "shared-package")
        let result = try SwiftTagDocumentPackageWriter.save(
            tracks: [
                SwiftTagDocumentExportTrack(
                    sortKey: "/tmp/a.flac",
                    tags: [TagKey.title: "One"],
                    pictures: [sharedPicture, secondPicture],
                    sourceFileURL: URL(fileURLWithPath: "/tmp/a.flac"),
                    securityScopedBookmarkData: Data([0x01, 0x02]),
                    flacFingerprint: " abc123 "
                ),
                SwiftTagDocumentExportTrack(
                    sortKey: "/tmp/b.flac",
                    tags: [TagKey.title: "Two"],
                    pictures: [sharedPicture],
                    sourceFileURL: URL(fileURLWithPath: "/tmp/b.flac"),
                    securityScopedBookmarkData: Data([0x03, 0x04]),
                    flacFingerprint: "def456"
                )
            ],
            state: .init(),
            to: destinationURL
        )

        let picturesDirectoryURL = destinationURL.appendingPathComponent("Pictures", isDirectory: true)
        let pictureFileNames = try FileManager.default.contentsOfDirectory(atPath: picturesDirectoryURL.path).sorted()
        #expect(pictureFileNames.count == 2)

        let manifest = try Self.plistDictionary(at: destinationURL.appendingPathComponent("Info.plist"))
        #expect(manifest["Id"] as? String == result.documentID.uuidString)
        #expect(manifest["Version"] as? String == SwiftTagDocumentType.version)
        #expect(manifest["Fingerprint"] as? String == result.fingerprint)

        let manifestTracks = try #require(manifest["Tracks"] as? [[String: Any]])
        #expect(manifestTracks.count == 2)
        #expect(
            manifestTracks[0]["FLAC File URL"] as? String
                == URL(fileURLWithPath: "/tmp/a.flac").standardizedFileURL.absoluteString
        )
        #expect(manifestTracks[0]["FLAC Fingerprint"] as? String == " abc123 ")

        let firstTrackPictures = try #require(manifestTracks[0]["Pictures"] as? [[String: Any]])
        let secondTrackPictures = try #require(manifestTracks[1]["Pictures"] as? [[String: Any]])
        let sharedFileName = try #require(firstTrackPictures.first?["File"] as? String)
        #expect(sharedFileName == secondTrackPictures.first?["File"] as? String)
        #expect(sharedFileName.hasSuffix(".png"))
        #expect(firstTrackPictures[0]["Width"] as? Int == sharedPicture.width)
        #expect(firstTrackPictures[0]["Height"] as? Int == sharedPicture.height)
    }

    @Test
    func swiftTagDocumentReaderLoadsWrittenPackage() throws {
        let sharedPNG = try Self.pngData(color: .systemOrange)
        let sharedPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Cover (front)",
            data: sharedPNG
        ).withComputedPictureMetadata()
        let destinationURL = try Self.tempPackageURL(name: "reader-roundtrip")
        let saveResult = try SwiftTagDocumentPackageWriter.save(
            tracks: [
                SwiftTagDocumentExportTrack(
                    sortKey: "/tmp/reader.flac",
                    tags: [TagKey.title: "Reader Track"],
                    pictures: [sharedPicture],
                    sourceFileURL: URL(fileURLWithPath: "/tmp/reader.flac"),
                    securityScopedBookmarkData: Data([0x0A, 0x0B]),
                    flacFingerprint: "reader-fingerprint"
                )
            ],
            state: .init(),
            to: destinationURL
        )

        let loadedDocument = try SwiftTagDocumentPackageReader.read(from: destinationURL)

        #expect(loadedDocument.documentURL == destinationURL.standardizedFileURL)
        #expect(loadedDocument.documentID == saveResult.documentID)
        #expect(loadedDocument.fingerprint == saveResult.fingerprint)
        let loadedTrack = try #require(loadedDocument.tracks.first)
        #expect(loadedTrack.sourceFileURL?.path == "/tmp/reader.flac")
        #expect(loadedTrack.securityScopedBookmarkData == Data([0x0A, 0x0B]))
        #expect(loadedTrack.flacFingerprint == "reader-fingerprint")
        #expect(loadedTrack.tags[TagKey.title] == "Reader Track")
        #expect(loadedTrack.pictures == [sharedPicture])
    }

    @Test
    func pictureDataUtilitiesComputesPaletteColorCountForIndexedPNG() throws {
        let indexedPNG = try Self.indexedPNGData(
            palette: [
                (255, 0, 0),
                (0, 255, 0),
                (0, 0, 255)
            ],
            pixelRows: [[0, 1]]
        )

        let specifications = PictureDataUtilities.computedSpecifications(from: indexedPNG)

        #expect(specifications.width == 2)
        #expect(specifications.height == 1)
        #expect(specifications.depth == 8)
        #expect(specifications.colors == 3)
    }

    @Test
    func pictureDataUtilitiesComputesBitsPerPixelDepthForJPEGAndRGBAPNG() throws {
        let jpegSpecifications = PictureDataUtilities.computedSpecifications(
            from: try Self.jpegData(color: .systemBlue)
        )
        let pngSpecifications = PictureDataUtilities.computedSpecifications(
            from: try Self.pngData(color: .systemRed)
        )

        #expect(jpegSpecifications.width > 0)
        #expect(jpegSpecifications.height > 0)
        #expect(jpegSpecifications.depth == 24)

        #expect(pngSpecifications.width > 0)
        #expect(pngSpecifications.height > 0)
        #expect(pngSpecifications.depth == 32)
    }

    @Test
    func swiftTagDocumentWriterPreservesExistingDocumentIDWhenOverwritingPackage() throws {
        let destinationURL = try Self.tempPackageURL(name: "preserve-id")
        let track = SwiftTagDocumentExportTrack(
            sortKey: "/tmp/one.flac",
            tags: [TagKey.title: "One"],
            pictures: [],
            sourceFileURL: URL(fileURLWithPath: "/tmp/one.flac"),
            securityScopedBookmarkData: nil,
            flacFingerprint: "fingerprint-1"
        )

        let firstResult = try SwiftTagDocumentPackageWriter.save(
            tracks: [track],
            state: .init(),
            to: destinationURL
        )

        let secondResult = try SwiftTagDocumentPackageWriter.save(
            tracks: [
                SwiftTagDocumentExportTrack(
                    sortKey: "/tmp/one.flac",
                    tags: [TagKey.title: "Updated"],
                    pictures: [],
                    sourceFileURL: URL(fileURLWithPath: "/tmp/one.flac"),
                    securityScopedBookmarkData: nil,
                    flacFingerprint: "fingerprint-2"
                )
            ],
            state: .init(),
            to: destinationURL
        )

        #expect(secondResult.documentID == firstResult.documentID)
    }

    @Test
    func swiftTagDocumentWriterUsesStableFingerprintForReorderedTracks() throws {
        let firstDestinationURL = try Self.tempPackageURL(name: "fingerprint-a")
        let secondDestinationURL = try Self.tempPackageURL(name: "fingerprint-b")
        let tracks = [
            SwiftTagDocumentExportTrack(
                sortKey: "/tmp/b.flac",
                tags: [TagKey.title: "Two"],
                pictures: [],
                sourceFileURL: URL(fileURLWithPath: "/tmp/b.flac"),
                securityScopedBookmarkData: nil,
                flacFingerprint: "fingerprint-b"
            ),
            SwiftTagDocumentExportTrack(
                sortKey: "/tmp/a.flac",
                tags: [TagKey.title: "One"],
                pictures: [],
                sourceFileURL: URL(fileURLWithPath: "/tmp/a.flac"),
                securityScopedBookmarkData: nil,
                flacFingerprint: "fingerprint-a"
            )
        ]

        let firstResult = try SwiftTagDocumentPackageWriter.save(
            tracks: tracks,
            state: .init(),
            to: firstDestinationURL
        )
        let secondResult = try SwiftTagDocumentPackageWriter.save(
            tracks: tracks.reversed(),
            state: .init(),
            to: secondDestinationURL
        )

        #expect(firstResult.fingerprint == secondResult.fingerprint)
    }

    @MainActor
    @Test
    func tagEditorViewModelExportsCurrentEditorTagsForSwiftTagDocument() {
        let track = Track(
            album: "Edited Album",
            albumArtist: "Edited Artist",
            totalTracks: "12",
            tags: [
                TagKey.album: "Original Album",
                TagKey.albumArtist: "Original Artist",
                "TRACKTOTAL": "99",
                "DISCTOTAL": "3",
                TagKey.filename: "ignored.flac",
                TagKey.title: "Song"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/edited.flac")
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]

        let exportTrack = try! #require(viewModel.swiftTagDocumentExportTracks().first)
        #expect(exportTrack.tags[TagKey.album] == "Edited Album")
        #expect(exportTrack.tags[TagKey.albumArtist] == "Edited Artist")
        #expect(exportTrack.tags["TOTALTRACKS"] == "12")
        #expect(exportTrack.tags["TOTALDISCS"] == "3")
        #expect(exportTrack.tags["TRACKTOTAL"] == nil)
        #expect(exportTrack.tags[TagKey.filename] == nil)
    }

    @MainActor
    @Test
    func tagEditorViewModelLoadsSwiftTagDocumentAsCleanEditableSession() throws {
        let frontCover = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Cover (front)",
            data: try Self.pngData(color: .systemPink)
        ).withComputedPictureMetadata()
        let destinationURL = try Self.tempPackageURL(name: "view-model-load")
        let saveResult = try SwiftTagDocumentPackageWriter.save(
            tracks: [
                SwiftTagDocumentExportTrack(
                    sortKey: "/tmp/view-model-load.flac",
                    tags: [
                        TagKey.title: "Loaded Track",
                        TagKey.album: "Loaded Album",
                        TagKey.trackNumber: "01",
                        "TOTALTRACKS": "01"
                    ],
                    pictures: [frontCover],
                    sourceFileURL: URL(fileURLWithPath: "/tmp/view-model-load.flac"),
                    securityScopedBookmarkData: nil,
                    flacFingerprint: "loaded-fingerprint"
                )
            ],
            state: .init(),
            to: destinationURL
        )
        let document = try SwiftTagDocumentPackageReader.read(from: destinationURL)
        let viewModel = TagEditorViewModel()

        viewModel.loadSwiftTagDocument(document, tagWriteOptions: Self.defaultTagWriteOptions)

        let loadedTrack = try #require(viewModel.trackItems.first)
        #expect(viewModel.swiftTagDocumentSaveState().destinationURL == destinationURL.standardizedFileURL)
        #expect(viewModel.swiftTagDocumentSaveState().documentID == saveResult.documentID)
        #expect(loadedTrack.tags[TagKey.title] == "Loaded Track")
        #expect(loadedTrack.album == "Loaded Album")
        #expect(loadedTrack.latestFileSnapshot != nil)
        #expect(loadedTrack.preservesEditorStateDuringFileRefresh)
        #expect(!viewModel.canSave(
            payload: .writeTagsAndPictures,
            scope: .allTracks,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        ))
    }

    @MainActor
    @Test
    func tagEditorViewModelTreatsPictureSpecMismatchAsSaveableDifference() throws {
        let pngData = try Self.pngData(color: .systemGreen)
        let currentPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Cover (front)",
            data: pngData
        ).withComputedPictureMetadata()
        let importedPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Cover (front)",
            data: pngData,
            width: 0,
            height: 0,
            depth: 0,
            colors: 0
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: [TagKey.title: "Track"],
                flacPictureRecords: [currentPicture],
                sourceFileURL: URL(fileURLWithPath: "/tmp/mismatch.flac"),
                latestFileSnapshot: TrackFileSnapshot(
                    tags: [TagKey.title: "Track"],
                    picturesByType: [3: pngData],
                    pictureRecords: [importedPicture]
                )
            )
        ]

        #expect(
            viewModel.canSave(
                payload: .writePictures,
                scope: .allTracks,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: []
            )
        )
    }

    @MainActor
    @Test
    func swiftTagDocumentLoadRefreshesLiveTagDifferencesImmediately() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "document-live-diff.flac")
        let baselineViewModel = TagEditorViewModel()
        try await baselineViewModel.importFlacFiles([fileURL])

        let destinationURL = try Self.tempPackageURL(name: "document-live-diff")
        _ = try SwiftTagDocumentPackageWriter.save(
            tracks: try baselineViewModel.validatedSwiftTagDocumentExportTracks(),
            state: .init(),
            to: destinationURL
        )

        try await Self.writeLiveTitle("Document Live Changed", to: fileURL)

        let document = try SwiftTagDocumentPackageReader.read(from: destinationURL)
        let viewModel = TagEditorViewModel()
        viewModel.loadSwiftTagDocument(document, tagWriteOptions: Self.defaultTagWriteOptions)
        viewModel.refreshLoadedTrackFileStates(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let loadedTrack = try #require(viewModel.trackItems.first)
        #expect(loadedTrack.tags[TagKey.title] == "Test Title")
        #expect(loadedTrack.latestFileSnapshot?.tags[TagKey.title] == "Test Title")
        #expect(loadedTrack.externalDifferences?.fileValuesByTag[TagKey.title] == "Document Live Changed")
        #expect(loadedTrack.externalDifferences?.isDeleted == false)

        let presentation = viewModel.trackStatusPresentation(
            for: loadedTrack.id,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        #expect(presentation?.systemImageName == "exclamationmark.triangle")
    }

    @MainActor
    @Test
    func swiftTagDocumentLoadRefreshDoesNotFlagPictureDifferencesWhenLiveFileMatches() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "document-picture-match.flac")
        let baselineViewModel = TagEditorViewModel()
        try await baselineViewModel.importFlacFiles([fileURL])

        let destinationURL = try Self.tempPackageURL(name: "document-picture-match")
        _ = try SwiftTagDocumentPackageWriter.save(
            tracks: try baselineViewModel.validatedSwiftTagDocumentExportTracks(),
            state: .init(),
            to: destinationURL
        )

        let document = try SwiftTagDocumentPackageReader.read(from: destinationURL)
        let viewModel = TagEditorViewModel()
        viewModel.loadSwiftTagDocument(document, tagWriteOptions: Self.defaultTagWriteOptions)
        viewModel.refreshLoadedTrackFileStates(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let loadedTrack = try #require(viewModel.trackItems.first)
        #expect(loadedTrack.externalDifferences == nil)

        let presentation = viewModel.trackStatusPresentation(
            for: loadedTrack.id,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        #expect(presentation?.systemImageName == "fish.fill")
    }

    @MainActor
    @Test
    func swiftTagDocumentNavigationMetadataCountsExternalTagAndPictureDifferences() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "document-navigation-external-diffs.flac")
        let baselineViewModel = TagEditorViewModel()
        try await baselineViewModel.importFlacFiles([fileURL])

        let destinationURL = try Self.tempPackageURL(name: "document-navigation-external-diffs")
        _ = try SwiftTagDocumentPackageWriter.save(
            tracks: try baselineViewModel.validatedSwiftTagDocumentExportTracks(),
            state: .init(),
            to: destinationURL
        )

        let replacementPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Changed",
            data: try Self.pngData(color: .systemBlue)
        )
        try await Self.writeLiveTitle("Externally Changed Title", to: fileURL)
        try Self.writeLivePictures([replacementPicture], to: fileURL)

        let document = try SwiftTagDocumentPackageReader.read(from: destinationURL)
        let viewModel = TagEditorViewModel()
        viewModel.loadSwiftTagDocument(document, tagWriteOptions: Self.defaultTagWriteOptions)
        viewModel.refreshLoadedTrackFileStates(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        #expect(metadata.subtitle == "Tracks: 1 (0) • Tag Δ: 1 (0) • Picture Δ: 1 (0)")
    }

    @MainActor
    @Test
    func swiftTagDocumentLoadRepairsRenamedTrackReferenceWithoutDeletedState() async throws {
        let originalURL = try Self.tempFixtureCopyURL(name: "document-rename-source.flac")
        let sourceViewModel = TagEditorViewModel()
        try await sourceViewModel.importFlacFiles([originalURL])

        let destinationURL = try Self.tempPackageURL(name: "document-rename")
        _ = try SwiftTagDocumentPackageWriter.save(
            tracks: try sourceViewModel.validatedSwiftTagDocumentExportTracks(),
            state: .init(),
            to: destinationURL
        )

        let renamedURL = originalURL.deletingLastPathComponent().appendingPathComponent("document-rename-target.flac")
        try FileManager.default.moveItem(at: originalURL, to: renamedURL)

        let document = try SwiftTagDocumentPackageReader.read(from: destinationURL)
        let viewModel = TagEditorViewModel()
        viewModel.loadSwiftTagDocument(document, tagWriteOptions: Self.defaultTagWriteOptions)
        viewModel.refreshLoadedTrackFileStates(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let loadedTrack = try #require(viewModel.trackItems.first)
        #expect(loadedTrack.sourceFileURL?.path == renamedURL.path)
        #expect(loadedTrack.tags[TagKey.filename] == renamedURL.lastPathComponent)
        #expect(loadedTrack.externalDifferences == nil)
        #expect(!viewModel.hasDeletedFile(for: loadedTrack.id))

        let repairedBookmarkData = try #require(loadedTrack.securityScopedBookmarkData)
        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: repairedBookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        #expect(!isStale)
        #expect(resolvedURL.path == renamedURL.path)
    }

    @MainActor
    @Test
    func swiftTagDocumentLoadFallsBackToSavedFileURLWhenBookmarkCannotResolve() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "document-fallback.flac")
        let metadata = try FlacMetadataService.readTags(for: fileURL)
        let pictureRecords = FlacImportMapper.mapWritablePictureRecords(metadata.pictures)

        let document = SwiftTagDocumentImportResult(
            documentURL: try Self.tempPackageURL(name: "document-fallback-manual"),
            documentID: UUID(),
            fingerprint: UUID().uuidString,
            tracks: [
                SwiftTagDocumentImportTrack(
                    documentTrackFingerprint: UUID().uuidString,
                    sourceFileURL: fileURL,
                    securityScopedBookmarkData: Data([0x00, 0x01, 0x02]),
                    flacFingerprint: metadata.fingerprint,
                    tags: metadata.tags,
                    pictures: pictureRecords
                )
            ]
        )

        let viewModel = TagEditorViewModel()
        viewModel.loadSwiftTagDocument(document, tagWriteOptions: Self.defaultTagWriteOptions)
        viewModel.refreshLoadedTrackFileStates(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let loadedTrack = try #require(viewModel.trackItems.first)
        #expect(loadedTrack.sourceFileURL?.path == fileURL.path)
        #expect(!viewModel.hasDeletedFile(for: loadedTrack.id))
        #expect(loadedTrack.externalDifferences == nil)
        #expect(loadedTrack.securityScopedBookmarkData != Data([0x00, 0x01, 0x02]))
    }

    @MainActor
    @Test
    func validatedSwiftTagDocumentExportTracksRepairsRenamedReferencesBeforeSave() throws {
        let originalURL = try Self.tempFixtureCopyURL(name: "document-export-rename-source.flac")
        let bookmarkData = try originalURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let metadata = try FlacMetadataService.readTags(for: originalURL)
        let renamedURL = originalURL.deletingLastPathComponent().appendingPathComponent("document-export-rename-target.flac")
        try FileManager.default.moveItem(at: originalURL, to: renamedURL)

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: FlacImportMapper.mapTrackTags(
                    sourceTags: metadata.tags,
                    fileURL: originalURL,
                    defaultDate: .now
                ),
                sourceFileURL: originalURL,
                securityScopedBookmarkData: bookmarkData,
                fingerprint: metadata.fingerprint
            )
        ]

        let exportTrack = try #require(viewModel.validatedSwiftTagDocumentExportTracks().first)
        #expect(exportTrack.sourceFileURL?.path == renamedURL.path)
        #expect(viewModel.trackItems.first?.sourceFileURL?.path == renamedURL.path)

        let repairedBookmarkData = try #require(exportTrack.securityScopedBookmarkData)
        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: repairedBookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        #expect(!isStale)
        #expect(resolvedURL.path == renamedURL.path)
    }

    @MainActor
    @Test
    func validatedSwiftTagDocumentExportTracksFailsWhenNoUsableReferenceCanBeProduced() throws {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("flac")
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: [TagKey.title: "Missing Track", TagKey.filename: missingURL.lastPathComponent],
                sourceFileURL: missingURL,
                securityScopedBookmarkData: Data([0xFF])
            )
        ]

        #expect(throws: TagEditorSaveError.self) {
            _ = try viewModel.validatedSwiftTagDocumentExportTracks()
        }
    }

    @MainActor
    @Test
    func swiftTagDocumentLoadedTrackMonitorReflectsExternalChangesAndRestoredRefreshClearsDifferences() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "document-monitor-source.flac")
        let sourceViewModel = TagEditorViewModel()
        try await sourceViewModel.importFlacFiles([fileURL])

        let destinationURL = try Self.tempPackageURL(name: "document-monitor")
        _ = try SwiftTagDocumentPackageWriter.save(
            tracks: try sourceViewModel.validatedSwiftTagDocumentExportTracks(),
            state: .init(),
            to: destinationURL
        )

        let document = try SwiftTagDocumentPackageReader.read(from: destinationURL)
        let viewModel = TagEditorViewModel()
        viewModel.loadSwiftTagDocument(document, tagWriteOptions: Self.defaultTagWriteOptions)
        viewModel.refreshLoadedTrackFileStates(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let trackID = try #require(viewModel.trackItems.first?.id)
        let monitor = TrackFileMonitor()
        defer { monitor.stopAll() }

        @MainActor
        func onChange(_ event: TrackFileMonitorEvent) {
            viewModel.refreshTrackFileState(
                for: event.trackID,
                currentPath: event.currentPath,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: []
            )
            monitor.replaceObservations(for: viewModel.trackItems, onChange: onChange)
        }

        monitor.replaceObservations(for: viewModel.trackItems, onChange: onChange)

        try await Self.writeLiveTitle("Document Monitor Changed", to: fileURL)
        let sawDifference = await Self.waitUntil {
            viewModel.trackItems.first?.externalDifferences?.fileValuesByTag[TagKey.title] == "Document Monitor Changed"
        }
        #expect(sawDifference)

        try await Self.writeLiveTitle("Test Title", to: fileURL)
        viewModel.refreshTrackFileState(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        #expect(viewModel.trackItems.first?.externalDifferences == nil)
        #expect(!viewModel.hasDeletedFile(for: trackID))
    }
}

private extension UInt32 {
    var bigEndianBytes: [UInt8] {
        [
            UInt8((self >> 24) & 0xff),
            UInt8((self >> 16) & 0xff),
            UInt8((self >> 8) & 0xff),
            UInt8(self & 0xff)
        ]
    }
}
