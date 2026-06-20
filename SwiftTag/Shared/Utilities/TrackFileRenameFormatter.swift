import Foundation

enum TrackFileRenameError: LocalizedError, Equatable {
    case noTracksToRename
    case unknownPlaceholder(String)
    case invalidZeroPaddedPlaceholder(String)
    case emptyFilename(trackName: String)
    case duplicateDestination(String)
    case destinationExists(String)
    case failedToRename(from: String, to: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .noTracksToRename:
            return "There are no loaded FLAC tracks available for rename."
        case let .unknownPlaceholder(placeholder):
            return "Unknown rename placeholder \(placeholder)."
        case let .invalidZeroPaddedPlaceholder(placeholder):
            return "Zero padding is only supported for numeric placeholders. \(placeholder) is not supported."
        case let .emptyFilename(trackName):
            return "Rename format produced an empty filename for \(trackName)."
        case let .duplicateDestination(path):
            return "Multiple tracks would be renamed to \(path). Rename aborted."
        case let .destinationExists(path):
            return "A file already exists at \(path). Rename aborted."
        case let .failedToRename(source, destination, reason):
            return "Failed to rename \(source) to \(destination): \(reason)"
        }
    }
}

struct TrackFileRenameFormatEditResult: Equatable {
    let format: String
    let insertionPointOffset: Int?
}

enum TrackFileRenameFormatter {
    private struct Placeholder {
        let key: String
        let isZeroPadded: Bool

        var normalizedToken: String {
            isZeroPadded ? "zp\(key)" : key
        }
    }

    private enum FormatPart {
        case literal(String)
        case placeholder(rawToken: String, placeholder: Placeholder)
    }

    private static let zeroPaddableKeys: Set<String> = [
        TagKey.trackNumber,
        TagKey.discNumber,
        "TOTALTRACKS",
        "TOTALDISCS",
        "TRACKTOTAL",
        "DISCTOTAL"
    ]

    private static let baseKnownTagKeys: Set<String> = [
        TagKey.album,
        TagKey.albumArtist,
        TagKey.artist,
        TagKey.comment,
        TagKey.compilation,
        TagKey.composer,
        TagKey.date,
        TagKey.description,
        TagKey.discNumber,
        TagKey.filename,
        TagKey.genre,
        TagKey.location,
        TagKey.title,
        TagKey.trackNumber,
        "ALBUMSORT",
        "ALBUMARTISTSORT",
        "ARTISTSORT",
        "COMPOSERSORT",
        "CONDUCTOR",
        "COPYRIGHT",
        "DIRECTOR",
        "DISCTOTAL",
        "ENCODED_BY",
        "ENCODED_USING",
        "ENCODER",
        "ENCODER_OPTIONS",
        "ISRC",
        "LICENSE",
        "LINEAGE",
        "NARRATOR",
        "PERFORMER",
        "PRODUCER",
        "RATING",
        "REPLAYGAIN_ALBUM_GAIN",
        "REPLAYGAIN_ALBUM_PEAK",
        "REPLAYGAIN_TRACK_GAIN",
        "REPLAYGAIN_TRACK_PEAK",
        "SOURCE",
        "TITLESORT",
        "TOTALDISCS",
        "TOTALTRACKS",
        "TRACKTOTAL",
        "VENDOR",
        "VERSION"
    ]

    private static let fuzzyAliases: [String: String] = [
        "albumartist": TagKey.albumArtist,
        "artist": TagKey.artist,
        "comment": TagKey.comment,
        "comments": TagKey.comment,
        "compilation": TagKey.compilation,
        "composer": TagKey.composer,
        "date": TagKey.date,
        "description": TagKey.description,
        "disc": TagKey.discNumber,
        "disccount": "TOTALDISCS",
        "discnumber": TagKey.discNumber,
        "disctotal": "DISCTOTAL",
        "encodedby": "ENCODED_BY",
        "encodedusing": "ENCODED_USING",
        "encodersettings": "ENCODER_OPTIONS",
        "filename": TagKey.filename,
        "genre": TagKey.genre,
        "location": TagKey.location,
        "number": TagKey.trackNumber,
        "releasedate": TagKey.date,
        "sortalbum": "ALBUMSORT",
        "sortalbumartist": "ALBUMARTISTSORT",
        "sortartist": "ARTISTSORT",
        "sortcomposer": "COMPOSERSORT",
        "sorttitle": "TITLESORT",
        "title": TagKey.title,
        "track": TagKey.trackNumber,
        "trackcount": "TOTALTRACKS",
        "trackdescription": TagKey.description,
        "tracknumber": TagKey.trackNumber,
        "tracktotal": "TRACKTOTAL",
        "trackversion": "VERSION",
        "totaldiscs": "TOTALDISCS",
        "totaltracks": "TOTALTRACKS"
    ]

    static func knownTagKeys(from tracks: [Track]) -> Set<String> {
        var knownKeys = baseKnownTagKeys
        for track in tracks {
            for rawKey in track.tags.keys {
                let normalizedKey = TagNormalization.normalizeTagKey(rawKey)
                if !normalizedKey.isEmpty {
                    knownKeys.insert(normalizedKey)
                }
            }
        }
        return knownKeys
    }

    static func normalizedFormat(_ format: String, knownTagKeys: Set<String>) -> String {
        normalizedFormat(
            format,
            knownTagKeys: knownTagKeys,
            insertionPointAfterClosingDelimiterAt: nil
        ).format
    }

    private static func normalizedFormat(
        _ format: String,
        knownTagKeys: Set<String>,
        insertionPointAfterClosingDelimiterAt closingDelimiterOffset: Int?
    ) -> TrackFileRenameFormatEditResult {
        var output = ""
        var insertionPointOffset: Int?
        var index = format.startIndex

        while index < format.endIndex {
            guard format[index] == "|" else {
                output.append(format[index])
                index = format.index(after: index)
                continue
            }

            let tokenStart = format.index(after: index)
            guard let tokenEnd = format[tokenStart...].firstIndex(of: "|") else {
                output.append(contentsOf: format[index...])
                break
            }

            let rawToken = String(format[tokenStart..<tokenEnd])
            let tokenOutput: String
            if let placeholder = try? normalizedPlaceholder(rawToken, knownTagKeys: knownTagKeys) {
                tokenOutput = "|\(placeholder.normalizedToken)|"
            } else {
                tokenOutput = String(format[index...tokenEnd])
            }
            output.append(tokenOutput)

            let tokenEndOffset = format.distance(from: format.startIndex, to: tokenEnd)
            if closingDelimiterOffset == tokenEndOffset {
                insertionPointOffset = output.count
            }
            index = format.index(after: tokenEnd)
        }

        return TrackFileRenameFormatEditResult(
            format: output,
            insertionPointOffset: insertionPointOffset
        )
    }

    static func normalizedFormatAfterTextFieldEdit(
        previousFormat: String,
        newFormat: String,
        knownTagKeys: Set<String>
    ) -> String {
        normalizedFormatTextFieldEdit(
            previousFormat: previousFormat,
            newFormat: newFormat,
            knownTagKeys: knownTagKeys
        ).format
    }

    static func normalizedFormatTextFieldEdit(
        previousFormat: String,
        newFormat: String,
        knownTagKeys: Set<String>
    ) -> TrackFileRenameFormatEditResult {
        guard let closingDelimiterOffset = insertedClosingPlaceholderDelimiterOffset(
            previousFormat: previousFormat,
            newFormat: newFormat
        ) else {
            return TrackFileRenameFormatEditResult(
                format: newFormat,
                insertionPointOffset: nil
            )
        }

        return normalizedFormat(
            newFormat,
            knownTagKeys: knownTagKeys,
            insertionPointAfterClosingDelimiterAt: closingDelimiterOffset
        )
    }

    static func renderedExample(
        for track: Track?,
        totalDiscsValue: String,
        configuration: TrackFileRenameConfiguration,
        knownTagKeys: Set<String>
    ) -> String {
        guard let track else {
            return ""
        }

        do {
            return try renderedFileName(
                for: track,
                totalDiscsValue: totalDiscsValue,
                configuration: configuration,
                knownTagKeys: knownTagKeys
            )
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    static func renderedFileName(
        for track: Track,
        totalDiscsValue: String,
        configuration: TrackFileRenameConfiguration,
        knownTagKeys: Set<String>
    ) throws -> String {
        let stem = try renderedStem(
            for: track,
            totalDiscsValue: totalDiscsValue,
            format: configuration.format,
            knownTagKeys: knownTagKeys
        )
        let sanitizedStem = sanitizedFilenameStem(
            stem,
            invalidReplacement: configuration.invalidReplacementText.replacement,
            spaceReplacement: configuration.spaceReplacement,
            strict: configuration.strict
        )
        guard !sanitizedStem.isEmpty else {
            throw TrackFileRenameError.emptyFilename(trackName: displayName(for: track))
        }

        let fileExtension = track.sourceFileURL?.pathExtension ?? "flac"
        return sanitizedStem + "." + (fileExtension.isEmpty ? "flac" : fileExtension)
    }

    static func renderedStem(
        for track: Track,
        totalDiscsValue: String,
        format: String,
        knownTagKeys: Set<String>
    ) throws -> String {
        let parts = try parsedFormatParts(format, knownTagKeys: knownTagKeys)
        var output = ""

        for part in parts {
            switch part {
            case let .literal(value):
                output.append(value)
            case let .placeholder(_, placeholder):
                let value = placeholderValue(
                    for: placeholder.key,
                    track: track,
                    totalDiscsValue: totalDiscsValue
                )
                output.append(
                    placeholder.isZeroPadded
                        ? zeroPaddedValue(value, key: placeholder.key, track: track, totalDiscsValue: totalDiscsValue)
                        : value
                )
            }
        }

        return output
    }

    static func sanitizedFilenameStem(
        _ value: String,
        invalidReplacement: String,
        spaceReplacement: TrackFileRenameSpaceReplacement,
        strict: Bool
    ) -> String {
        var output = ""
        for scalar in value.unicodeScalars {
            if isInvalidFilenameScalar(scalar, strict: strict) {
                output.append(invalidReplacement)
            } else {
                output.append(String(scalar))
            }
        }

        output = replacingWhitespace(in: output, spaceReplacement: spaceReplacement)

        return output
    }

    private static func parsedFormatParts(
        _ format: String,
        knownTagKeys: Set<String>
    ) throws -> [FormatPart] {
        var parts: [FormatPart] = []
        var literal = ""
        var index = format.startIndex

        while index < format.endIndex {
            guard format[index] == "|" else {
                literal.append(format[index])
                index = format.index(after: index)
                continue
            }

            let tokenStart = format.index(after: index)
            guard let tokenEnd = format[tokenStart...].firstIndex(of: "|") else {
                literal.append(contentsOf: format[index...])
                break
            }

            if !literal.isEmpty {
                parts.append(.literal(literal))
                literal = ""
            }

            let rawToken = String(format[tokenStart..<tokenEnd])
            let placeholder = try normalizedPlaceholder(rawToken, knownTagKeys: knownTagKeys)
            parts.append(.placeholder(rawToken: rawToken, placeholder: placeholder))
            index = format.index(after: tokenEnd)
        }

        if !literal.isEmpty {
            parts.append(.literal(literal))
        }

        return parts
    }

    private static func normalizedPlaceholder(
        _ rawToken: String,
        knownTagKeys: Set<String>
    ) throws -> Placeholder {
        let trimmedToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw TrackFileRenameError.unknownPlaceholder("||")
        }

        let isZeroPadded = trimmedToken.lowercased().hasPrefix("zp")
        let rawKey = isZeroPadded ? String(trimmedToken.dropFirst(2)) : trimmedToken
        guard let key = canonicalTagKey(rawKey, knownTagKeys: knownTagKeys) else {
            throw TrackFileRenameError.unknownPlaceholder("|\(rawToken)|")
        }

        if isZeroPadded, !zeroPaddableKeys.contains(key) {
            throw TrackFileRenameError.invalidZeroPaddedPlaceholder("|\(rawToken)|")
        }

        return Placeholder(key: key, isZeroPadded: isZeroPadded)
    }

    private static func canonicalTagKey(
        _ rawKey: String,
        knownTagKeys: Set<String>
    ) -> String? {
        let compactKey = compactAliasKey(rawKey)
        if let alias = fuzzyAliases[compactKey] {
            return alias
        }

        let normalizedKey = TagNormalization.normalizeTagKey(rawKey)
        if !normalizedKey.isEmpty, knownTagKeys.contains(normalizedKey) {
            return normalizedKey
        }

        var compactKnownKeys: [String: String] = [:]
        for key in knownTagKeys.sorted() where compactKnownKeys[compactAliasKey(key)] == nil {
            compactKnownKeys[compactAliasKey(key)] = key
        }
        if let knownKey = compactKnownKeys[compactKey] {
            return knownKey
        }

        return nil
    }

    private static func compactAliasKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func insertedClosingPlaceholderDelimiterOffset(
        previousFormat: String,
        newFormat: String
    ) -> Int? {
        newFormat
            .difference(from: previousFormat)
            .compactMap { change -> Int? in
                guard case let .insert(offset, character, _) = change,
                      character == "|" else {
                    return nil
                }

                let insertedIndex = newFormat.index(newFormat.startIndex, offsetBy: offset)
                let precedingPipeCount = newFormat[..<insertedIndex].filter { $0 == "|" }.count
                return precedingPipeCount.isMultiple(of: 2) ? nil : offset
            }
            .first
    }

    private static func placeholderValue(
        for key: String,
        track: Track,
        totalDiscsValue: String
    ) -> String {
        switch key {
        case TagKey.album:
            return track.album
        case TagKey.albumArtist:
            return track.albumArtist
        case TagKey.compilation:
            return CompilationTag.normalizedValue(track.tags[TagKey.compilation]) ?? ""
        case TagKey.filename:
            return track.tags[TagKey.filename] ?? track.sourceFileURL?.lastPathComponent ?? ""
        case "TOTALTRACKS", "TRACKTOTAL":
            return track.totalTracks
        case "TOTALDISCS", "DISCTOTAL":
            return totalDiscsValue
        default:
            return tagValue(in: track.tags, for: key)
        }
    }

    private static func tagValue(in tags: [String: String], for key: String) -> String {
        if let value = tags[key] {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let normalizedKey = TagNormalization.normalizeTagKey(key)
        return tags.first { rawKey, _ in
            TagNormalization.normalizeTagKey(rawKey) == normalizedKey
        }?.value.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func zeroPaddedValue(
        _ value: String,
        key: String,
        track: Track,
        totalDiscsValue: String
    ) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let numericValue = Int(trimmedValue), numericValue > 0 else {
            return trimmedValue
        }

        let minimumWidth: Int
        switch key {
        case TagKey.trackNumber:
            minimumWidth = max(2, track.totalTracks.trimmingCharacters(in: .whitespacesAndNewlines).count)
        case TagKey.discNumber:
            minimumWidth = max(2, totalDiscsValue.trimmingCharacters(in: .whitespacesAndNewlines).count)
        default:
            minimumWidth = max(2, trimmedValue.count)
        }

        return String(format: "%0*d", minimumWidth, numericValue)
    }

    private static func isInvalidFilenameScalar(_ scalar: UnicodeScalar, strict: Bool) -> Bool {
        if scalar.value == 0 || scalar == "/" || scalar == ":" {
            return true
        }

        guard strict else {
            return false
        }

        if scalar.value < 0x20 {
            return true
        }

        return scalar == "<" ||
            scalar == ">" ||
            scalar == "\"" ||
            scalar == "\\" ||
            scalar == "|" ||
            scalar == "?" ||
            scalar == "*"
    }

    private static func replacingWhitespace(
        in value: String,
        spaceReplacement: TrackFileRenameSpaceReplacement
    ) -> String {
        guard let replacement = spaceReplacement.replacement else {
            return value
        }

        var output = ""
        for scalar in value.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                output.append(replacement)
            } else {
                output.append(String(scalar))
            }
        }
        return output
    }

    private static func displayName(for track: Track) -> String {
        let title = track.tags[TagKey.title]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !title.isEmpty {
            return title
        }

        let filename = track.displayFileName
        if !filename.isEmpty {
            return filename
        }

        return "track"
    }
}
