import AppKit
import Foundation
import Testing
@testable import SwiftTag

struct SwiftTagQuickLookTests {
    private static func pngData(color: NSColor) throws -> Data {
        let imageSize = NSSize(width: 8, height: 8)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRepresentation.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SwiftTagQuickLookTests", code: 1)
        }

        return pngData
    }

    private static func picture(
        type: Int = 3,
        color: NSColor,
        description: String
    ) throws -> FlacWritablePictureRecord {
        FlacWritablePictureRecord(
            type: type,
            mimeType: "image/png",
            description: description,
            data: try pngData(color: color)
        ).withComputedPictureMetadata()
    }

    private static func tempPackageURL(name: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent(name).appendingPathExtension(SwiftTagDocumentType.fileExtension)
    }

    private static func importTrack(
        title: String,
        album: String = "Album",
        albumArtist: String = "Album Artist",
        artist: String = "Album Artist",
        trackNumber: String? = nil,
        duration: TimeInterval? = nil,
        pictures: [FlacWritablePictureRecord] = []
    ) -> SwiftTagDocumentImportTrack {
        var tags: [String: String] = [
            "TITLE": title,
            "ALBUM": album,
            "ALBUMARTIST": albumArtist,
            "ARTIST": artist,
        ]
        if let trackNumber {
            tags["TRACKNUMBER"] = trackNumber
        }

        return SwiftTagDocumentImportTrack(
            documentTrackFingerprint: UUID().uuidString,
            sourceFileURL: nil,
            securityScopedBookmarkData: nil,
            flacFingerprint: nil,
            duration: duration,
            tags: tags,
            pictures: pictures
        )
    }

    private static func importResult(tracks: [SwiftTagDocumentImportTrack]) -> SwiftTagDocumentImportResult {
        SwiftTagDocumentImportResult(
            documentURL: URL(fileURLWithPath: "/tmp/TestDocument.swifttag"),
            documentID: UUID(),
            fingerprint: UUID().uuidString,
            tracks: tracks
        )
    }

    private static func exportTrack(
        sortKey: String,
        title: String,
        album: String = "Album",
        albumArtist: String = "Album Artist",
        artist: String = "Album Artist",
        trackNumber: String? = nil,
        duration: TimeInterval? = nil,
        pictures: [FlacWritablePictureRecord] = []
    ) -> SwiftTagDocumentExportTrack {
        var tags: [String: String] = [
            "TITLE": title,
            "ALBUM": album,
            "ALBUMARTIST": albumArtist,
            "ARTIST": artist,
        ]
        if let trackNumber {
            tags["TRACKNUMBER"] = trackNumber
        }

        return SwiftTagDocumentExportTrack(
            sortKey: sortKey,
            tags: tags,
            pictures: pictures,
            sourceFileURL: URL(fileURLWithPath: "/tmp/\(sortKey).flac"),
            securityScopedBookmarkData: nil,
            flacFingerprint: nil,
            duration: duration
        )
    }

    private static func layoutWithHeight(_ height: CGFloat) -> SwiftTagDocumentQuickLookLayout {
        SwiftTagDocumentQuickLookLayout(
            canvasSize: CGSize(width: 900, height: height),
            horizontalPadding: 64,
            topPadding: 72,
            bottomPadding: 64,
            albumFontSize: 36,
            metadataFontSize: 24,
            titleLineHeightMultiplier: 1.2,
            bodyLineHeightMultiplier: 1.25,
            metadataLineSpacing: 8,
            trackSectionSpacing: 28,
            trackRowSpacing: 6,
            durationColumnMinWidth: 72,
            backgroundBlurRadius: 28,
            backgroundOverlayOpacity: 0.42,
            textShadowRadius: 4
        )
    }

    private static func bitmapContext(size: CGSize) -> CGContext? {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0,
              height > 0,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    @Test
    func quickLookLayoutDefaultsTo640SquareCanvas() {
        #expect(SwiftTagDocumentQuickLookLayout.default.canvasSize == CGSize(width: 640, height: 640))
    }

    @Test
    func quickLookSnapshotSelectsFirstFrontCoverPictureFromSavedPackage() throws {
        let frontCover = try Self.picture(color: .systemPink, description: "Front Cover")
        let secondCover = try Self.picture(color: .systemGreen, description: "Second Cover")
        let destinationURL = try Self.tempPackageURL(name: "quicklook-front-cover")

        _ = try SwiftTagDocumentPackageWriter.save(
            tracks: [
                Self.exportTrack(sortKey: "b", title: "Second", trackNumber: "02", pictures: [secondCover]),
                Self.exportTrack(sortKey: "a", title: "First", trackNumber: "01", pictures: [frontCover]),
            ],
            state: .init(),
            to: destinationURL
        )
        let document = try SwiftTagDocumentPackageReader.read(from: destinationURL)

        let snapshot = SwiftTagDocumentQuickLookSnapshot.make(from: document)

        #expect(snapshot.background == .documentPicture(frontCover.data))
    }

    @Test
    func quickLookSnapshotFallsBackWhenSavedPackageHasNoFrontCover() throws {
        let backCover = try Self.picture(type: 4, color: .systemBlue, description: "Back Cover")
        let destinationURL = try Self.tempPackageURL(name: "quicklook-no-front-cover")

        _ = try SwiftTagDocumentPackageWriter.save(
            tracks: [
                Self.exportTrack(sortKey: "a", title: "Only", trackNumber: "01", pictures: [backCover]),
            ],
            state: .init(),
            to: destinationURL
        )
        let document = try SwiftTagDocumentPackageReader.read(from: destinationURL)

        let snapshot = SwiftTagDocumentQuickLookSnapshot.make(from: document)

        #expect(snapshot.background == .fallback)
    }

    @Test
    func quickLookSnapshotOmitsAlbumArtistWhenEmptyAndShowsDistinctSharedArtist() {
        let emptyAlbumArtistDocument = Self.importResult(tracks: [
            Self.importTrack(title: "Track One", albumArtist: "", artist: "Shared Artist", trackNumber: "01"),
            Self.importTrack(title: "Track Two", albumArtist: "", artist: "Shared Artist", trackNumber: "02"),
        ])

        let emptyAlbumArtistSnapshot = SwiftTagDocumentQuickLookSnapshot.make(from: emptyAlbumArtistDocument)

        #expect(emptyAlbumArtistSnapshot.albumArtist == nil)
        #expect(emptyAlbumArtistSnapshot.sharedArtist == "Shared Artist")

        let matchingArtistDocument = Self.importResult(tracks: [
            Self.importTrack(title: "Track One", albumArtist: "Same Artist", artist: "Same Artist", trackNumber: "01"),
            Self.importTrack(title: "Track Two", albumArtist: "Same Artist", artist: "Same Artist", trackNumber: "02"),
        ])

        let matchingArtistSnapshot = SwiftTagDocumentQuickLookSnapshot.make(from: matchingArtistDocument)

        #expect(matchingArtistSnapshot.albumArtist == "Same Artist")
        #expect(matchingArtistSnapshot.sharedArtist == nil)
    }

    @Test
    func quickLookSnapshotSortsTrackNumbersAndUsesEllipsisWhenRowsOverflow() {
        let document = Self.importResult(tracks: [
            Self.importTrack(title: "Three", artist: "Different Artist", trackNumber: "03"),
            Self.importTrack(title: "One", artist: "Different Artist", trackNumber: "01"),
            Self.importTrack(title: "Two", artist: "Different Artist", trackNumber: "02"),
            Self.importTrack(title: "Four", artist: "Different Artist", trackNumber: "04"),
        ])

        let snapshot = SwiftTagDocumentQuickLookSnapshot.make(
            from: document,
            layout: Self.layoutWithHeight(386)
        )

        #expect(snapshot.sharedArtist == "Different Artist")
        #expect(snapshot.trackRows.map(\.leadingText) == ["1 One", "2 Two", "..."])
        #expect(snapshot.usesEllipsisRow)
    }

    @Test
    func quickLookSnapshotUsesSavedOrderForInvalidAndDuplicateTrackNumbers() {
        let document = Self.importResult(tracks: [
            Self.importTrack(title: "Alpha", artist: "Guest Artist", trackNumber: "02"),
            Self.importTrack(title: "Beta", artist: "Guest Artist", trackNumber: "02"),
            Self.importTrack(title: "Gamma", artist: "Guest Artist", trackNumber: "x"),
        ])

        let snapshot = SwiftTagDocumentQuickLookSnapshot.make(from: document)

        #expect(snapshot.trackRows.map(\.leadingText) == ["2 Alpha", "2 Beta", "x Gamma"])
    }

    @Test
    func quickLookSnapshotFormatsTrailingDurationsAndLeavesUnknownDurationEmpty() {
        let document = Self.importResult(tracks: [
            Self.importTrack(title: "Minute Track", trackNumber: "01", duration: 65.9),
            Self.importTrack(title: "Hour Track", trackNumber: "02", duration: 3_661.9),
            Self.importTrack(title: "Unknown Track", trackNumber: "03", duration: nil),
        ])

        let snapshot = SwiftTagDocumentQuickLookSnapshot.make(from: document)

        #expect(snapshot.trackRows.map(\.leadingText) == ["1 Minute Track", "2 Hour Track", "3 Unknown Track"])
        #expect(snapshot.trackRows.map(\.durationText) == ["01:05", "01:01:01", ""])
    }

    @Test
    func quickLookViewSourceUsesSpacerBeforeTrailingDurationText() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Shared")
            .appendingPathComponent("QuickLook")
            .appendingPathComponent("SwiftTagDocumentQuickLookView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("Spacer()"))
        #expect(source.contains("metadataText(row.durationText)"))
    }

    @MainActor
    @Test
    func quickLookBitmapRendererProducesDrawableImage() throws {
        let snapshot = SwiftTagDocumentQuickLookSnapshot.make(from: Self.importResult(tracks: [
            Self.importTrack(title: "Rendered Track", artist: "Rendered Artist", trackNumber: "01"),
        ]))
        let fallbackImageData = try Self.pngData(color: .systemOrange)
        let layout = SwiftTagDocumentQuickLookLayout.default

        let image = try SwiftTagDocumentQuickLookBitmapRenderer.renderCGImage(
            snapshot: snapshot,
            fallbackImageData: fallbackImageData,
            layout: layout
        )
        let context = try #require(Self.bitmapContext(size: layout.canvasSize))

        SwiftTagDocumentQuickLookBitmapRenderer.drawPreview(image, in: context, layout: layout)

        #expect(image.width == Int(layout.canvasSize.width))
        #expect(image.height == Int(layout.canvasSize.height))
        let byteCount = context.bytesPerRow * context.height
        let buffer = UnsafeBufferPointer(
            start: context.data?.assumingMemoryBound(to: UInt8.self),
            count: byteCount
        )
        #expect(buffer.contains(where: { $0 != 0 }))
    }
}
