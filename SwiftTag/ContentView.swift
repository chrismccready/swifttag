//
//  ContentView.swift
//  SwiftTag
//
//  Created by Christopher McCready on 2/24/26.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct ContentView: View {
    private let albumArtTypes: [AlbumArtType] = [
        AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
        AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover),
        AlbumArtType(flacPictureType: 5, flacDescription: "Leaflet page", navigationLinkName: "Leaflet", slot: .leaflet),
        AlbumArtType(flacPictureType: 6, flacDescription: "Media", navigationLinkName: "Media", slot: .media),
        AlbumArtType(flacPictureType: 7, flacDescription: "Lead artist/lead performer/soloist", navigationLinkName: "Lead Artist", slot: .leadArtist),
        AlbumArtType(flacPictureType: 8, flacDescription: "Artist/performer", navigationLinkName: "Artist", slot: .artist),
        AlbumArtType(flacPictureType: 9, flacDescription: "Conductor", navigationLinkName: "Conductor", slot: .conductor),
        AlbumArtType(flacPictureType: 10, flacDescription: "Band/Orchestra", navigationLinkName: "Band", slot: .band),
        AlbumArtType(flacPictureType: 11, flacDescription: "Composer", navigationLinkName: "Composer", slot: .composer),
        AlbumArtType(flacPictureType: 12, flacDescription: "Lyricist/text writer", navigationLinkName: "Lyricist", slot: .lyricist),
        AlbumArtType(flacPictureType: 13, flacDescription: "Recording location", navigationLinkName: "Recording Studio or Location", slot: .recordingStudioOrLocation),
        AlbumArtType(flacPictureType: 14, flacDescription: "During recording", navigationLinkName: "Recording Session", slot: .recordingSession),
        AlbumArtType(flacPictureType: 15, flacDescription: "During performance", navigationLinkName: "Performance", slot: .performance),
        AlbumArtType(flacPictureType: 16, flacDescription: "Movie/video capture", navigationLinkName: "Capture from Movie or Video", slot: .captureFromMovieOrVideo),
        AlbumArtType(flacPictureType: 17, flacDescription: "Bright coloured fish", navigationLinkName: "Bright(ly) Colored Fish", slot: .brightlyColoredFish),
        AlbumArtType(flacPictureType: 18, flacDescription: "Illustration", navigationLinkName: "Illustration", slot: .illustration),
        AlbumArtType(flacPictureType: 19, flacDescription: "Band/artist logotype", navigationLinkName: "Band Logo", slot: .bandLogo),
        AlbumArtType(flacPictureType: 20, flacDescription: "Publisher/studio logotype", navigationLinkName: "Publisher Logo", slot: .publisherLogo),
        AlbumArtType(flacPictureType: 1, flacDescription: "32x32 pixels file icon (PNG only)", navigationLinkName: "32x32 PNG Icon", slot: .pngIcon),
        AlbumArtType(flacPictureType: 2, flacDescription: "Other file icon", navigationLinkName: "Other Icon", slot: .otherIcon),
        AlbumArtType(flacPictureType: 0, flacDescription: "Other", navigationLinkName: "Other", slot: .other)
    ]

    @State private var isTomlSheetPresented: Bool = false
    @State private var isFlacImporterPresented: Bool = false
    @State private var isImportErrorPresented: Bool = false
    @State private var isAlbumArtSheetPresented: Bool = false
    @State private var importErrorMessage: String = ""
    @State private var viewModel: TagEditorViewModel = .init()
    @State private var albumArtViewModel: AlbumArtViewModel = .init()
    @State private var hasPerformedInitialUITestSetup: Bool = false
    @FocusState private var focusedMiscTagKeyRowID: MiscTagRow.ID?

    private var album: String {
        get { viewModel.album }
        set { viewModel.album = newValue }
    }

    private var albumArtist: String {
        get { viewModel.albumArtist }
        set { viewModel.albumArtist = newValue }
    }

    private var totalDiscs: String {
        get { viewModel.totalDiscs }
        set { viewModel.totalDiscs = newValue }
    }

    private var selectedTrackIDs: Set<UUID> {
        get { viewModel.selectedTrackIDs }
        set { viewModel.selectedTrackIDs = newValue }
    }

    private var miscTagRows: [MiscTagRow] {
        get { viewModel.miscTagRows }
        set { viewModel.miscTagRows = newValue }
    }

    private var selectedMiscTagRowIDs: Set<MiscTagRow.ID> {
        get { viewModel.selectedMiscTagRowIDs }
        set { viewModel.selectedMiscTagRowIDs = newValue }
    }

    private var trackItems: [Track] {
        get { viewModel.trackItems }
        set { viewModel.trackItems = newValue }
    }

    private var albumBinding: Binding<String> {
        Binding(
            get: { viewModel.album },
            set: { viewModel.album = $0 }
        )
    }

    private var albumArtistBinding: Binding<String> {
        Binding(
            get: { viewModel.albumArtist },
            set: { viewModel.albumArtist = $0 }
        )
    }

    private var totalDiscsBinding: Binding<String> {
        Binding(
            get: { viewModel.totalDiscs },
            set: { viewModel.totalDiscs = $0 }
        )
    }

    private var selectedTrackIDsBinding: Binding<Set<UUID>> {
        Binding(
            get: { viewModel.selectedTrackIDs },
            set: { viewModel.selectedTrackIDs = $0 }
        )
    }

    private var miscTagRowsBinding: Binding<[MiscTagRow]> {
        Binding(
            get: { viewModel.miscTagRows },
            set: { viewModel.miscTagRows = $0 }
        )
    }

    private var selectedMiscTagRowIDsBinding: Binding<Set<MiscTagRow.ID>> {
        Binding(
            get: { viewModel.selectedMiscTagRowIDs },
            set: { viewModel.selectedMiscTagRowIDs = $0 }
        )
    }


    private func titleBinding(for trackID: UUID) -> Binding<String>? {
        viewModel.titleBinding(for: trackID)
    }

    private func tagBinding(for trackID: UUID, tagName: String) -> Binding<String>? {
        viewModel.tagBinding(for: trackID, tagName: tagName)
    }

    private func selectedTagBinding(tagName: String) -> Binding<String>? {
        viewModel.selectedTagBinding(tagName: tagName)
    }

    private var selectedDateBinding: Binding<Date>? {
        viewModel.selectedDateBinding()
    }

    private var selectedArtistBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.artist)
    }

    private var selectedComposerBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.composer)
    }

    private var selectedLocationBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.location)
    }

    private var selectedDescriptionsBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.description)
    }

    private var selectedNumberBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.number)
    }

    private var selectedDiscBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.disc)
    }

    private var selectedGenreBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.genre)
    }

    private var totalTracks: String {
        viewModel.totalTracks
    }

    private var hasTotalTracksMismatch: Bool {
        viewModel.hasTotalTracksMismatch
    }

    private var totalTracksHoverMessage: String {
        viewModel.totalTracksHoverMessage
    }

    private var hasTotalDiscsMismatch: Bool {
        viewModel.hasTotalDiscsMismatch
    }

    private var totalDiscsHoverMessage: String {
        viewModel.totalDiscsHoverMessage
    }

    private func reloadMiscTagRowsFromSelection() {
        viewModel.reloadMiscTagRowsFromSelection()
    }

    private func addMiscTagRow() {
        let newRowID = viewModel.addMiscTagRow()
        DispatchQueue.main.async {
            focusedMiscTagKeyRowID = newRowID
        }
    }

    private func deleteSelectedMiscTagRows() {
        viewModel.deleteSelectedMiscTagRows()
    }

    private func miscTagKeyBinding(for rowID: MiscTagRow.ID) -> Binding<String>? {
        viewModel.miscTagKeyBinding(for: rowID)
    }

    private func isInvalidMiscTagKeyInput(_ rawKey: String, for rowID: MiscTagRow.ID) -> Bool {
        viewModel.isInvalidMiscTagKeyInput(rawKey, for: rowID)
    }

    private func recordOriginalMiscTagKeyIfNeeded(for rowID: MiscTagRow.ID) {
        viewModel.recordOriginalMiscTagKeyIfNeeded(for: rowID)
    }

    private func finalizeMiscTagKeyEditing(for rowID: MiscTagRow.ID) {
        viewModel.finalizeMiscTagKeyEditing(for: rowID)
    }

    private func miscTagValueBinding(for rowID: MiscTagRow.ID) -> Binding<String>? {
        viewModel.miscTagValueBinding(for: rowID)
    }

    private func positiveIntegerStringBinding(_ source: Binding<String>) -> Binding<String> {
        viewModel.positiveIntegerStringBinding(source)
    }

    private func tomlText() -> String {
        viewModel.tomlText()
    }

    private func handleFlacImportResult(_ result: Result<[URL], Error>) {
        guard case .success(let selectedURLs) = result else {
            return
        }

        Task {
            let scopedURLs = selectedURLs.filter { $0.startAccessingSecurityScopedResource() }
            defer {
                for scopedURL in scopedURLs {
                    scopedURL.stopAccessingSecurityScopedResource()
                }
            }

            let flacFiles = collectFlacFiles(from: selectedURLs)
            do {
                try await importFlacFiles(flacFiles)
            } catch {
                importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isImportErrorPresented = true
            }
        }
    }

    private func collectFlacFiles(from selectedURLs: [URL]) -> [URL] {
        var flacFiles: [URL] = []
        let fileManager = FileManager.default

        for selectedURL in selectedURLs {
            if selectedURL.pathExtension.lowercased() == "flac" {
                flacFiles.append(selectedURL)
                continue
            }

            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: selectedURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                if let enumerator = fileManager.enumerator(at: selectedURL,
                                                           includingPropertiesForKeys: [.isRegularFileKey],
                                                           options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        if fileURL.pathExtension.lowercased() == "flac" {
                            flacFiles.append(fileURL)
                        }
                    }
                }
            }
        }

        let uniqueFiles = Array(Set(flacFiles.map(\.path))).map(URL.init(fileURLWithPath:))
        return uniqueFiles.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    private func importFlacFiles(_ flacFiles: [URL]) async throws {
        try await viewModel.importFlacFiles(flacFiles)
        albumArtViewModel.applyImportedFlacPictures(
            viewModel.importedFlacPicturesByType,
            albumArtTypes: albumArtTypes
        )
    }

    private func loadUITestStateIfNeeded() {
        guard !hasPerformedInitialUITestSetup else {
            return
        }

        hasPerformedInitialUITestSetup = true
        let environment = ProcessInfo.processInfo.environment
        if environment["UITEST_OPEN_ALBUM_ART_SHEET"] == "1" {
            isAlbumArtSheetPresented = true
        }

        guard let fixturePath = environment["UITEST_FLAC_PATH"], !fixturePath.isEmpty else {
            return
        }

        Task {
            do {
                try await importFlacFiles([URL(fileURLWithPath: fixturePath)])
            } catch {
                importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isImportErrorPresented = true
            }
        }
    }

    var body: some View {
        TagEditorView(
            albumBinding: albumBinding,
            albumArtistBinding: albumArtistBinding,
            frontCoverImage: albumArtViewModel.imageForAlbumArtSlot(.frontCover),
            onFrontCoverDrop: { providers in
                albumArtViewModel.handleAlbumArtDrop(providers, for: .frontCover)
            },
            onFrontCoverTap: {
                isAlbumArtSheetPresented = true
            },
            trackItems: trackItems,
            selectedTrackIDsBinding: selectedTrackIDsBinding,
            titleBindingForTrack: titleBinding(for:),
            totalTracks: totalTracks,
            hasTotalTracksMismatch: hasTotalTracksMismatch,
            totalTracksHoverMessage: totalTracksHoverMessage,
            totalDiscsBinding: totalDiscsBinding,
            hasTotalDiscsMismatch: hasTotalDiscsMismatch,
            totalDiscsHoverMessage: totalDiscsHoverMessage,
            selectedNumberBinding: selectedNumberBinding,
            selectedDiscBinding: selectedDiscBinding,
            selectedGenreBinding: selectedGenreBinding,
            selectedArtistBinding: selectedArtistBinding,
            selectedComposerBinding: selectedComposerBinding,
            selectedLocationBinding: selectedLocationBinding,
            selectedDateBinding: selectedDateBinding,
            selectedDescriptionsBinding: selectedDescriptionsBinding,
            positiveIntegerTransform: positiveIntegerStringBinding(_:),
            miscTagRowsBinding: miscTagRowsBinding,
            selectedMiscTagRowIDsBinding: selectedMiscTagRowIDsBinding,
            focusedMiscTagKeyRowIDBinding: $focusedMiscTagKeyRowID,
            onAddMiscTagRow: addMiscTagRow,
            onDeleteSelectedMiscTagRows: deleteSelectedMiscTagRows,
            miscTagKeyBinding: miscTagKeyBinding(for:),
            miscTagValueBinding: miscTagValueBinding(for:),
            isInvalidMiscTagKeyInput: isInvalidMiscTagKeyInput(_:for:)
        )
        .padding()
        .frame(minWidth: 520, minHeight: 530, idealHeight: 640, alignment: .topLeading)
        .onAppear {
            reloadMiscTagRowsFromSelection()
            loadUITestStateIfNeeded()
        }
        .onChange(of: selectedTrackIDs) { _, _ in
            reloadMiscTagRowsFromSelection()
        }
        .onChange(of: focusedMiscTagKeyRowID) { oldValue, newValue in
            if let oldValue {
                finalizeMiscTagKeyEditing(for: oldValue)
            }

            if let newValue {
                recordOriginalMiscTagKeyIfNeeded(for: newValue)
            }
        }
        .focusedSceneValue(\.showTomlSheet) {
            isTomlSheetPresented = true
        }
        .focusedSceneValue(\.showFlacImporter) {
            isFlacImporterPresented = true
        }
        .fileImporter(
            isPresented: $isFlacImporterPresented,
            allowedContentTypes: [.folder, UTType(filenameExtension: "flac") ?? .data],
            allowsMultipleSelection: true,
            onCompletion: handleFlacImportResult
        )
        .sheet(isPresented: $isTomlSheetPresented) {
            TOMLUtilityView(tomlText: tomlText())
        }
        .sheet(isPresented: $isAlbumArtSheetPresented) {
            AlbumArtSheetView(
                albumArtTypes: albumArtTypes,
                navigationPath: Binding(
                    get: { albumArtViewModel.albumArtNavigationPath },
                    set: { albumArtViewModel.albumArtNavigationPath = $0 }
                ),
                isFileImporterPresented: Binding(
                    get: { albumArtViewModel.isAlbumArtFileImporterPresented },
                    set: { albumArtViewModel.isAlbumArtFileImporterPresented = $0 }
                ),
                isFileExporterPresented: Binding(
                    get: { albumArtViewModel.isAlbumArtFileExporterPresented },
                    set: { albumArtViewModel.isAlbumArtFileExporterPresented = $0 }
                ),
                exportDocument: albumArtViewModel.albumArtExportDocument,
                exportContentType: albumArtViewModel.albumArtExportContentType,
                exportDefaultFileName: albumArtViewModel.albumArtExportDefaultFileName,
                imageForSlot: albumArtViewModel.imageForAlbumArtSlot(_:),
                hasImageForSlot: albumArtViewModel.hasImage(for:),
                onOpenPicker: albumArtViewModel.openAlbumArtFilePicker(for:),
                onPrepareExport: { slot in
                    albumArtViewModel.prepareAlbumArtExport(for: slot, albumArtTypes: albumArtTypes)
                },
                onDropForSlot: { providers, slot in albumArtViewModel.handleAlbumArtDrop(providers, for: slot) },
                onFileImportResult: albumArtViewModel.handleAlbumArtFileImportResult(_:),
                onFileExportResult: albumArtViewModel.handleAlbumArtFileExportResult(_:)
            )
        }
        .alert("FLAC Import Error", isPresented: $isImportErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
    }
}

extension FocusedValues {
    @Entry var showTomlSheet: (() -> Void)?
    @Entry var showFlacImporter: (() -> Void)?
}

#Preview {
    ContentView()
}
