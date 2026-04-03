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
}

struct FlacPictureRecord {
    let type: Int
    let mimeType: String
    let description: String
    let width: Int
    let height: Int
    let depth: Int
    let colors: Int
    let data: Data

    init(
        type: Int,
        mimeType: String,
        description: String,
        width: Int = 0,
        height: Int = 0,
        depth: Int = 0,
        colors: Int = 0,
        data: Data
    ) {
        self.type = type
        self.mimeType = mimeType
        self.description = description
        self.width = width
        self.height = height
        self.depth = depth
        self.colors = colors
        self.data = data
    }
}

struct FlacWritablePictureRecord: Equatable {
    let type: Int
    let mimeType: String
    let description: String
    let data: Data
    let width: Int
    let height: Int
    let depth: Int
    let colors: Int

    init(
        type: Int,
        mimeType: String,
        description: String,
        data: Data,
        width: Int = 0,
        height: Int = 0,
        depth: Int = 0,
        colors: Int = 0
    ) {
        self.type = type
        self.mimeType = mimeType
        self.description = description
        self.data = data
        self.width = width
        self.height = height
        self.depth = depth
        self.colors = colors
    }
}

extension FlacWritablePictureRecord {
    func withComputedPictureMetadata() -> FlacWritablePictureRecord {
        let specifications = PictureDataUtilities.computedSpecifications(from: data)
        return FlacWritablePictureRecord(
            type: type,
            mimeType: PictureDataUtilities.normalizedMimeType(mimeType: mimeType, data: data),
            description: description,
            data: data,
            width: specifications.width,
            height: specifications.height,
            depth: specifications.depth,
            colors: specifications.colors
        )
    }
}

enum FlacMetadataService {
    @discardableResult
    static func readTags(for fileURL: URL) throws -> FlacMetadataRecord {
        var result = FlacTagResult(pairs: nil, count: 0)
        var pictureResult = FlacPictureResult(pictures: nil, count: 0)
        var fingerprintPointer: UnsafeMutablePointer<CChar>? = nil
        var errorMessage: UnsafeMutablePointer<CChar>? = nil

        let status: Int32 = fileURL.path.withCString { filePath in
            flac_read_tags(filePath, &result, &errorMessage)
        }

        defer {
            flac_free_tag_result(&result)
            flac_free_picture_result(&pictureResult)
            if let fingerprintPointer {
                flac_free_c_string(fingerprintPointer)
            }
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

        let fingerprintStatus: Int32 = fileURL.path.withCString { filePath in
            flac_read_fingerprint(filePath, &fingerprintPointer, &errorMessage)
        }

        guard fingerprintStatus == 0 else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown FLAC fingerprint bridge error."
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

        let fingerprint = fingerprintPointer
            .map { String(cString: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }

        return FlacMetadataRecord(tags: tags, pictures: pictures, fingerprint: fingerprint)
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
        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileURL.pathExtension.isEmpty ? "flac" : fileURL.pathExtension)

        do {
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
            try? fileManager.removeItem(at: tempURL)
            return usedTempRewrite
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw error
        }
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
}
