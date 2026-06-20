import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PictureDataSpecifications: Equatable, Codable {
    let width: Int
    let height: Int
    let depth: Int
    let colors: Int

    nonisolated static let zero = PictureDataSpecifications(width: 0, height: 0, depth: 0, colors: 0)
}

enum PictureDataUtilities {
    nonisolated private static let pngSignature = Data([137, 80, 78, 71, 13, 10, 26, 10])

    nonisolated static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func supportedAssetDetails(mimeType: String, data: Data) -> (mimeType: String, fileExtension: String, specifications: PictureDataSpecifications)? {
        guard let type = supportedImageType(mimeType: mimeType, data: data) else {
            return nil
        }

        return (
            mimeType: canonicalMimeType(for: type),
            fileExtension: canonicalFilenameExtension(for: type),
            specifications: computedSpecifications(from: data)
        )
    }

    nonisolated static func normalizedMimeType(mimeType: String, data: Data) -> String {
        guard let type = supportedImageType(mimeType: mimeType, data: data) else {
            let trimmedMimeType = mimeType.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedMimeType.isEmpty ? "application/octet-stream" : trimmedMimeType
        }

        return canonicalMimeType(for: type)
    }

    nonisolated static func computedSpecifications(from data: Data) -> PictureDataSpecifications {
        if let pngSpecifications = pngSpecifications(from: data) {
            return pngSpecifications
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return .zero
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let sourceType = CGImageSourceGetType(source)
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        let depth = inferredBitsPerPixel(properties: properties, sourceType: sourceType)

        return PictureDataSpecifications(width: width, height: height, depth: depth, colors: 0)
    }

    nonisolated private static func pngSpecifications(from data: Data) -> PictureDataSpecifications? {
        guard data.count >= pngSignature.count,
              data.prefix(pngSignature.count) == pngSignature else {
            return nil
        }

        var cursor = pngSignature.count
        var width: Int?
        var height: Int?
        var bitDepth: Int?
        var colorType: UInt8?
        var paletteEntryCount = 0

        while cursor + 8 <= data.count {
            guard let chunkLength = uint32BigEndian(in: data, at: cursor) else {
                return nil
            }

            let chunkDataStart = cursor + 8
            let chunkDataEnd = chunkDataStart + Int(chunkLength)
            let chunkCRCEnd = chunkDataEnd + 4
            guard chunkCRCEnd <= data.count else {
                return nil
            }

            let chunkTypeData = data[(cursor + 4) ..< chunkDataStart]
            let chunkType = String(data: chunkTypeData, encoding: .ascii)

            switch chunkType {
            case "IHDR":
                guard chunkLength >= 13,
                      let parsedWidth = uint32BigEndian(in: data, at: chunkDataStart),
                      let parsedHeight = uint32BigEndian(in: data, at: chunkDataStart + 4) else {
                    return nil
                }

                width = Int(parsedWidth)
                height = Int(parsedHeight)
                bitDepth = Int(data[chunkDataStart + 8])
                colorType = data[chunkDataStart + 9]
            case "PLTE":
                paletteEntryCount = Int(chunkLength) / 3
            case "IEND":
                cursor = chunkCRCEnd
                break
            default:
                break
            }

            cursor = chunkCRCEnd
        }

        guard let width, let height, let bitDepth else {
            return nil
        }

        let colors = colorType == 3 ? paletteEntryCount : 0
        let depth = bitDepth * pngChannelCount(for: colorType)
        return PictureDataSpecifications(width: width, height: height, depth: depth, colors: colors)
    }

    nonisolated private static func uint32BigEndian(in data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else {
            return nil
        }

        return data[offset ..< offset + 4].reduce(UInt32(0)) { partialResult, byte in
            (partialResult << 8) | UInt32(byte)
        }
    }

    nonisolated private static func inferredBitsPerPixel(properties: [CFString: Any]?, sourceType: CFString?) -> Int {
        let propertyBitsPerComponent = (properties?[kCGImagePropertyDepth] as? NSNumber)?.intValue ?? 0
        guard propertyBitsPerComponent > 0 else {
            return 0
        }

        let propertyComponentCount = componentCount(for: properties?[kCGImagePropertyColorModel] as? String)
            ?? defaultComponentCount(for: sourceType)
        let propertyHasAlpha = properties?[kCGImagePropertyHasAlpha] as? Bool
        let totalComponentCount = (propertyComponentCount ?? 1) + ((propertyHasAlpha ?? false) ? 1 : 0)

        return propertyBitsPerComponent * max(totalComponentCount, 1)
    }

    nonisolated private static func componentCount(for colorModel: String?) -> Int? {
        let rgbColorModel = kCGImagePropertyColorModelRGB as String
        let grayColorModel = kCGImagePropertyColorModelGray as String
        let cmykColorModel = kCGImagePropertyColorModelCMYK as String
        let labColorModel = kCGImagePropertyColorModelLab as String

        switch colorModel {
        case rgbColorModel:
            return 3
        case grayColorModel:
            return 1
        case cmykColorModel:
            return 4
        case labColorModel:
            return 3
        default:
            return nil
        }
    }

    nonisolated private static func defaultComponentCount(for sourceType: CFString?) -> Int? {
        guard let sourceType,
              let type = UTType(sourceType as String) else {
            return nil
        }

        if type.conforms(to: .jpeg) || type.conforms(to: .png) {
            return 3
        }

        return nil
    }

    nonisolated private static func pngChannelCount(for colorType: UInt8?) -> Int {
        switch colorType {
        case 0:
            return 1
        case 2:
            return 3
        case 3:
            return 1
        case 4:
            return 2
        case 6:
            return 4
        default:
            return 1
        }
    }

    nonisolated private static func supportedImageType(mimeType: String, data: Data) -> UTType? {
        if let type = type(forMimeType: mimeType), let normalized = normalizedSupportedType(type) {
            return normalized
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let sourceType = CGImageSourceGetType(source),
              let type = UTType(sourceType as String) else {
            return nil
        }

        return normalizedSupportedType(type)
    }

    nonisolated private static func type(forMimeType mimeType: String) -> UTType? {
        let trimmedMimeType = mimeType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMimeType.isEmpty else {
            return nil
        }

        return UTType(mimeType: trimmedMimeType)
    }

    nonisolated private static func normalizedSupportedType(_ type: UTType) -> UTType? {
        if type.conforms(to: .jpeg) {
            return .jpeg
        }

        if type.conforms(to: .png) {
            return .png
        }

        return nil
    }

    nonisolated private static func canonicalMimeType(for type: UTType) -> String {
        if type.conforms(to: .jpeg) {
            return "image/jpeg"
        }

        return "image/png"
    }

    nonisolated private static func canonicalFilenameExtension(for type: UTType) -> String {
        if type.conforms(to: .jpeg) {
            return "jpg"
        }

        return "png"
    }
}
