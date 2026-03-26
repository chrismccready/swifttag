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
    let pictureCountForSlot: (AlbumArtSlot) -> (count: Int, pinCount: Int)
    let infoOverlayMessagesForSlot: (AlbumArtSlot) -> [AlbumArtInfoOverlayMessage]
    let metadataForSlot: (AlbumArtSlot) -> AlbumArtPictureMetadata?
    let hasCrossTypeDuplicateForSlot: (AlbumArtSlot) -> Bool
    let scopeLabelText: String
    let typePictureScopeForSlot: (AlbumArtSlot) -> AlbumArtPictureScope
    let onSetTypePictureScope: (AlbumArtSlot, AlbumArtPictureScope) -> Void
    let isPinTrackPictureOn: (AlbumArtSlot) -> Bool
    let onSetPinTrackPicture: (AlbumArtSlot, Bool) -> Void
    let isPinTrackPictureDisabled: (AlbumArtSlot) -> Bool
    let isTypePictureScopeDisabled: (AlbumArtSlot) -> Bool
    let canNavigateForSlot: (AlbumArtSlot) -> Bool
    let canGoToPreviousPictureForSlot: (AlbumArtSlot) -> Bool
    let canGoToNextPictureForSlot: (AlbumArtSlot) -> Bool
    let onFirstPicture: (AlbumArtSlot) -> Void
    let onPreviousPicture: (AlbumArtSlot) -> Void
    let onNextPicture: (AlbumArtSlot) -> Void
    let onLastPicture: (AlbumArtSlot) -> Void
    let onRemovePicture: (AlbumArtSlot) -> Void

    @AppStorage(FeedbackSettingsKey.trackDiscTotalMismatchColor)
    private var trackDiscTotalMismatchColorRawValue: String = FeedbackSettingsDefaults.trackDiscTotalMismatchColor

    private func albumArtType(for slot: AlbumArtSlot) -> AlbumArtType? {
        albumArtTypes.first { $0.slot == slot }
    }

    private func metadataText(for metadata: AlbumArtPictureMetadata) -> String {
        let descriptionText = metadata.description.isEmpty ? "None" : metadata.description
        let mimeTypeText = metadata.mimeType.isEmpty ? "unknown" : metadata.mimeType
        let byteCountText = ByteCountFormatter.string(
            fromByteCount: Int64(metadata.byteCount),
            countStyle: .file
        )
        
        return """
            \(descriptionText) \(metadata.poolItemIDShort) \(metadata.inSlotReferenceCount) \(metadata.outOfSlotReferenceCount) \
            \(metadata.pinCount) · \(mimeTypeText) · \(byteCountText) · \(metadata.currentIndex) of \(metadata.totalCount)"
            """
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
                List {
                    ForEach(albumArtTypes) { albumArtType in
                        let countSummary = pictureCountForSlot(albumArtType.slot)
                        let hasCrossTypeDuplicate = hasCrossTypeDuplicateForSlot(albumArtType.slot)
                        let hasCrossTypeDuplicateColor = AppColorStorage.color(from: trackDiscTotalMismatchColorRawValue, fallback: .systemRed)
                        NavigationLink(value: albumArtType.slot) {
                            HStack(spacing: 0) {
                                Text("\(albumArtType.navigationLinkName)")
                                    .italic(hasCrossTypeDuplicate)
                                    .foregroundStyle(
                                        hasCrossTypeDuplicate
                                        ? AnyShapeStyle(hasCrossTypeDuplicateColor)
                                        : AnyShapeStyle(.primary)
                                    )
                                Spacer()
                                Text("\(countSummary.count) : \(countSummary.pinCount)")
                                    .font(.caption)
                                    .italic(hasCrossTypeDuplicate)
                                    .foregroundStyle(
                                        hasCrossTypeDuplicate
                                        ? AnyShapeStyle(hasCrossTypeDuplicateColor)
                                        : AnyShapeStyle(.secondary)
                                    )
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                }
                .navigationTitle("Album Art")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Text(scopeLabelText)
                            .font(.caption)
                    }
                }
                .navigationDestination(for: AlbumArtSlot.self) { albumArtSlot in
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack(alignment: .bottomLeading) {
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

                            let infoOverlayMessages = infoOverlayMessagesForSlot(albumArtSlot)
                            if !infoOverlayMessages.isEmpty {
                                Rectangle()
                                    .fill(
                                        AppColorStorage.color(
                                            from: trackDiscTotalMismatchColorRawValue,
                                            fallback: .systemRed
                                        )
                                        .opacity(0.25)
                                    )
                                    .overlay(alignment: .bottomLeading) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(Array(infoOverlayMessages.enumerated()), id: \.offset) { _, overlayMessage in
                                                Text(overlayMessage.message)
                                                    .font(.caption)
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .padding(10)
                                    }
                                    .allowsHitTesting(false)
                            }
                        }

                        if let metadata = metadataForSlot(albumArtSlot) {
                            HStack(spacing: 0) {
                                Text("""
                                     \(metadata.descriptionText()) \(metadata.poolItemIDShort) \(metadata.inSlotReferenceCount) \
                                     \(metadata.outOfSlotReferenceCount) \(metadata.pinCount) · \(metadata.mimeTypeText()) · \(metadata.byteCountText())
                                     """)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(metadata.currentIndex) of \(metadata.totalCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .padding(.top, 8)
                            .padding(.horizontal, 4)
                        }

                        Text(isSaveOperationRunning ? "disabled" : "enabled")
                            .font(.system(size: 1))
                            .foregroundStyle(.clear)
                            .accessibilityIdentifier("albumArt.sheet.imageWell.state")
                    }
                    .padding(22)
                    .navigationTitle(albumArtType(for: albumArtSlot)?.navigationLinkName ?? "Album Art")
                    .toolbar {
                        ToolbarItemGroup(placement: .automatic) {
                                Toggle(isOn: Binding(
                                    get: { isPinTrackPictureOn(albumArtSlot) },
                                    set: { onSetPinTrackPicture(albumArtSlot, $0) }
                                )) {
                                    Label("Pin Track Pictures", systemImage: "pin.fill")
                                }
                                .toggleStyle(.button)
                                .labelStyle(.iconOnly)
                                .disabled(isPinTrackPictureDisabled(albumArtSlot))
                                .frame(width: 60)
                                
                                Picker("", selection: Binding(
                                    get: { typePictureScopeForSlot(albumArtSlot) },
                                    set: { onSetTypePictureScope(albumArtSlot, $0) }
                                )) {
                                    ForEach(AlbumArtPictureScope.allCases) { scope in
                                        Image(systemName: scope.systemImage)
                                            .tag(scope)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .disabled(isTypePictureScopeDisabled(albumArtSlot))
                                .accessibilityIdentifier("albumArt.sheet.typePictureScopePicker")
                                       
                            HStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    //Divider()
                                    Button("First Picture", systemImage: "backward.end.fill") {
                                        onFirstPicture(albumArtSlot)
                                    }
                                    .labelStyle(.iconOnly)
                                    .disabled(!canGoToPreviousPictureForSlot(albumArtSlot))
                                    .frame(width: 36)
                                    //Divider()
                                    Button("Previous Picture", systemImage: "arrowtriangle.backward.fill") {
                                        onPreviousPicture(albumArtSlot)
                                    }
                                    .labelStyle(.iconOnly)
                                    .disabled(!canGoToPreviousPictureForSlot(albumArtSlot))
                                    .frame(width: 36)
                                    //Divider()
                                    Button("Next Picture", systemImage: "arrowtriangle.forward.fill") {
                                        onNextPicture(albumArtSlot)
                                    }
                                    .labelStyle(.iconOnly)
                                    .disabled(!canGoToNextPictureForSlot(albumArtSlot))
                                    .frame(width: 36)
                                    //Divider()
                                    Button("Last Picture", systemImage: "forward.end.fill") {
                                        onLastPicture(albumArtSlot)
                                    }
                                    .labelStyle(.iconOnly)
                                    .disabled(!canGoToNextPictureForSlot(albumArtSlot))
                                    .frame(width: 36)
                                    //Divider()
                                }
                                .buttonStyle(.glass)
                                .padding(2)
//                                .background(
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .fill(.regularMaterial)
//                                )
                                
                            }
                            .frame(width: 240)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.primary, lineWidth: 1)
                                    .opacity(0.08)
                            )
                                                        
                            ControlGroup {
                                Button("Import Picture", systemImage: "plus") { // plus.app.fill
                                    onOpenPicker(albumArtSlot)
                                }
                                .labelStyle(.iconOnly)
                                .disabled(!isEditingEnabled || isSaveOperationRunning)
                                .controlSize(.small)
                                
                                Button("Remove Picture", systemImage: "minus") { // minus, xmark.app
                                    onRemovePicture(albumArtSlot)
                                }
                                .labelStyle(.iconOnly)
                                .disabled(!hasImageForSlot(albumArtSlot))
                                
                                Button("Export Picture", systemImage: "arrow.down") { // arrow.down.app
                                    onPrepareExport(albumArtSlot)
                                }
                                .labelStyle(.iconOnly)
                                .disabled(!hasImageForSlot(albumArtSlot))
                            }
                        }
                    }
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
        .frame(width: 524, height: 582, alignment: .top)
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
