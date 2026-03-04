import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AlbumArtSheetView: View {
    let albumArtTypes: [AlbumArtType]
    @Binding var navigationPath: [AlbumArtSlot]
    @Binding var isFileImporterPresented: Bool
    @Binding var isFileExporterPresented: Bool
    let exportDocument: AlbumArtExportDocument?
    let exportContentType: UTType
    let exportDefaultFileName: String

    let imageForSlot: (AlbumArtSlot) -> Image
    let hasImageForSlot: (AlbumArtSlot) -> Bool
    let onOpenPicker: (AlbumArtSlot) -> Void
    let onPrepareExport: (AlbumArtSlot) -> Void
    let onDropForSlot: ([NSItemProvider], AlbumArtSlot) -> Bool
    let onFileImportResult: (Result<[URL], Error>) -> Void
    let onFileExportResult: (Result<URL, Error>) -> Void

    private func albumArtType(for slot: AlbumArtSlot) -> AlbumArtType? {
        albumArtTypes.first { $0.slot == slot }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(albumArtTypes) { albumArtType in
                    NavigationLink(albumArtType.navigationLinkName, value: albumArtType.slot)
                }
            }
            .navigationTitle("Album Art")
            .navigationDestination(for: AlbumArtSlot.self) { albumArtSlot in
                VStack(alignment: .leading, spacing: 0) {
                    AlbumArtWellView(
                        image: imageForSlot(albumArtSlot),
                        dimension: 480,
                        onDropProviders: { providers in
                            onDropForSlot(providers, albumArtSlot)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onOpenPicker(albumArtSlot)
                    }
                    .contextMenu {
                        let navigationLinkName = albumArtType(for: albumArtSlot)?.navigationLinkName ?? "Album Art"
                        Button("Import \(navigationLinkName)...") {
                            onOpenPicker(albumArtSlot)
                        }
                        Button("Export \(navigationLinkName)...") {
                            onPrepareExport(albumArtSlot)
                        }
                        .disabled(!hasImageForSlot(albumArtSlot))
                    }
                    .help("Click to select or drag and drop album \(albumArtType(for: albumArtSlot)?.navigationLinkName ?? "art") image.")
                }
                .padding(22)
                .navigationTitle(albumArtType(for: albumArtSlot)?.navigationLinkName ?? "Album Art")
            }
        }
        .frame(width: 524, height: 572)
        .accessibilityIdentifier("albumArt.sheet")
        .onAppear {
            if navigationPath.isEmpty {
                navigationPath = [.frontCover]
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.jpeg, .png],
            allowsMultipleSelection: false,
            onCompletion: onFileImportResult
        )
        .fileExporter(
            isPresented: $isFileExporterPresented,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportDefaultFileName,
            onCompletion: onFileExportResult
        )
    }
}
