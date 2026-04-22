import Foundation

enum TagNormalization {
    static let explicitTagKeys: Set<String> = [
        TagKey.album,
        TagKey.albumArtist,
        TagKey.compilation,
        TagKey.trackNumber,
        TagKey.discNumber,
        TagKey.genre,
        TagKey.title,
        TagKey.filename,
        TagKey.artist,
        TagKey.composer,
        TagKey.location,
        TagKey.date,
        TagKey.description,
        "TRACK",
        "TRACKNUMBER",
        "TOTALTRACKS",
        "TRACKTOTAL",
        "DISCNUMBER",
        "TOTALDISCS"
    ]

    static func normalizeTagKey(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hasInvalidWhitespace(trimmedValue) else {
            return ""
        }

        return trimmedValue.uppercased()
    }

    static func hasInvalidWhitespace(_ value: String) -> Bool {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return false
        }

        return trimmedValue.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
    }

    static func isExplicitTagKey(_ value: String) -> Bool {
        explicitTagKeys.contains(normalizeTagKey(value))
    }
}
