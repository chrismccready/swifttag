import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AlbumArtWellView: View {
    let image: Image
    let dimension: CGFloat
    let onDropProviders: ([NSItemProvider]) -> Bool
    var isEnabled: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.secondary, lineWidth: 1)

            image
                .resizable()
                .scaledToFit()
                .padding(4)
        }
        .frame(width: dimension, height: dimension)
        .onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: nil) { providers in
            guard isEnabled else {
                return false
            }
            return onDropProviders(providers)
        }
    }
}
