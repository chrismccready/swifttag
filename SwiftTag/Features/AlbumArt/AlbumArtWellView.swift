import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AlbumArtWellView: View {
    let image: Image
    let dimension: CGFloat
    var interpolation: Image.Interpolation = .low
    let onDropProviders: ([NSItemProvider]) -> Bool
    var onCopyProviders: (() -> [NSItemProvider])? = nil
    var onPasteProviders: (([NSItemProvider]) -> Bool)? = nil
    var isEnabled: Bool = true
    var showsExternalDifferenceOverlay: Bool = false

    private static let supportedPasteContentTypes: [UTType] = [.image, .fileURL]

    private static func itemProvider(for data: Data, typeIdentifier: String) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: typeIdentifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    static func pasteProvidersFromPasteboard() -> [NSItemProvider] {
        guard let pasteboardItems = NSPasteboard.general.pasteboardItems else {
            return []
        }

        return pasteboardItems.compactMap { item in
            if let fileURLString = item.string(forType: .fileURL),
               let fileURL = URL(string: fileURLString) {
                return NSItemProvider(contentsOf: fileURL)
            }

            for type in item.types {
                let typeIdentifier = type.rawValue
                guard let utType = UTType(typeIdentifier),
                      utType.conforms(to: .image),
                      let data = item.data(forType: type) else {
                    continue
                }

                return itemProvider(for: data, typeIdentifier: typeIdentifier)
            }

            return nil
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.secondary, lineWidth: 1)

            image
                .interpolation(interpolation)
                .resizable()
                .scaledToFit()
                .padding(4)

            if showsExternalDifferenceOverlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.red.opacity(0.22))
            }
        }
        .frame(width: dimension, height: dimension)
        .onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: nil) { providers in
            guard isEnabled else {
                return false
            }
            return onDropProviders(providers)
        }
        .focusable(isEnabled, interactions: .activate)
        .onCopyCommand {
            onCopyProviders?() ?? []
        }
        .onPasteCommand(of: Self.supportedPasteContentTypes) { providers in
            guard isEnabled else {
                return
            }
            _ = onPasteProviders?(providers)
        }
    }
}
