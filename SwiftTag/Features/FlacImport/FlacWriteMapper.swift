import Foundation

enum FlacWriteMapper {
    static func makeTags(
        for track: Track,
        album: String,
        albumArtist: String,
        totalTracks: Int,
        totalDiscs: String,
        options: TagWriteOptions
    ) -> [String: String] {
        var track = track
        track.album = album
        track.albumArtist = albumArtist
        track.totalTracks = String(totalTracks)
        return makeTags(
            for: track,
            totalDiscs: totalDiscs,
            options: options
        )
    }

    static func makeTags(
        for track: Track,
        totalDiscs: String,
        options: TagWriteOptions
    ) -> [String: String] {
        var tags: [String: String] = [:]

        mergeNonEmptyTags(from: track.tags, into: &tags)
        tags.removeValue(forKey: TagKey.filename)
        tags.removeValue(forKey: "TRACK")
        tags.removeValue(forKey: "DISC")
        tags.removeValue(forKey: "TRACKTOTAL")
        tags.removeValue(forKey: "TOTALTRACKS")
        tags.removeValue(forKey: "DISCTOTAL")
        tags.removeValue(forKey: "TOTALDISCS")
        tags.removeValue(forKey: TagKey.compilation)

        tags[TagKey.trackNumber] = paddedNumberString(
            track.tags[TagKey.trackNumber],
            totalCountString: track.totalTracks,
            zeroPad: options.zeroPadTrackNumber
        )

        tags[TagKey.discNumber] = paddedNumberString(
            track.tags[TagKey.discNumber],
            totalCountString: totalDiscs,
            zeroPad: options.zeroPadDiscNumber
        )

        writeSharedValue(track.album, forKey: TagKey.album, into: &tags)
        writeSharedValue(track.albumArtist, forKey: TagKey.albumArtist, into: &tags)
        writeTrackCount(
            track.totalTracks,
            strategy: options.trackCountKeyStrategy,
            zeroPad: options.zeroPadTrackNumber,
            into: &tags
        )
        writeDiscCount(
            totalDiscs,
            strategy: options.discCountKeyStrategy,
            zeroPad: options.zeroPadDiscNumber,
            into: &tags
        )
        writeCompilationTag(track.tags[TagKey.compilation], into: &tags)

        return tags
            .mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.value.isEmpty }
    }

    private static func mergeNonEmptyTags(from source: [String: String], into destination: inout [String: String]) {
        for (key, value) in source {
            let normalizedKey = TagNormalization.normalizeTagKey(key)
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedValue.isEmpty, normalizedKey != TagKey.filename else {
                continue
            }

            destination[normalizedKey] = trimmedValue
        }
    }

    private static func writeSharedValue(_ value: String, forKey key: String, into tags: inout [String: String]) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            tags.removeValue(forKey: key)
            return
        }

        tags[key] = trimmedValue
    }

    private static func writeTrackCount(
        _ totalTracks: String,
        strategy: TrackCountKeyStrategy,
        zeroPad: Bool,
        into tags: inout [String: String]
    ) {
        let trimmedValue = totalTracks.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return
        }

        let totalTracksValue = formattedTotalCountString(trimmedValue, zeroPad: zeroPad)
        switch strategy {
        case .totalTracks:
            tags["TOTALTRACKS"] = totalTracksValue
        case .trackTotal:
            tags["TRACKTOTAL"] = totalTracksValue
        case .both:
            tags["TOTALTRACKS"] = totalTracksValue
            tags["TRACKTOTAL"] = totalTracksValue
        case .none:
            break
        }
    }

    private static func writeDiscCount(
        _ totalDiscs: String,
        strategy: DiscCountKeyStrategy,
        zeroPad: Bool,
        into tags: inout [String: String]
    ) {
        let trimmedValue = totalDiscs.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return
        }

        let normalizedValue = formattedTotalCountString(trimmedValue, zeroPad: zeroPad)
        switch strategy {
        case .totalDiscs:
            tags["TOTALDISCS"] = normalizedValue
        case .discTotal:
            tags["DISCTOTAL"] = normalizedValue
        case .both:
            tags["TOTALDISCS"] = normalizedValue
            tags["DISCTOTAL"] = normalizedValue
        case .none:
            break
        }
    }

    private static func writeCompilationTag(_ rawValue: String?, into tags: inout [String: String]) {
        guard let normalizedValue = CompilationTag.normalizedValue(rawValue) else {
            tags.removeValue(forKey: TagKey.compilation)
            return
        }

        tags[TagKey.compilation] = normalizedValue
    }

    private static func paddedNumberString(_ value: String?, totalCountString: String, zeroPad: Bool) -> String? {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedValue.isEmpty else {
            return nil
        }

        guard zeroPad, let numericValue = Int(trimmedValue), numericValue > 0 else {
            return trimmedValue
        }

        let minimumWidth = max(2, totalCountString.trimmingCharacters(in: .whitespacesAndNewlines).count)
        return String(format: "%0*d", minimumWidth, numericValue)
    }

    private static func formattedTotalCountString(_ value: String, zeroPad: Bool) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard zeroPad, let numericValue = Int(trimmedValue), numericValue > 0 else {
            return Int(trimmedValue).map(String.init) ?? trimmedValue
        }

        let minimumWidth = max(2, trimmedValue.count)
        return String(format: "%0*d", minimumWidth, numericValue)
    }
}
