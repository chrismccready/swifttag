import CoreGraphics
import Foundation

struct SwiftTagDocumentQuickLookLayout: Equatable {
    let canvasSize: CGSize
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let albumFontSize: CGFloat
    let metadataFontSize: CGFloat
    let titleLineHeightMultiplier: CGFloat
    let bodyLineHeightMultiplier: CGFloat
    let metadataLineSpacing: CGFloat
    let trackSectionSpacing: CGFloat
    let trackRowSpacing: CGFloat
    let durationColumnMinWidth: CGFloat
    let backgroundBlurRadius: CGFloat
    let backgroundOverlayOpacity: Double
    let textShadowRadius: CGFloat

    static let `default` = SwiftTagDocumentQuickLookLayout(
        canvasSize: CGSize(width: 640, height: 640),
        horizontalPadding: 46,
        topPadding: 52,
        bottomPadding: 46,
        albumFontSize: 22,
        metadataFontSize: 14,
        titleLineHeightMultiplier: 1.2,
        bodyLineHeightMultiplier: 1.25,
        metadataLineSpacing: 6,
        trackSectionSpacing: 20,
        trackRowSpacing: 4,
        durationColumnMinWidth: 58,
        backgroundBlurRadius: 14,
        backgroundOverlayOpacity: 0.42,
        textShadowRadius: 3
    )

    var titleLineHeight: CGFloat {
        ceil(albumFontSize * titleLineHeightMultiplier)
    }

    var bodyLineHeight: CGFloat {
        ceil(metadataFontSize * bodyLineHeightMultiplier)
    }

    func visibleTrackRowCount(metadataLineCount: Int) -> Int {
        let additionalMetadataCount = max(metadataLineCount - 1, 0)
        let metadataHeight = CGFloat(additionalMetadataCount) * bodyLineHeight
        let metadataSpacingHeight = CGFloat(additionalMetadataCount) * metadataLineSpacing
        let consumedHeight = topPadding + bottomPadding + titleLineHeight + metadataHeight + metadataSpacingHeight + trackSectionSpacing
        let availableTrackHeight = canvasSize.height - consumedHeight
        guard availableTrackHeight > 0 else {
            return 0
        }

        let rowFootprint = bodyLineHeight + trackRowSpacing
        let visibleRows = Int(floor((availableTrackHeight + trackRowSpacing) / rowFootprint))
        return max(visibleRows, 0)
    }
}

struct SwiftTagDocumentQuickLookSnapshot: Equatable {
    enum Background {
        case documentPicture(Data)
        case fallback
    }

    struct TrackRow: Equatable {
        let leadingText: String
        let durationText: String
        let isEllipsis: Bool

        static let ellipsis = TrackRow(leadingText: "...", durationText: "", isEllipsis: true)
    }

    let album: String
    let albumArtist: String?
    let sharedArtist: String?
    let trackRows: [TrackRow]
    let usesEllipsisRow: Bool
    let background: Background

    static func make(
        from document: SwiftTagDocumentImportResult,
        layout: SwiftTagDocumentQuickLookLayout = .default
    ) -> Self {
        let albumArtist = sharedAlbumArtist(in: document.tracks)
        let sharedArtist = sharedArtist(in: document.tracks, albumArtist: albumArtist)
        let metadataLineCount = 1 + (albumArtist == nil ? 0 : 1) + (sharedArtist == nil ? 0 : 1)
        let orderedTrackRows = orderedTrackRows(from: document.tracks)
        let visibleTrackRowCount = orderedTrackRows.isEmpty
            ? 0
            : max(layout.visibleTrackRowCount(metadataLineCount: metadataLineCount), 1)
        let usesEllipsisRow = orderedTrackRows.count > visibleTrackRowCount && visibleTrackRowCount > 0
        let trackRows: [TrackRow]

        if usesEllipsisRow {
            let visiblePrefixCount = max(visibleTrackRowCount - 1, 0)
            trackRows = Array(orderedTrackRows.prefix(visiblePrefixCount)) + [.ellipsis]
        } else {
            trackRows = Array(orderedTrackRows.prefix(visibleTrackRowCount))
        }

        return SwiftTagDocumentQuickLookSnapshot(
            album: preferredAlbum(in: document),
            albumArtist: albumArtist,
            sharedArtist: sharedArtist,
            trackRows: trackRows,
            usesEllipsisRow: usesEllipsisRow,
            background: firstFrontCoverBackground(in: document.tracks)
        )
    }

    private static func preferredAlbum(in document: SwiftTagDocumentImportResult) -> String {
        let normalizedValues = Set(document.tracks.map { normalizedValue($0.tags[QuickLookTagKey.album]) ?? nil } )
        guard let firstValue = (normalizedValues.compactMap { $0 }.first) else {
            return document.documentURL.lastPathComponent
          }
          if normalizedValues.count == 1 {
            return firstValue
          }
          return "Mix"
    }

    private static func sharedAlbumArtist(in tracks: [SwiftTagDocumentImportTrack]) -> String? {
        sharedNonEmptyValue(for: QuickLookTagKey.albumArtist, in: tracks)
            ?? firstNonEmptyValue(for: QuickLookTagKey.albumArtist, in: tracks)
    }

    private static func sharedArtist(
        in tracks: [SwiftTagDocumentImportTrack],
        albumArtist: String?
    ) -> String? {
        guard let sharedArtist = sharedNonEmptyValue(for: QuickLookTagKey.artist, in: tracks) else {
            return nil
        }

        let normalizedAlbumArtist = albumArtist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return sharedArtist == normalizedAlbumArtist ? nil : sharedArtist
    }

    private static func firstFrontCoverBackground(in tracks: [SwiftTagDocumentImportTrack]) -> Background {
        for track in tracks {
            if let pictureData = track.pictures.first(where: { $0.type == 3 })?.data {
                return .documentPicture(pictureData)
            }
        }

        return .fallback
    }

    private static func orderedTrackRows(from tracks: [SwiftTagDocumentImportTrack]) -> [TrackRow] {
        let preparedTracks = tracks.enumerated().map { index, track in
            PreparedTrack(
                manifestIndex: index,
                rawTrackNumber: normalizedValue(track.tags[QuickLookTagKey.trackNumber]),
                title: normalizedValue(track.tags[QuickLookTagKey.title]) ?? "",
                duration: track.duration
            )
        }

        return preparedTracks
            .sorted { lhs, rhs in
                comparePreparedTracks(lhs, rhs)
            }
            .map {
                TrackRow(
                    leadingText: $0.displayLeadingText,
                    durationText: $0.displayDurationText,
                    isEllipsis: false
                )
            }
    }

    private static func comparePreparedTracks(_ lhs: PreparedTrack, _ rhs: PreparedTrack) -> Bool {
        switch (lhs.numericTrackNumber, rhs.numericTrackNumber) {
        case let (lhsValue?, rhsValue?):
            if lhsValue != rhsValue {
                return lhsValue < rhsValue
            }
            return lhs.manifestIndex < rhs.manifestIndex
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.manifestIndex < rhs.manifestIndex
        }
    }

    private static func sharedNonEmptyValue(
        for key: String,
        in tracks: [SwiftTagDocumentImportTrack]
    ) -> String? {
        let normalizedValues = tracks.map { normalizedValue($0.tags[key]) ?? "" }
        guard let firstValue = normalizedValues.first,
              !firstValue.isEmpty,
              normalizedValues.allSatisfy({ $0 == firstValue }) else {
            return nil
        }

        return firstValue
    }

    private static func firstNonEmptyValue(
        for key: String,
        in tracks: [SwiftTagDocumentImportTrack]
    ) -> String? {
        tracks
            .compactMap { normalizedValue($0.tags[key]) }
            .first(where: { !$0.isEmpty })
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

extension SwiftTagDocumentQuickLookSnapshot.Background: Equatable {
    nonisolated static func ==(
        lhs: SwiftTagDocumentQuickLookSnapshot.Background,
        rhs: SwiftTagDocumentQuickLookSnapshot.Background
    ) -> Bool {
        switch (lhs, rhs) {
        case let (.documentPicture(lhsData), .documentPicture(rhsData)):
            lhsData == rhsData
        case (.fallback, .fallback):
            true
        default:
            false
        }
    }
}

private enum QuickLookTagKey {
    static let album = "ALBUM"
    static let albumArtist = "ALBUMARTIST"
    static let artist = "ARTIST"
    static let title = "TITLE"
    static let trackNumber = "TRACKNUMBER"
}

private struct PreparedTrack {
    let manifestIndex: Int
    let rawTrackNumber: String?
    let title: String
    let duration: TimeInterval?

    var numericTrackNumber: Int? {
        guard let rawTrackNumber else {
            return nil
        }

        return Int(rawTrackNumber)
    }

    var displayTrackNumber: String? {
        if let numericTrackNumber {
            return String(numericTrackNumber)
        }

        return rawTrackNumber
    }

    var displayLeadingText: String {
        let components = [displayTrackNumber, title.isEmpty ? nil : title].compactMap { $0 }

        return components.joined(separator: "  ")
    }

    var displayDurationText: String {
        TrackDurationFormatter.string(from: duration)
    }
}
