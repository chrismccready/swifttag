import Foundation

enum TagNormalization {
    static let explicitTagKeys: Set<String> = [
        TagKey.number,
        TagKey.disc,
        TagKey.genre,
        TagKey.title,
        TagKey.filename,
        TagKey.artist,
        TagKey.composer,
        TagKey.location,
        TagKey.date,
        TagKey.description,
        "ALBUM",
        "ALBUMARTIST",
        "TRACK",
        "TRACKNUMBER",
        "TOTALTRACKS",
        "TRACKTOTAL",
        "DISCNUMBER",
        "TOTALDISCS"
    ]

    static func normalizeTagKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func isExplicitTagKey(_ value: String) -> Bool {
        explicitTagKeys.contains(normalizeTagKey(value))
    }
}
