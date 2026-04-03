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
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return .zero
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? image?.width ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? image?.height ?? 0
        let depth = (properties?[kCGImagePropertyDepth] as? NSNumber)?.intValue ?? image?.bitsPerPixel ?? 0

        return PictureDataSpecifications(width: width, height: height, depth: depth, colors: 0)
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
