import AppKit
import SwiftUI

struct SwiftTagDocumentQuickLookView: View {
    let snapshot: SwiftTagDocumentQuickLookSnapshot
    let fallbackImageData: Data
    let layout: SwiftTagDocumentQuickLookLayout

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(alignment: .leading, spacing: 0) {
                Text(snapshot.album)
                    .font(.system(size: layout.albumFontSize, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let albumArtist = snapshot.albumArtist {
                    metadataText(albumArtist)
                        .padding(.top, layout.metadataLineSpacing)
                }

                if let sharedArtist = snapshot.sharedArtist {
                    metadataText(sharedArtist)
                        .padding(.top, layout.metadataLineSpacing)
                }

                if !snapshot.trackRows.isEmpty {
                    VStack(alignment: .leading, spacing: layout.trackRowSpacing) {
                        ForEach(Array(snapshot.trackRows.enumerated()), id: \.offset) { offset, row in
                            HStack(spacing: 0) {
                                metadataText(row.leadingText)
                                    .applyQuickLookItalic(if: row.isEllipsis)
                                    .frame(maxWidth: .infinity, alignment: .init(horizontal: .leading, vertical: .center))
                                Spacer(minLength: 4)
                                metadataText(row.durationText)
                                    .frame(minWidth: layout.durationColumnMinWidth, alignment: .trailing)
                            }
                            .background(alignment: .center) {
                                RoundedRectangle(cornerRadius: 8, style: .circular)
                                    .fill(offset % 2 == 0 ? Color.primary.opacity(0.08) : Color.clear)
                                    .padding(EdgeInsets(top: -2, leading: -5, bottom: -3, trailing: -5))
                            }
                        }
                    }
                    .padding(.top, layout.trackSectionSpacing)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, layout.topPadding)
            .padding(.bottom, layout.bottomPadding)
            .padding(.horizontal, layout.horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
        .background(Color.black)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let backgroundImage = decodedBackgroundImage {
            Image(nsImage: backgroundImage)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
                .clipped()
                .blur(radius: layout.backgroundBlurRadius)
                .overlay(Color.black.opacity(layout.backgroundOverlayOpacity))
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.18, blue: 0.26),
                    Color(red: 0.04, green: 0.06, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(Color.black.opacity(layout.backgroundOverlayOpacity))
        }
    }

    private func metadataText(_ value: String) -> some View {
        Text(value)
            .font(.system(size: layout.metadataFontSize, weight: .regular))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: layout.textShadowRadius, x: 0, y: 1)
    }

    private var decodedBackgroundImage: NSImage? {
        NSImage(data: backgroundImageData) ?? NSImage(data: fallbackImageData)
    }

    private var backgroundImageData: Data {
        switch snapshot.background {
        case let .documentPicture(data):
            data
        case .fallback:
            fallbackImageData
        }
    }
}

private extension View {
    @ViewBuilder
    func applyQuickLookItalic(if shouldItalicize: Bool) -> some View {
        if shouldItalicize {
            self.italic()
        } else {
            self
        }
    }
}
