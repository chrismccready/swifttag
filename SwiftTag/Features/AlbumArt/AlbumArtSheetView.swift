import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AlbumArtSheetView: View {
    let isSaveOperationRunning: Bool
    let isEditingEnabled: Bool
    let saveStatusPresentation: SaveStatusPresentation?
    let albumArtTypes: [AlbumArtType]
    @Binding var navigationPath: [AlbumArtSlot]
    @Binding var isFileImporterPresented: Bool
    @Binding var isFileExporterPresented: Bool
    @Binding var isPictureImportAlertPresented: Bool
    let pictureImportAlertMessage: String
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
    let itemProvidersForSlot: (AlbumArtSlot) -> [NSItemProvider]
    let onCopyPictureForSlot: (AlbumArtSlot) -> Void
    let pictureCountForSlot: (AlbumArtSlot) -> (count: Int, pinCount: Int)
    let infoOverlayStateForSlot: (AlbumArtSlot) -> AlbumArtInfoOverlayState?
    let metadataForSlot: (AlbumArtSlot) -> AlbumArtPictureMetadata?
    let canEditDescriptionForSlot: (AlbumArtSlot) -> Bool
    let descriptionValidationForSlot: (AlbumArtSlot, String) -> FlacPictureDescriptionValidation?
    let onSaveDescriptionForSlot: (AlbumArtSlot, String) -> Void
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
    let hasExternalPictureDifferenceForSlot: (AlbumArtSlot) -> Bool
    let hasInternalPictureDifferenceForSlot: (AlbumArtSlot) -> Bool

    @AppStorage(FeedbackSettingsKey.pictureStatusOverlayColor)
    private var pictureStatusOverlayColorRawValue: String = FeedbackSettingsDefaults.pictureStatusOverlayColor

    @AppStorage(FeedbackSettingsKey.formatOnDuplicatePicture)
    private var formatOnDuplicatePicture: Bool = FeedbackSettingsDefaults.formatOnDuplicatePicture

    @AppStorage(FeedbackSettingsKey.trackToFileDiffColor)
    private var trackToFileDiffColorRawValue: String = FeedbackSettingsDefaults.trackToFileDiffColor

    @AppStorage(FeedbackSettingsKey.externallyModifiedDiffColor)
    private var externallyModifiedDiffColorRawValue: String = FeedbackSettingsDefaults.externallyModifiedDiffColor
    
    @State private var descriptionEditorSlot: AlbumArtSlot?
    @State private var originalPictureDescription: String = ""
    @State private var stagedPictureDescription: String = ""
    @State private var isPictureDescriptionSheetPresented: Bool = false
    @State private var isPictureDescriptionAlertPresented: Bool = false
    @State private var pictureDescriptionAlertMessage: String = ""

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

    private func filteredInfoOverlayMessages(from state: AlbumArtInfoOverlayState?) -> [AlbumArtInfoOverlayMessage] {
        guard let state else {
            return []
        }

        return state.messages.filter { message in
            switch message.messageType {
            case .hasDuplicateInOtherSlot:
                return formatOnDuplicatePicture
            case .hasOutOfScopeReference:
                return true
            }
        }
    }

    private func beginDescriptionEdit(for slot: AlbumArtSlot) {
        guard canEditDescriptionForSlot(slot),
              let metadata = metadataForSlot(slot) else {
            return
        }

        descriptionEditorSlot = slot
        originalPictureDescription = metadata.description
        stagedPictureDescription = metadata.description
        isPictureDescriptionAlertPresented = false
        pictureDescriptionAlertMessage = ""
        isPictureDescriptionSheetPresented = true
    }

    private func dismissDescriptionEdit() {
        isPictureDescriptionSheetPresented = false
        descriptionEditorSlot = nil
    }

    private func saveDescriptionEdit() {
        guard let slot = descriptionEditorSlot,
              let validation = descriptionValidationForSlot(slot, stagedPictureDescription) else {
            return
        }

        guard validation.isValid else {
            pictureDescriptionAlertMessage = """
            The description uses \(validation.proposedDescriptionBytes) UTF-8 bytes, but this \
            picture can save at most \(validation.maximumDescriptionBytes) bytes after reserving \
            the image payload, MIME type, fixed FLAC picture fields, and 256-byte buffer.
            """
            isPictureDescriptionAlertPresented = true
            return
        }

        onSaveDescriptionForSlot(slot, stagedPictureDescription)
        dismissDescriptionEdit()
    }

    private func sidebarAccessibilityIdentifier(for slot: AlbumArtSlot) -> String {
        "albumArt.sheet.slot.\(slot.accessibilityIdentifierComponent)"
    }

    @ViewBuilder
    private var pictureDescriptionSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Picture Description")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Current Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    VStack {
                        Text(originalPictureDescription.isEmpty ? "None" : originalPictureDescription)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
                            .padding(EdgeInsets(top: 5, leading: 6, bottom: 7, trailing: 6))
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .textSelection(.enabled)
                            .accessibilityIdentifier("albumArt.sheet.pictureDescription.original")
                    }
                }
                .frame(height: 56)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("New Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $stagedPictureDescription)
                    .font(.body)
                    .frame(minHeight: 64, maxHeight: 64)
                    .padding(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                    .accessibilityIdentifier("albumArt.sheet.pictureDescription.editor")
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismissDescriptionEdit()
                }
                .accessibilityIdentifier("albumArt.sheet.pictureDescription.cancelButton")
                Button("Done") {
                    saveDescriptionEdit()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("albumArt.sheet.pictureDescription.saveButton")
            }
        }
        .padding(20)
        .frame(width: 460)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("albumArt.sheet.pictureDescription")
        .alert("Description Too Large", isPresented: $isPictureDescriptionAlertPresented) {
            Button("Ok") {}
        } message: {
            Text(pictureDescriptionAlertMessage)
        }
    }

    @ViewBuilder
    private func navigationRow(for albumArtType: AlbumArtType) -> some View {
        let countSummary = pictureCountForSlot(albumArtType.slot)
        let hasCrossTypeDuplicate = hasCrossTypeDuplicateForSlot(albumArtType.slot)
        let hasCrossTypeDuplicateColor = AppColorStorage.color(from: pictureStatusOverlayColorRawValue, fallback: .systemOrange)
        let hasInternalPictureDifference = hasInternalPictureDifferenceForSlot(albumArtType.slot)
        let hasInternalPictureDifferenceColor = AppColorStorage.color(from: trackToFileDiffColorRawValue, fallback: .labelColor)
        let hasExternalPictureDifference = hasExternalPictureDifferenceForSlot(albumArtType.slot)
        let hasExternalPictureDifferenceColor = AppColorStorage.color(from: externallyModifiedDiffColorRawValue, fallback: .systemRed)
        let textForegroundStyle = hasExternalPictureDifference ? AnyShapeStyle(hasExternalPictureDifferenceColor) :
            (hasCrossTypeDuplicate ? AnyShapeStyle(hasCrossTypeDuplicateColor) :
                (hasInternalPictureDifference ? AnyShapeStyle(hasInternalPictureDifferenceColor) :
                    AnyShapeStyle(.primary)))

        HStack(spacing: 0) {
            Text("\(albumArtType.navigationLinkName)")
                .italic(hasCrossTypeDuplicate)
                .fontWeight(hasInternalPictureDifference ? .bold : .regular)
                .foregroundStyle(textForegroundStyle)
            Spacer()
            Text("\(countSummary.count) : \(countSummary.pinCount)")
                .font(.caption)
                .italic(hasCrossTypeDuplicate)
                .fontWeight(hasInternalPictureDifference ? .bold : .regular)
                .foregroundStyle(textForegroundStyle)
                .frame(width: 40, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(sidebarAccessibilityIdentifier(for: albumArtType.slot))
    }

    @ViewBuilder
    private func pictureDetailView(for albumArtSlot: AlbumArtSlot) -> some View {
        let showsPictureDifferenceOverlay = hasExternalPictureDifferenceForSlot(albumArtSlot)
        let slotName = albumArtType(for: albumArtSlot)?.navigationLinkName ?? "Album Art"

        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                AlbumArtWellView(
                    image: imageForSlot(albumArtSlot),
                    dimension: 480,
                    onDropProviders: { providers in
                        onDropForSlot(providers, albumArtSlot)
                    },
                    onCopyProviders: {
                        itemProvidersForSlot(albumArtSlot)
                    },
                    onPasteProviders: { providers in
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
                    Divider()
                    Button("Copy \(navigationLinkName)") {
                        onCopyPictureForSlot(albumArtSlot)
                    }
                    .disabled(!hasImageForSlot(albumArtSlot))
                    Button("Paste \(navigationLinkName)") {
                        _ = onDropForSlot(AlbumArtWellView.pasteProvidersFromPasteboard(), albumArtSlot)
                    }
                    .disabled(!isEditingEnabled || isSaveOperationRunning || AlbumArtWellView.pasteProvidersFromPasteboard().isEmpty)
                    Divider()
                    Button("Edit Description...") {
                        beginDescriptionEdit(for: albumArtSlot)
                    }
                    .disabled(!isEditingEnabled || isSaveOperationRunning || !canEditDescriptionForSlot(albumArtSlot))
                }
                .allowsHitTesting(isEditingEnabled && !isSaveOperationRunning)
                .help("Click to select or drag and drop album \(albumArtType(for: albumArtSlot)?.navigationLinkName ?? "art") image.")

                let infoOverlayState = infoOverlayStateForSlot(albumArtSlot)
                let overlayMessages = filteredInfoOverlayMessages(from: infoOverlayState)
                let shouldShowInfoOverlay = metadataForSlot(albumArtSlot)?.poolItemID == infoOverlayState?.poolItemID
                if shouldShowInfoOverlay, !overlayMessages.isEmpty {
                    Rectangle()
                        .fill(
                            AppColorStorage.color(
                                from: pictureStatusOverlayColorRawValue,
                                fallback: .systemOrange
                            )
                            .opacity(0.25)
                        )
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(overlayMessages.enumerated()), id: \.offset) { _, overlayMessage in
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
                         \(metadata.descriptionText().truncated(limit: 36, position: .middle)) \(metadata.poolItemIDShort) \(metadata.inSlotReferenceCount) \
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
            Text(slotName)
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .accessibilityIdentifier("albumArt.sheet.currentSlot")
            Text(showsPictureDifferenceOverlay ? "external" : "none")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .accessibilityIdentifier("albumArt.sheet.externalDifferenceState")
        }
        .padding(22)
        .navigationTitle(slotName)
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
                        Button("First Picture", systemImage: "backward.end.fill") {
                            onFirstPicture(albumArtSlot)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(!canGoToPreviousPictureForSlot(albumArtSlot))
                        .frame(width: 36)
                        Button("Previous Picture", systemImage: "arrowtriangle.backward.fill") {
                            onPreviousPicture(albumArtSlot)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(!canGoToPreviousPictureForSlot(albumArtSlot))
                        .frame(width: 36)
                        Button("Next Picture", systemImage: "arrowtriangle.forward.fill") {
                            onNextPicture(albumArtSlot)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(!canGoToNextPictureForSlot(albumArtSlot))
                        .frame(width: 36)
                        Button("Last Picture", systemImage: "forward.end.fill") {
                            onLastPicture(albumArtSlot)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(!canGoToNextPictureForSlot(albumArtSlot))
                        .frame(width: 36)
                    }
                    .buttonStyle(.glass)
                    .padding(2)
                }
                .frame(width: 240)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.primary, lineWidth: 1)
                        .opacity(0.08)
                )
                                        
                ControlGroup {
                    Button("Import Picture", systemImage: "plus") {
                        onOpenPicker(albumArtSlot)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!isEditingEnabled || isSaveOperationRunning)
                    .controlSize(.small)
                    
                    Button("Remove Picture", systemImage: "minus") {
                        onRemovePicture(albumArtSlot)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!hasImageForSlot(albumArtSlot))
                    
                    Button("Export Picture", systemImage: "arrow.down") {
                        onPrepareExport(albumArtSlot)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!hasImageForSlot(albumArtSlot))
                }
            }
        }
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
                List {
                    ForEach(albumArtTypes) { albumArtType in
                        NavigationLink(value: albumArtType.slot) {
                            navigationRow(for: albumArtType)
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
                    pictureDetailView(for: albumArtSlot)
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
            allowedContentTypes: [.image],
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
        .sheet(isPresented: $isPictureDescriptionSheetPresented, onDismiss: {
            descriptionEditorSlot = nil
        }) {
            pictureDescriptionSheet
        }
        .alert("Picture Too Large", isPresented: $isPictureImportAlertPresented) {
            Button("Ok") {}
        } message: {
            Text(pictureImportAlertMessage)
        }
    }
}
