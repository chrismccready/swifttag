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
    let metadataTextForSlot: (AlbumArtSlot) -> String?
    let hasCrossTypeDuplicateForSlot: (AlbumArtSlot) -> Bool
    let pinAlbumPictures: Bool
    let isPinAlbumPicturesDisabled: Bool
    let onSetPinAlbumPictures: (Bool) -> Void
    let trackPictureScope: AlbumArtPictureScope
    let onSetTrackPictureScope: (AlbumArtPictureScope) -> Void
    let scopeLabelText: String
    let typePictureScopeForSlot: (AlbumArtSlot) -> AlbumArtPictureScope
    let onSetTypePictureScope: (AlbumArtSlot, AlbumArtPictureScope) -> Void
    let isPinTrackPictureOn: (AlbumArtSlot) -> Bool
    let onSetPinTrackPicture: (AlbumArtSlot, Bool) -> Void
    let isPinTrackPictureDisabled: (AlbumArtSlot) -> Bool
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

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
                List {
                    ForEach(albumArtTypes) { albumArtType in
                        let countSummary = pictureCountForSlot(albumArtType.slot)
                        NavigationLink(value: albumArtType.slot) {
                            Text("\(albumArtType.navigationLinkName) • \(countSummary.count) • \(countSummary.pinCount)")
                                .italic(hasCrossTypeDuplicateForSlot(albumArtType.slot))
                                .foregroundStyle(
                                    hasCrossTypeDuplicateForSlot(albumArtType.slot)
                                    ? AnyShapeStyle(
                                        AppColorStorage.color(
                                            from: trackDiscTotalMismatchColorRawValue,
                                            fallback: .systemRed
                                        )
                                    )
                                    : AnyShapeStyle(.primary)
                                )
                        }
                    }
                }
                .navigationTitle("Album Art")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Toggle(isOn: Binding(
                            get: { pinAlbumPictures },
                            set: { onSetPinAlbumPictures($0) }
                        )) {
                            Label("Pin Album Pictures", systemImage: "pin.fill")
                        }
                        .toggleStyle(.button)
                        .labelStyle(.iconOnly)
                        .disabled(isPinAlbumPicturesDisabled)
                    }

                    ToolbarItem(placement: .automatic) {
                        Picker("", selection: Binding(
                            get: { trackPictureScope },
                            set: { onSetTrackPictureScope($0) }
                        )) {
                            ForEach(AlbumArtPictureScope.allCases) { scope in
                                Image(systemName: scope.systemImage)
                                    .tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("albumArt.sheet.trackPictureScopePicker")
                    }

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

                        if let metadataText = metadataTextForSlot(albumArtSlot) {
                            Text(metadataText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
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
                            .accessibilityIdentifier("albumArt.sheet.typePictureScopePicker")

                            Text(scopeLabelText)
                                .font(.caption)

                            Button("First Picture", systemImage: "backward.end.fill") {
                                onFirstPicture(albumArtSlot)
                            }
                            .labelStyle(.iconOnly)
                            .disabled(!canGoToPreviousPictureForSlot(albumArtSlot))

                            Button("Previous Picture", systemImage: "arrowtriangle.backward.fill") {
                                onPreviousPicture(albumArtSlot)
                            }
                            .labelStyle(.iconOnly)
                            .disabled(!canGoToPreviousPictureForSlot(albumArtSlot))

                            Button("Next Picture", systemImage: "arrowtriangle.forward.fill") {
                                onNextPicture(albumArtSlot)
                            }
                            .labelStyle(.iconOnly)
                            .disabled(!canGoToNextPictureForSlot(albumArtSlot))

                            Button("Last Picture", systemImage: "forward.end.fill") {
                                onLastPicture(albumArtSlot)
                            }
                            .labelStyle(.iconOnly)
                            .disabled(!canGoToNextPictureForSlot(albumArtSlot))

                            Button("Import Picture", systemImage: "plus") {
                                onOpenPicker(albumArtSlot)
                            }
                            .labelStyle(.iconOnly)
                            .disabled(!isEditingEnabled || isSaveOperationRunning)

                            Button("Remove Picture", systemImage: "minus") {
                                onRemovePicture(albumArtSlot)
                            }
                            .labelStyle(.iconOnly)
                            .disabled(!hasImageForSlot(albumArtSlot) || isPinTrackPictureDisabled(albumArtSlot))

                            Button("Export Picture", systemImage: "arrow.down") {
                                onPrepareExport(albumArtSlot)
                            }
                            .labelStyle(.iconOnly)
                            .disabled(!hasImageForSlot(albumArtSlot))
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
