import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PictureDataSpecifications: Equatable, Codable {
    let width: Int
    let height: Int
    let depth: Int
    let colors: Int

    static let zero = PictureDataSpecifications(width: 0, height: 0, depth: 0, colors: 0)
}

enum PictureDataUtilities {
    private static let pngSignature = Data([137, 80, 78, 71, 13, 10, 26, 10])

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func supportedAssetDetails(mimeType: String, data: Data) -> (mimeType: String, fileExtension: String, specifications: PictureDataSpecifications)? {
        guard let type = supportedImageType(mimeType: mimeType, data: data) else {
            return nil
        }

        return (
            mimeType: canonicalMimeType(for: type),
            fileExtension: canonicalFilenameExtension(for: type),
            specifications: computedSpecifications(from: data)
        )
    }

    static func normalizedMimeType(mimeType: String, data: Data) -> String {
        guard let type = supportedImageType(mimeType: mimeType, data: data) else {
            let trimmedMimeType = mimeType.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedMimeType.isEmpty ? "application/octet-stream" : trimmedMimeType
        }

        return canonicalMimeType(for: type)
    }

    static func computedSpecifications(from data: Data) -> PictureDataSpecifications {
        if let pngSpecifications = pngSpecifications(from: data) {
            return pngSpecifications
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return .zero
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? image?.width ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? image?.height ?? 0
        let depth = inferredBitsPerPixel(properties: properties, image: image)

        return PictureDataSpecifications(width: width, height: height, depth: depth, colors: 0)
    }

    private static func pngSpecifications(from data: Data) -> PictureDataSpecifications? {
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

    private static func uint32BigEndian(in data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else {
            return nil
        }

        return data[offset ..< offset + 4].reduce(UInt32(0)) { partialResult, byte in
            (partialResult << 8) | UInt32(byte)
        }
    }

    private static func inferredBitsPerPixel(properties: [CFString: Any]?, image: CGImage?) -> Int {
        let propertyBitsPerComponent = (properties?[kCGImagePropertyDepth] as? NSNumber)?.intValue ?? 0
        let propertyComponentCount = componentCount(for: properties?[kCGImagePropertyColorModel] as? String)
        let propertyHasAlpha = properties?[kCGImagePropertyHasAlpha] as? Bool
        if propertyBitsPerComponent > 0, let propertyComponentCount {
            let totalComponentCount = propertyComponentCount + ((propertyHasAlpha ?? false) ? 1 : 0)
            return propertyBitsPerComponent * max(totalComponentCount, 1)
        }

        let imageBitsPerComponent = image?.bitsPerComponent ?? 0
        if imageBitsPerComponent > 0 {
            let imageComponentCount = image?.colorSpace?.numberOfComponents ?? propertyComponentCount ?? 1
            let totalComponentCount = imageComponentCount + (hasAlphaChannel(image: image, properties: properties) ? 1 : 0)
            return imageBitsPerComponent * max(totalComponentCount, 1)
        }

        return image?.bitsPerPixel ?? 0
    }

    private static func componentCount(for colorModel: String?) -> Int? {
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

    private static func hasAlphaChannel(image: CGImage?, properties: [CFString: Any]?) -> Bool {
        if let image {
            switch image.alphaInfo {
            case .alphaOnly, .first, .last, .premultipliedFirst, .premultipliedLast:
                return true
            case .none, .noneSkipFirst, .noneSkipLast:
                return false
            @unknown default:
                break
            }
        }

        return properties?[kCGImagePropertyHasAlpha] as? Bool ?? false
    }

    private static func pngChannelCount(for colorType: UInt8?) -> Int {
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

    private static func supportedImageType(mimeType: String, data: Data) -> UTType? {
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

    private static func type(forMimeType mimeType: String) -> UTType? {
        let trimmedMimeType = mimeType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMimeType.isEmpty else {
            return nil
        }

        return UTType(mimeType: trimmedMimeType)
    }

    private static func normalizedSupportedType(_ type: UTType) -> UTType? {
        if type.conforms(to: .jpeg) {
            return .jpeg
        }

        if type.conforms(to: .png) {
            return .png
        }

        return nil
    }

    private static func canonicalMimeType(for type: UTType) -> String {
        if type.conforms(to: .jpeg) {
            return "image/jpeg"
        }

        return "image/png"
    }

    private static func canonicalFilenameExtension(for type: UTType) -> String {
        if type.conforms(to: .jpeg) {
            return "jpg"
        }

        return "png"
    }
}
