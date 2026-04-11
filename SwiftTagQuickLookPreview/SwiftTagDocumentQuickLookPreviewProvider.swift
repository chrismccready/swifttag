import Foundation
import QuickLookUI

final class SwiftTagDocumentQuickLookPreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let document = try SwiftTagDocumentPackageReader.read(from: request.fileURL)
        let layout = SwiftTagDocumentQuickLookLayout.default
        let snapshot = SwiftTagDocumentQuickLookSnapshot.make(from: document, layout: layout)
        let fallbackImageData = try SwiftTagQuickLookPreviewResources.fallbackImageData(
            bundle: Bundle(for: Self.self)
        )
        let previewImage = try await MainActor.run {
            try SwiftTagDocumentQuickLookBitmapRenderer.renderCGImage(
                snapshot: snapshot,
                fallbackImageData: fallbackImageData,
                layout: layout
            )
        }
        let title = document.documentURL.deletingPathExtension().lastPathComponent

        let reply = QLPreviewReply(
            contextSize: layout.canvasSize,
            isBitmap: true
        ) { context, updatedReply in
            updatedReply.title = title
            SwiftTagDocumentQuickLookBitmapRenderer.drawPreview(
                previewImage,
                in: context,
                layout: layout
            )
        }
        reply.title = title
        return reply
    }
}

private enum SwiftTagQuickLookPreviewResources {
    static let fallbackImageName = "SwiftTagQuickLookFallback"
    static let fallbackImageExtension = "png"

    static func fallbackImageData(bundle: Bundle) throws -> Data {
        guard let resourceURL = bundle.url(
            forResource: fallbackImageName,
            withExtension: fallbackImageExtension
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }

        return try Data(contentsOf: resourceURL)
    }
}
