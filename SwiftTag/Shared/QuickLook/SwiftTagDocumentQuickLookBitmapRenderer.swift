import CoreGraphics
import Foundation
import SwiftUI

enum SwiftTagDocumentQuickLookBitmapRendererError: LocalizedError {
    case failedToCreateBitmapImage

    var errorDescription: String? {
        switch self {
        case .failedToCreateBitmapImage:
            return "Failed to create a bitmap image for the SwiftTag Quick Look preview."
        }
    }
}

@MainActor
enum SwiftTagDocumentQuickLookBitmapRenderer {
    static func renderCGImage(
        snapshot: SwiftTagDocumentQuickLookSnapshot,
        fallbackImageData: Data,
        layout: SwiftTagDocumentQuickLookLayout
    ) throws -> CGImage {
        let view = SwiftTagDocumentQuickLookView(
            snapshot: snapshot,
            fallbackImageData: fallbackImageData,
            layout: layout
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1

        guard let cgImage = renderer.cgImage else {
            throw SwiftTagDocumentQuickLookBitmapRendererError.failedToCreateBitmapImage
        }

        return cgImage
    }

    static func drawPreview(
        _ image: CGImage,
        in context: CGContext,
        layout: SwiftTagDocumentQuickLookLayout
    ) {
        let bounds = CGRect(origin: .zero, size: layout.canvasSize)
        context.interpolationQuality = .high
        context.draw(image, in: bounds)
    }
}
