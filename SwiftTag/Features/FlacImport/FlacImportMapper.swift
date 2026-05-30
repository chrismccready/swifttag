import Foundation

struct FlacImportInitialization {
    let album: String?
    let albumArtist: String?
    let totalTracks: String?
    let totalDiscs: String?
}

enum FlacImportMapper {
    static func initialValues(from tags: [String: String]) -> FlacImportInitialization {
        let albumValue = tags["ALBUM"]?.isEmpty == false ? tags["ALBUM"] : nil
        let albumArtistValue = tags[TagKey.albumArtist]
            .flatMap { $0.isEmpty ? nil : $0 }

        let rawTotalDiscs = tags["TOTALDISCS"] ?? tags["DISCTOTAL"] ?? ""
        let normalizedTotalDiscs = Int(rawTotalDiscs).map(String.init) ?? rawTotalDiscs
        let totalDiscsValue = normalizedTotalDiscs.isEmpty ? nil : normalizedTotalDiscs

        let rawTotalTracks = tags["TOTALTRACKS"] ?? tags["TRACKTOTAL"] ?? ""
        let normalizedTotalTracks = Int(rawTotalTracks).map(String.init) ?? rawTotalTracks
        let totalTracksValue = normalizedTotalTracks.isEmpty ? nil : normalizedTotalTracks

        return FlacImportInitialization(
            album: albumValue,
            albumArtist: albumArtistValue,
            totalTracks: totalTracksValue,
            totalDiscs: totalDiscsValue
        )
    }

    static func mapTrackTags(
        sourceTags: [String: String],
        fileURL: URL,
        defaultDate: Date
    ) -> [String: String] {
        let fileTitle = fileURL.deletingPathExtension().lastPathComponent
        let title = sourceTags[TagKey.title]?.isEmpty == false ? sourceTags[TagKey.title]! : fileTitle

        let description = sourceTags[TagKey.description] ?? sourceTags["COMMENT"] ?? ""
        let location = sourceTags[TagKey.location] ?? sourceTags["VENUE"] ?? ""
        let genre = sourceTags[TagKey.genre] ?? ""

        let rawTrackNumber = sourceTags[TagKey.trackNumber] ?? sourceTags["TRACK"] ?? ""
        let normalizedTrackNumber = Int(rawTrackNumber).map(String.init) ?? rawTrackNumber
        let rawDiscNumber = sourceTags[TagKey.discNumber] ?? sourceTags["DISC"] ?? ""
        let normalizedDiscNumber = Int(rawDiscNumber).map(String.init) ?? rawDiscNumber

        var trackTags = sourceTags
        trackTags[TagKey.trackNumber] = normalizedTrackNumber
        trackTags[TagKey.discNumber] = normalizedDiscNumber
        trackTags[TagKey.genre] = genre
        trackTags[TagKey.title] = title
        trackTags[TagKey.filename] = fileURL.lastPathComponent
        trackTags[TagKey.artist] = sourceTags[TagKey.artist] ?? ""
        trackTags[TagKey.composer] = sourceTags[TagKey.composer] ?? ""
        trackTags[TagKey.location] = location
        trackTags[TagKey.date] = DateTagFormatter.format(DateTagFormatter.parse(sourceTags[TagKey.date]) ?? defaultDate)
        trackTags[TagKey.description] = description

        return trackTags
    }

    static func mapPicturesByType(_ pictures: [FlacPictureRecord]) -> [Int: Data] {
        var picturesByType: [Int: Data] = [:]

        for picture in pictures where !picture.data.isEmpty {
            if picturesByType[picture.type] == nil {
                picturesByType[picture.type] = picture.data
            }
        }

        return picturesByType
    }

    static func mapWritablePictureRecords(
        _ pictures: [FlacPictureRecord],
        normalizeImageMetadata: Bool = false
    ) -> [FlacWritablePictureRecord] {
        pictures.compactMap { picture in
            guard !picture.data.isEmpty else {
                return nil
            }

            let record = FlacWritablePictureRecord(
                type: picture.type,
                mimeType: picture.mimeType,
                description: picture.description,
                data: picture.data,
                width: picture.width,
                height: picture.height,
                depth: picture.depth,
                colors: picture.colors
            )

            return normalizeImageMetadata ? record.withComputedPictureMetadata() : record
        }
    }
}
