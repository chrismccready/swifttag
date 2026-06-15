import Darwin
import AppKit
import Foundation
import UniformTypeIdentifiers

enum FlacMetadataServiceError: LocalizedError {
    case bridgeFailed(message: String)

    var errorDescription: String? {
        switch self {
        case let .bridgeFailed(message):
            return message
        }
    }
}

struct FlacMetadataRecord {
    let tags: [String: String]
    let pictures: [FlacPictureRecord]
    let fingerprint: String?
    let duration: TimeInterval?
    let sampleRate: UInt32?
    let totalSamples: UInt64?
    let bitsPerSample: UInt32?
    let channels: UInt32?
}

enum UITestFlacOverrideWriter {
    static func applyOverrides(
        to fileURL: URL,
        albumMode: String?,
        titleOverride: String?,
        pictureProfile: String?
    ) throws {
        let normalizedAlbumMode = albumMode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedTitleOverride = titleOverride?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPictureProfile = pictureProfile?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let shouldEmptyAlbum = normalizedAlbumMode == "empty"
        let shouldRemoveAlbum = normalizedAlbumMode == "remove"
        let shouldOverrideTitle = !(normalizedTitleOverride?.isEmpty ?? true)
        let shouldOverridePictures = !(normalizedPictureProfile?.isEmpty ?? true)
        guard shouldEmptyAlbum || shouldRemoveAlbum || shouldOverrideTitle || shouldOverridePictures else {
            return
        }

        let metadata = try FlacMetadataService.readTags(for: fileURL)
        var tags = metadata.tags
        if shouldRemoveAlbum {
            tags.removeValue(forKey: "ALBUM")
        } else if shouldEmptyAlbum {
            tags["ALBUM"] = ""
        }
        if let normalizedTitleOverride, !normalizedTitleOverride.isEmpty {
            tags["TITLE"] = normalizedTitleOverride
        }

        let pictures = shouldOverridePictures
            ? try pictureRecords(for: normalizedPictureProfile ?? "")
            : []

        _ = try FlacMetadataService.writeMetadata(
            tags: tags,
            pictures: pictures,
            to: fileURL,
            writeTags: shouldEmptyAlbum || shouldRemoveAlbum || shouldOverrideTitle,
            writePictures: shouldOverridePictures
        )
    }

    private static func pictureRecords(for profile: String) throws -> [FlacWritablePictureRecord] {
        switch profile {
        case "single-front-cover":
            return [
                try makeFrontCoverPicture(
                    color: .systemRed,
                    description: "UI Test Single Front Cover"
                )
            ]
        case "double-front-cover-reversed":
            let firstPicture = try makeFrontCoverPicture(
                color: .systemBlue,
                description: "UI Test Regression Front Cover A"
            )
            let secondPicture = try makeFrontCoverPicture(
                color: .systemGreen,
                description: "UI Test Regression Front Cover B"
            )
            return Array(PictureRecordCanonicalizer.canonicalize([firstPicture, secondPicture]).reversed())
        default:
            throw NSError(
                domain: "SwiftTagUITestOverrides",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported UI test picture profile '\(profile)'."]
            )
        }
    }

    private static func makeFrontCoverPicture(
        color: NSColor,
        description: String
    ) throws -> FlacWritablePictureRecord {
        FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: description,
            data: try pngData(color: color)
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
            throw NSError(
                domain: "SwiftTagUITestOverrides",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to generate PNG data for UI test picture overrides."]
            )
        }

        return pngData
    }
}

enum FlacMetadataService {
    @discardableResult
    static func readTags(for fileURL: URL) throws -> FlacMetadataRecord {
        var result = FlacTagResult(pairs: nil, count: 0)
        var pictureResult = FlacPictureResult(pictures: nil, count: 0)
        var streamInfoResult = FlacStreamInfoResult(
            sample_rate: 0,
            total_samples: 0,
            bits_per_sample: 0,
            channels: 0,
            fingerprint: nil
        )
        var errorMessage: UnsafeMutablePointer<CChar>? = nil

        let status: Int32 = fileURL.path.withCString { filePath in
            flac_read_tags(filePath, &result, &errorMessage)
        }

        defer {
            flac_free_tag_result(&result)
            flac_free_picture_result(&pictureResult)
            flac_free_streaminfo_result(&streamInfoResult)
            if let errorMessage {
                flac_free_c_string(errorMessage)
            }
        }

        guard status == 0 else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown FLAC metadata bridge error."
            throw FlacMetadataServiceError.bridgeFailed(message: message)
        }

        let pictureStatus: Int32 = fileURL.path.withCString { filePath in
            flac_read_pictures(filePath, &pictureResult, &errorMessage)
        }

        guard pictureStatus == 0 else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown FLAC picture bridge error."
            throw FlacMetadataServiceError.bridgeFailed(message: message)
        }

        let streamInfoStatus: Int32 = fileURL.path.withCString { filePath in
            flac_read_streaminfo(filePath, &streamInfoResult, &errorMessage)
        }

        guard streamInfoStatus == 0 else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown FLAC stream info bridge error."
            throw FlacMetadataServiceError.bridgeFailed(message: message)
        }

        var tags: [String: String] = [:]
        if let pairs = result.pairs {
            for index in 0 ..< Int(result.count) {
                let pair = pairs.advanced(by: index).pointee
                guard let keyC = pair.key, let valueC = pair.value else {
                    continue
                }

                let key = String(cString: keyC).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let value = String(cString: valueC).trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    tags[key] = value
                }
            }
        }

        var pictures: [FlacPictureRecord] = []
        if let pictureItems = pictureResult.pictures {
            for index in 0 ..< Int(pictureResult.count) {
                let picture = pictureItems.advanced(by: index).pointee
                let mimeType = picture.mime_type.map { String(cString: $0) } ?? ""
                let description = picture.description.map { String(cString: $0) } ?? ""
                let dataLength = Int(picture.data_length)
                guard let dataPointer = picture.data, dataLength > 0 else {
                    continue
                }

                let data = Data(bytes: dataPointer, count: dataLength)
                pictures.append(
                    FlacPictureRecord(
                        type: Int(picture.type),
                        mimeType: mimeType,
                        description: description,
                        width: Int(picture.width),
                        height: Int(picture.height),
                        depth: Int(picture.depth),
                        colors: Int(picture.colors),
                        data: data
                    )
                )
            }
        }

        let fingerprint = streamInfoResult.fingerprint
            .map { String(cString: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
        let sampleRate = positiveValue(streamInfoResult.sample_rate)
        let totalSamples = positiveValue(streamInfoResult.total_samples)
        let bitsPerSample = positiveValue(streamInfoResult.bits_per_sample)
        let channels = positiveValue(streamInfoResult.channels)
        let duration = duration(
            sampleRate: streamInfoResult.sample_rate,
            totalSamples: streamInfoResult.total_samples
        )

        return FlacMetadataRecord(
            tags: tags,
            pictures: pictures,
            fingerprint: fingerprint,
            duration: duration,
            sampleRate: sampleRate,
            totalSamples: totalSamples,
            bitsPerSample: bitsPerSample,
            channels: channels
        )
    }

    @discardableResult
    static func writeMetadata(
        tags: [String: String] = [:],
        pictures: [FlacWritablePictureRecord] = [],
        to fileURL: URL,
        writeTags: Bool,
        writePictures: Bool
    ) throws -> Bool {
        guard writeTags || writePictures else {
            return false
        }

        var errorMessage: UnsafeMutablePointer<CChar>? = nil

        defer {
            if let errorMessage {
                flac_free_c_string(errorMessage)
            }
        }

        let fileManager = FileManager.default
        let tempDirectoryURL = try fileManager.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: fileURL,
            create: true
        )
        let tempURL = tempDirectoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileURL.pathExtension.isEmpty ? "flac" : fileURL.pathExtension)
        defer {
            try? fileManager.removeItem(at: tempDirectoryURL)
        }

        var usedTempRewrite = false
        try withWriteTagPairs(tags) { tagPairs in
            let normalizedPictures = try normalizePicturesForFlacWrite(pictures)
            try withWritePictures(normalizedPictures) { flacPictures in
                var usedTempFile: UInt8 = 0
                let status: Int32 = fileURL.path.withCString { filePath in
                    tempURL.path.withCString { tempFilePath in
                        flac_write_metadata(
                            filePath,
                            tempFilePath,
                            tagPairs.baseAddress,
                            tagPairs.count,
                            flacPictures.baseAddress,
                            flacPictures.count,
                            writeTags ? 1 : 0,
                            writePictures ? 1 : 0,
                            &usedTempFile,
                            &errorMessage
                        )
                    }
                }

                guard status == 0 else {
                    let message = errorMessage.map { String(cString: $0) } ?? "Unknown FLAC metadata write bridge error."
                    throw FlacMetadataServiceError.bridgeFailed(message: message)
                }

                if usedTempFile != 0 {
                    usedTempRewrite = true
                    _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
                }
            }
        }
        return usedTempRewrite
    }

    private static func normalizePicturesForFlacWrite(
        _ pictures: [FlacWritablePictureRecord]
    ) throws -> [FlacWritablePictureRecord] {
        try pictures.map { picture in
            let type = UTType(mimeType: picture.mimeType) ?? UTType(filenameExtension: picture.mimeType)
            if type?.conforms(to: .jpeg) == true || type?.conforms(to: .png) == true {
                return picture
            }

            guard let image = NSImage(data: picture.data),
                  let tiffData = image.tiffRepresentation,
                  let bitmapRepresentation = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapRepresentation.representation(using: .png, properties: [:]) else {
                throw FlacMetadataServiceError.bridgeFailed(
                    message: "Unsupported picture format could not be converted to PNG before FLAC write."
                )
            }

            return FlacWritablePictureRecord(
                type: picture.type,
                mimeType: "image/png",
                description: picture.description,
                data: pngData,
                width: picture.width,
                height: picture.height,
                depth: picture.depth,
                colors: picture.colors
            )
        }
    }

    private static func withWriteTagPairs<T>(
        _ tags: [String: String],
        _ body: (UnsafeBufferPointer<FlacWriteTagPair>) throws -> T
    ) throws -> T {
        let sortedTags = tags
            .map { (TagNormalization.normalizeTagKey($0.key), $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.0.isEmpty && !$0.1.isEmpty }
            .sorted { $0.0 < $1.0 }

        var allocatedPointers: [UnsafeMutablePointer<CChar>?] = []
        let pairs: [FlacWriteTagPair] = sortedTags.map { key, value in
            let keyPointer = strdup(key)
            let valuePointer = strdup(value)
            allocatedPointers.append(keyPointer)
            allocatedPointers.append(valuePointer)
            return FlacWriteTagPair(key: UnsafePointer(keyPointer), value: UnsafePointer(valuePointer))
        }

        defer {
            for pointer in allocatedPointers {
                free(pointer)
            }
        }

        return try pairs.withUnsafeBufferPointer(body)
    }

    private static func withWritePictures<T>(
        _ pictures: [FlacWritablePictureRecord],
        _ body: (UnsafeBufferPointer<FlacWritePicture>) throws -> T
    ) throws -> T {
        var mimeTypePointers: [UnsafeMutablePointer<CChar>?] = []
        var descriptionPointers: [UnsafeMutablePointer<CChar>?] = []
        var dataPointers: [UnsafeMutablePointer<UInt8>?] = []

        let flacPictures: [FlacWritePicture] = pictures.map { picture in
            let mimeTypePointer = strdup(picture.mimeType)
            let descriptionPointer = strdup(picture.description)
            let dataPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: picture.data.count)
            picture.data.copyBytes(to: dataPointer, count: picture.data.count)

            mimeTypePointers.append(mimeTypePointer)
            descriptionPointers.append(descriptionPointer)
            dataPointers.append(dataPointer)

            return FlacWritePicture(
                type: UInt32(picture.type),
                mime_type: UnsafePointer(mimeTypePointer),
                description: UnsafePointer(descriptionPointer),
                width: UInt32(picture.width),
                height: UInt32(picture.height),
                depth: UInt32(picture.depth),
                colors: UInt32(picture.colors),
                data: UnsafePointer(dataPointer),
                data_length: picture.data.count
            )
        }

        defer {
            for pointer in mimeTypePointers {
                free(pointer)
            }
            for pointer in descriptionPointers {
                free(pointer)
            }
            for pointer in dataPointers {
                pointer?.deallocate()
            }
        }

        return try flacPictures.withUnsafeBufferPointer(body)
    }

    private static func duration(
        sampleRate: UInt32,
        totalSamples: UInt64
    ) -> TimeInterval? {
        guard sampleRate > 0, totalSamples > 0 else {
            return nil
        }

        return Double(totalSamples) / Double(sampleRate)
    }

    private static func positiveValue(_ value: UInt32) -> UInt32? {
        value > 0 ? value : nil
    }

    private static func positiveValue(_ value: UInt64) -> UInt64? {
        value > 0 ? value : nil
    }
}
