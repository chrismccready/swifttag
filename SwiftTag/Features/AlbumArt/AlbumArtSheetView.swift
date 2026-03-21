import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AlbumArtSheetView: View {
    let isSaveOperationRunning: Bool
    let isEditingEnabled: Bool
    let showsPictureDifferenceOverlay: Bool
    let saveStatusPresentation: SaveStatusPresentation?
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
        ZStack {
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
                            },
                            isEnabled: isEditingEnabled && !isSaveOperationRunning,
                            showsExternalDifferenceOverlay: showsPictureDifferenceOverlay
                        )
                        .disabled(!isEditingEnabled || isSaveOperationRunning)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("albumArt.sheet.imageWell")
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard isEditingEnabled, !isSaveOperationRunning else {
                                return
                            }
                            onOpenPicker(albumArtSlot)
                        }
                        .contextMenu {
                            let navigationLinkName = albumArtType(for: albumArtSlot)?.navigationLinkName ?? "Album Art"
                            Button("Import \(navigationLinkName)...") {
                                onOpenPicker(albumArtSlot)
                            }
                            .disabled(!isEditingEnabled || isSaveOperationRunning)
                            Button("Export \(navigationLinkName)...") {
                                onPrepareExport(albumArtSlot)
                            }
                            .disabled(!hasImageForSlot(albumArtSlot))
                        }
                        .allowsHitTesting(isEditingEnabled && !isSaveOperationRunning)
                        .help("Click to select or drag and drop album \(albumArtType(for: albumArtSlot)?.navigationLinkName ?? "art") image.")

                        Text(isSaveOperationRunning ? "disabled" : "enabled")
                            .font(.system(size: 1))
                            .foregroundStyle(.clear)
                            .accessibilityIdentifier("albumArt.sheet.imageWell.state")
                    }
                    .padding(22)
                    .navigationTitle(albumArtType(for: albumArtSlot)?.navigationLinkName ?? "Album Art")
                }
            }
            .controlSize(.regular)

            if let saveStatusPresentation, isSaveOperationRunning {
                SaveStatusView(presentation: saveStatusPresentation)
                    .transition(.opacity)
                    .zIndex(1)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("albumArt.sheet.saveStatusView")

                Text("sheet save status visible")
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .accessibilityIdentifier("albumArt.sheet.saveStatusVisible")
            }
        }
        .frame(width: 524, height: 572)
        .accessibilityIdentifier("albumArt.sheet")
        .accessibilityLabel(isSaveOperationRunning ? "imageWellDisabled" : "imageWellEnabled")
        .accessibilityValue(isSaveOperationRunning ? "imageWellDisabled" : "imageWellEnabled")
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
