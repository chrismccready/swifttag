import Foundation
import Observation
import SwiftUI

struct EditorNavigationMetadata: Equatable {
    let title: String
    let subtitle: String
    let documentURL: URL?
    let documentDisplayName: String?
}

fileprivate enum TrackBookmarkIdentityResolver {
    static func identity(for track: Track) -> String? {
        identity(
            bookmarkData: track.securityScopedBookmarkData,
            fallbackFileURL: track.sourceFileURL
        )
    }

    static func identity(for fileURL: URL?) -> String {
        guard let fileURL else {
            return ""
        }

        if let bookmarkData = try? fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ),
           let resolvedPath = resolvedPath(from: bookmarkData) {
            return resolvedPath
        }

        return normalizedPath(for: fileURL) ?? ""
    }

    static func identity(
        bookmarkData: Data?,
        fallbackFileURL: URL?
    ) -> String? {
        if let bookmarkData,
           let resolvedPath = resolvedPath(from: bookmarkData) {
            return resolvedPath
        }

        return normalizedPath(for: fallbackFileURL)
    }

    static func identity(
        bookmarkData: Data?,
        fallbackSourceFilePath: String?
    ) -> String? {
        if let bookmarkData,
           let resolvedPath = resolvedPath(from: bookmarkData) {
            return resolvedPath
        }

        return normalizedPath(for: fallbackSourceFilePath)
    }

    static func normalizedPath(for fileURL: URL?) -> String? {
        guard let fileURL else {
            return nil
        }

        return fileURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    static func normalizedPath(for filePath: String?) -> String? {
        guard let filePath else {
            return nil
        }

        let trimmedFilePath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFilePath.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: trimmedFilePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    static func resolvedPath(from bookmarkData: Data) -> String? {
        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let didAccess = resolvedURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    resolvedURL.stopAccessingSecurityScopedResource()
                }
            }
            return normalizedPath(for: resolvedURL)
        } catch {
            return nil
        }
    }
}

@MainActor
struct ReferencedSwiftTagDocumentTrackList: Equatable {
    struct Entry: Equatable {
        let securityScopedBookmarkData: Data?
        let sourceFilePath: String?
        let sessionTrackID: UUID

        init(track: Track) {
            securityScopedBookmarkData = track.securityScopedBookmarkData
            sourceFilePath = TrackBookmarkIdentityResolver.normalizedPath(for: track.sourceFileURL)
            sessionTrackID = track.id
        }

        fileprivate func resolvedIdentity() -> Identity {
            if let normalizedPath = TrackBookmarkIdentityResolver.identity(
                bookmarkData: securityScopedBookmarkData,
                fallbackSourceFilePath: sourceFilePath
            ) {
                return .filePath(normalizedPath)
            }

            return .sessionTrackID(sessionTrackID)
        }
    }

    fileprivate enum Identity: Equatable {
        case filePath(String)
        case sessionTrackID(UUID)
    }

    let entries: [Entry]

    static func make(from tracks: [Track]) -> Self {
        Self(entries: tracks.map(Entry.init(track:)))
    }

    static func differs(
        current: Self,
        baseline: Self?
    ) -> Bool {
        guard let baseline else {
            return false
        }

        let currentIdentities = current.entries.map { $0.resolvedIdentity() }
        let baselineIdentities = baseline.entries.map { $0.resolvedIdentity() }
        return currentIdentities != baselineIdentities
    }
}

enum TagEditorSaveError: LocalizedError {
    case noTracksToSave
    case failedToResolveAccess(path: String)
    case failedToAccessFile(path: String)
    case partialFailure(messages: [String])

    var errorDescription: String? {
        switch self {
        case .noTracksToSave:
            return "There are no imported/selected FLAC tracks available for the requested save operation."
        case let .failedToResolveAccess(path):
            return "Failed to resolve security-scoped access for \(path). Re-import the file and try again."
        case let .failedToAccessFile(path):
            return "Failed to access \(path) for writing."
        case let .partialFailure(messages):
            return messages.joined(separator: "\n")
        }
    }
}

@MainActor
@Observable
final class TagEditorViewModel {
    private struct ResolvedTrackFileReference {
        let fileURL: URL
        let refreshedBookmarkData: Data?
    }

    let mixedSelectionMarker: String = "*"
    var totalDiscs: String = ""
    var selectedTrackIDs: Set<UUID> = []
    var miscTagRows: [MiscTagRow] = []
    var selectedMiscTagRowIDs: Set<MiscTagRow.ID> = []
    var originalMiscTagKeyByRowID: [MiscTagRow.ID: String] = [:]
    var trackItems: [Track] {
        didSet {
            guard oldValue.map(\.id) != trackItems.map(\.id) else {
                return
            }
            applyLegacySharedMetadataIfNeeded()
        }
    }
    var importedFlacPicturesByType: [Int: Data] = [:]

    private let totalTrackTagKeys: [String] = ["TOTALTRACKS", "TRACKTOTAL"]
    private let totalDiscTagKeys: [String] = ["TOTALDISCS", "DISCTOTAL"]
    private var pendingMissingRefreshTasks: [UUID: Task<Void, Never>] = [:]
    private var pendingSwiftTagDocumentMissingRefreshTask: Task<Void, Never>?
    private var pendingAlbumValue: String = ""
    private var pendingAlbumArtistValue: String = ""
    private var rememberedSwiftTagDocumentSaveState: SwiftTagDocumentSaveState = .init()
    private var referencedSwiftTagDocumentTrackListBaseline: ReferencedSwiftTagDocumentTrackList?

    init() {
        trackItems = []
    }

    var album: String {
        get { sharedDisplayValue(for: trackItems.map(\.album)) }
        set {
            pendingAlbumValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            for index in trackItems.indices {
                trackItems[index].album = pendingAlbumValue
            }
        }
    }

    var albumArtist: String {
        get { sharedDisplayValue(for: trackItems.map(\.albumArtist)) }
        set {
            pendingAlbumArtistValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            for index in trackItems.indices {
                trackItems[index].albumArtist = pendingAlbumArtistValue
            }
        }
    }

    var selectedAlbumIsMixed: Bool { isMixedSelectedTrackValue(\.album) }

    var selectedAlbumArtistIsMixed: Bool { isMixedSelectedTrackValue(\.albumArtist) }

    var selectedTotalTracksIsMixed: Bool { isMixedSelectedTrackValue(\.totalTracks) }

    var totalTracksHoverMessage: String {
        if selectedTrackIDs.isEmpty {
            return "Select track(s) to edit total tracks."
        }

        if hasTotalTracksMismatch {
            return "Track count mismatch: one or more selected total-tracks values do not match the current loaded track count."
        }

        return "Loaded track count is \(trackItems.count)."
    }

    var hasTotalTracksMismatch: Bool {
        guard !trackItems.isEmpty else {
            return false
        }

        let expectedValue = String(trackItems.count)
        return trackItems.contains { track in
            let normalizedValue = normalizedTagValue(track.totalTracks)
            return !normalizedValue.isEmpty && normalizedValue != expectedValue
        }
    }

    var hasTotalDiscsMismatch: Bool {
        let totalDiscValues = trackItems.compactMap { track in
            totalDiscTagKeys.lazy
                .compactMap { self.normalizedTagValue(track.tags[$0] ?? "") }
                .first(where: { !$0.isEmpty })
        }
        let distinctTotals = Set(totalDiscValues)
        if distinctTotals.count > 1 {
            return true
        }

        let maximumTotalDiscs = totalDiscValues.compactMap(Int.init).max()
        guard let maximumTotalDiscs else {
            return false
        }

        if trackItems.contains(where: { track in
            guard let discNumber = Int(normalizedTagValue(track.tags[TagKey.discNumber] ?? "")) else {
                return false
            }
            return discNumber > maximumTotalDiscs
        }) {
            return true
        }

        return false
    }

    var totalDiscsHoverMessage: String {
        if hasTotalDiscsMismatch {
            return "Disc count mismatch: loaded tracks disagree on total discs, or a disc number exceeds the maximum total discs value."
        }

        let selectedTracks = trackItems.filter { selectedTrackIDs.contains($0.id) }
        guard !selectedTracks.isEmpty else {
            return "Select track(s) to edit total discs."
        }

        let selectedValues = selectedTracks.map(currentTotalDiscsValue(for:))
        if selectedValues.allSatisfy({ $0.isEmpty }) {
            return "Set total discs. Empty TOTALDISCS values are ignored."
        }

        return "Selected total discs value updates selected tracks."
    }

    var hasImportedFlacTracks: Bool {
        trackItems.contains(where: \.isImportedFlacTrack)
    }

    var importedTrackReferences: [ImportedTrackReference] {
        trackItems.compactMap(\.importedTrackReference)
    }

    var hasUnlockedTracks: Bool {
        trackItems.contains { $0.isImportedFlacTrack && !$0.isLocked }
    }

    var nonDeletedTrackCount: Int {
        trackItems.count(where: { !$0.isDeletedInTable })
    }

    func canSave(scope: SaveScopeOption) -> Bool {
        saveTrackCount(for: scope) > 0
    }

    func saveTrackCount(for scope: SaveScopeOption) -> Int {
        saveTrackIndices(for: scope).count
    }

    func canSaveSwiftTagDocument() -> Bool {
        true
    }

    func swiftTagDocumentExportTracks() -> [SwiftTagDocumentExportTrack] {
        trackItems.enumerated().map { index, track in
            let normalizedPath = track.sourceFileURL?.standardizedFileURL.path ?? ""
            let title = track.tags[TagKey.title]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let sortKey = [
                normalizedPath,
                title,
                String(format: "%08d", index)
            ].joined(separator: "|")

            return SwiftTagDocumentExportTrack(
                sortKey: sortKey,
                tags: swiftTagDocumentTags(forTrackAt: index),
                pictures: canonicalPictureRecords(picturesForTrack(at: index, fallback: [])),
                sourceFileURL: track.sourceFileURL,
                securityScopedBookmarkData: track.securityScopedBookmarkData,
                flacFingerprint: track.fingerprint,
                sampleRate: track.sampleRate,
                totalSamples: track.totalSamples,
                bitsPerSample: track.bitsPerSample,
                channels: track.channels,
                duration: track.duration
            )
        }
    }

    func validatedSwiftTagDocumentExportTracks() throws -> [SwiftTagDocumentExportTrack] {
        for index in trackItems.indices {
            try validateSwiftTagDocumentTrackReferenceForExport(at: index)
        }

        return swiftTagDocumentExportTracks()
    }

    func swiftTagDocumentSaveState() -> SwiftTagDocumentSaveState {
        rememberedSwiftTagDocumentSaveState
    }

    func rememberSwiftTagDocumentSave(_ result: SwiftTagDocumentSaveResult) {
        rememberedSwiftTagDocumentSaveState = makeSwiftTagDocumentSaveState(
            destinationURL: result.destinationURL,
            documentID: result.documentID,
            securityScopedBookmarkData: result.securityScopedBookmarkData,
            availability: .available
        )
        cancelPendingSwiftTagDocumentMissingRefresh()
        acceptCurrentTrackListAsReferencedSwiftTagDocumentBaseline()
    }

    func loadSwiftTagDocument(
        _ document: SwiftTagDocumentImportResult,
        tagWriteOptions: TagWriteOptions
    ) {
        rememberedSwiftTagDocumentSaveState = makeSwiftTagDocumentSaveState(
            destinationURL: document.documentURL,
            documentID: document.documentID,
            securityScopedBookmarkData: document.securityScopedBookmarkData,
            availability: .available
        )
        cancelPendingSwiftTagDocumentMissingRefresh()
        selectedTrackIDs.removeAll()
        selectedMiscTagRowIDs.removeAll()
        originalMiscTagKeyByRowID.removeAll()
        pendingAlbumValue = ""
        pendingAlbumArtistValue = ""
        totalDiscs = ""

        var importedPicturesByType: [Int: Data] = [:]
        let loadedTracks = document.tracks.map { documentTrack in
            let initialValues = FlacImportMapper.initialValues(from: documentTrack.tags)
            let pictureRecords = documentTrack.pictures
            let picturesByType = writablePicturesByType(from: pictureRecords)

            for (pictureType, pictureData) in picturesByType where importedPicturesByType[pictureType] == nil {
                importedPicturesByType[pictureType] = pictureData
            }

            return Track(
                album: initialValues.album,
                albumArtist: initialValues.albumArtist,
                totalTracks: initialValues.totalTracks,
                tags: editorTagsForSwiftTagDocumentTrack(
                    sourceTags: documentTrack.tags,
                    sourceFileURL: documentTrack.sourceFileURL
                ),
                flacPicturesByType: picturesByType,
                flacPictureRecords: pictureRecords,
                sourceFileURL: documentTrack.sourceFileURL,
                securityScopedBookmarkData: documentTrack.securityScopedBookmarkData,
                fingerprint: documentTrack.flacFingerprint,
                duration: documentTrack.duration,
                sampleRate: documentTrack.sampleRate,
                totalSamples: documentTrack.totalSamples,
                bitsPerSample: documentTrack.bitsPerSample,
                channels: documentTrack.channels,
                preservesEditorStateDuringFileRefresh: true
            )
        }

        importedFlacPicturesByType = importedPicturesByType
        trackItems = loadedTracks
        acceptCurrentTrackListAsReferencedSwiftTagDocumentBaseline()
        syncCurrentStateAsSaved(tagWriteOptions: tagWriteOptions, albumArtPictures: [])
        reloadMiscTagRowsFromSelection()
    }

    func hasReferencedSwiftTagDocumentTrackListDifference() -> Bool {
        guard rememberedSwiftTagDocumentSaveState.hasReferencedDocument else {
            return false
        }

        return ReferencedSwiftTagDocumentTrackList.differs(
            current: ReferencedSwiftTagDocumentTrackList.make(from: trackItems),
            baseline: referencedSwiftTagDocumentTrackListBaseline
        )
    }

    func refreshLoadedTrackFileStates(
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) {
        let loadedTrackIDs = trackItems.map(\.id)
        for trackID in loadedTrackIDs {
            refreshTrackFileState(
                for: trackID,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures
            )
        }
    }

    func isTrackLocked(_ trackID: UUID) -> Bool {
        trackItems.first(where: { $0.id == trackID })?.isLocked ?? false
    }

    func isSelectionEditable(_ selection: Set<UUID>? = nil) -> Bool {
        let trackIDs = selection ?? selectedTrackIDs
        guard !trackIDs.isEmpty else {
            return false
        }

        return trackItems.contains { trackIDs.contains($0.id) } &&
            !trackItems.contains { trackIDs.contains($0.id) && $0.isLocked }
    }

    func lockMenuTitle(for selection: Set<UUID>) -> String? {
        guard !selection.isEmpty else {
            return nil
        }

        let selectedTracks = trackItems.filter { selection.contains($0.id) }
        guard !selectedTracks.isEmpty else {
            return nil
        }

        let lockedCount = selectedTracks.filter(\.isLocked).count
        let isPlural = selectedTracks.count > 1
        if lockedCount == 0 {
            return isPlural ? "Lock Selected Tracks" : "Lock Selected Track"
        }
        if lockedCount == selectedTracks.count {
            return isPlural ? "Unlock Selected Tracks" : "Unlock Selected Track"
        }
        return "Toggle Selected Tracks Lock"
    }

    func toggleLockState(for trackIDs: Set<UUID>) {
        guard !trackIDs.isEmpty else {
            return
        }

        for index in trackItems.indices where trackIDs.contains(trackItems[index].id) {
            trackItems[index].isLocked.toggle()
        }
    }

    func titleBinding(for trackID: UUID) -> Binding<String>? {
        tagBinding(for: trackID, tagName: TagKey.title)
    }

    func selectedAlbumBinding() -> Binding<String>? {
        selectedTrackValueBinding(\.album)
    }

    func selectedAlbumArtistBinding() -> Binding<String>? {
        selectedTrackValueBinding(\.albumArtist)
    }

    func selectedTotalTracksBinding() -> Binding<String>? {
        selectedTrackValueBinding(\.totalTracks)
    }

    func selectedTotalDiscsBinding() -> Binding<String>? {
        let selectedTracks = trackItems.filter { selectedTrackIDs.contains($0.id) }
        guard !selectedTracks.isEmpty else {
            return nil
        }

        return Binding(
            get: {
                self.sharedDisplayValue(
                    for: self.trackItems
                        .filter { self.selectedTrackIDs.contains($0.id) }
                        .map { self.currentTotalDiscsValue(for: $0) }
                )
            },
            set: { newValue in
                guard newValue != self.mixedSelectionMarker else {
                    return
                }

                let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                for index in self.trackItems.indices where self.selectedTrackIDs.contains(self.trackItems[index].id) {
                    guard !self.trackItems[index].isLocked else {
                        continue
                    }
                    self.setCurrentTotalDiscsValue(trimmedValue, forTrackAt: index)
                    self.clearExternallyModifiedDifference(forTrackAt: index, keys: self.totalDiscTagKeys)
                }
            }
        )
    }

    func compilationToggleState(applyToAllTracks: Bool) -> CompilationToggleState? {
        let trackIndices = compilationStateTrackIndices(applyToAllTracks: applyToAllTracks)
        guard !trackIndices.isEmpty else {
            return nil
        }

        let compilationValues = trackIndices.map { CompilationTag.isEnabled(trackItems[$0].tags[TagKey.compilation]) }
        guard let firstValue = compilationValues.first else {
            return nil
        }

        return compilationValues.allSatisfy { $0 == firstValue }
            ? (firstValue ? .on : .off)
            : .mixed
    }

    func compilationTrackIDs(applyToAllTracks: Bool) -> Set<UUID> {
        Set(compilationStateTrackIndices(applyToAllTracks: applyToAllTracks).map { trackItems[$0].id })
    }

    func canEditCompilation(applyToAllTracks: Bool) -> Bool {
        !compilationEditableTrackIndices(applyToAllTracks: applyToAllTracks).isEmpty
    }

    func setCompilationEnabled(_ isEnabled: Bool, applyToAllTracks: Bool) {
        for index in compilationEditableTrackIndices(applyToAllTracks: applyToAllTracks) {
            CompilationTag.setEnabled(isEnabled, in: &trackItems[index].tags)
            clearExternallyModifiedDifference(forTrackAt: index, keys: [TagKey.compilation])
        }
    }

    func tagBinding(for trackID: UUID, tagName: String) -> Binding<String>? {
        guard trackItems.contains(where: { $0.id == trackID }) else {
            return nil
        }

        return Binding(
            get: {
                guard let index = self.trackItems.firstIndex(where: { $0.id == trackID }) else {
                    return ""
                }
                return self.trackItems[index].tags[tagName] ?? ""
            },
            set: { newValue in
                guard let index = self.trackItems.firstIndex(where: { $0.id == trackID }) else {
                    return
                }
                guard !self.trackItems[index].isLocked else {
                    return
                }
                self.trackItems[index].tags[tagName] = newValue
                self.clearExternallyModifiedDifference(forTrackAt: index, keys: [tagName])
            }
        )
    }

    func selectedTagBinding(tagName: String) -> Binding<String>? {
        let selectedTracks = trackItems.filter { selectedTrackIDs.contains($0.id) }
        guard !selectedTracks.isEmpty else {
            return nil
        }

        return Binding(
            get: {
                let selectedValues = self.trackItems
                    .filter { self.selectedTrackIDs.contains($0.id) }
                    .map { $0.tags[tagName] ?? "" }

                guard let firstValue = selectedValues.first else {
                    return ""
                }

                let allMatch = selectedValues.allSatisfy { $0 == firstValue }
                return allMatch ? firstValue : self.mixedSelectionMarker
            },
            set: { newValue in
                for index in self.trackItems.indices where self.selectedTrackIDs.contains(self.trackItems[index].id) {
                    guard !self.trackItems[index].isLocked else {
                        continue
                    }
                    self.trackItems[index].tags[tagName] = newValue
                    self.clearExternallyModifiedDifference(forTrackAt: index, keys: [tagName])
                }
            }
        )
    }

    func sharedAlbumDisplayText(in scope: SaveScopeOption) -> String {
        let trackIndices = saveTrackIndices(for: scope)
        guard !trackIndices.isEmpty else {
            return ""
        }

        let values = trackIndices.map { trackItems[$0].album }
        return sharedDisplayValue(for: values)
    }

    func editorNavigationMetadata(
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> EditorNavigationMetadata {
        let documentState = rememberedSwiftTagDocumentSaveState
        let documentURL = documentState.navigationDocumentURL
        let documentDisplayName = documentState.documentDisplayName
        let allTrackIDs = Set(trackItems.map(\.id))
        let selectedTrackCount = trackItems.count(where: { selectedTrackIDs.contains($0.id) })
        let totalDifferenceCounts = differenceCounts(
            for: allTrackIDs,
            tagWriteOptions: tagWriteOptions,
            albumArtPictures: albumArtPictures
        )
        let selectedDifferenceCounts = differenceCounts(
            for: selectedTrackIDs,
            tagWriteOptions: tagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        return EditorNavigationMetadata(
            title: editorNavigationTitle(
                documentState: documentState,
                hasReferencedSwiftTagDocumentTrackListDifference: hasReferencedSwiftTagDocumentTrackListDifference()
            ),
            subtitle: [
                "Tracks: \(trackItems.count) (\(selectedTrackCount))",
                "Tag \u{0394}: \(totalDifferenceCounts.tagEdits) (\(selectedDifferenceCounts.tagEdits))",
                "Picture \u{0394}: \(totalDifferenceCounts.pictureEdits) (\(selectedDifferenceCounts.pictureEdits))"
            ].joined(separator: " • "),
            documentURL: documentURL,
            documentDisplayName: documentDisplayName
        )
    }

    @discardableResult
    func refreshSwiftTagDocumentSaveState(
        currentPath: String? = nil,
        allowMissingRetry: Bool = true
    ) -> Bool {
        guard rememberedSwiftTagDocumentSaveState.hasReferencedDocument else {
            cancelPendingSwiftTagDocumentMissingRefresh()
            return false
        }

        if let resolvedReference = resolvedSwiftTagDocumentReference(currentPath: currentPath) {
            cancelPendingSwiftTagDocumentMissingRefresh()
            let updatedState = makeSwiftTagDocumentSaveState(
                destinationURL: resolvedReference.fileURL,
                documentID: rememberedSwiftTagDocumentSaveState.documentID,
                securityScopedBookmarkData: resolvedReference.refreshedBookmarkData,
                availability: .available
            )
            guard updatedState != rememberedSwiftTagDocumentSaveState else {
                return false
            }

            rememberedSwiftTagDocumentSaveState = updatedState
            return true
        }

        if allowMissingRetry {
            scheduleMissingSwiftTagDocumentRefresh()
            return false
        }

        let deletedState = makeDeletedSwiftTagDocumentSaveState()
        guard deletedState != rememberedSwiftTagDocumentSaveState else {
            return false
        }

        rememberedSwiftTagDocumentSaveState = deletedState
        return true
    }

    func selectedDateBinding() -> Binding<Date>? {
        let selectedTracks = trackItems.filter { selectedTrackIDs.contains($0.id) }
        guard !selectedTracks.isEmpty else {
            return nil
        }

        return Binding(
            get: {
                let firstSelectedDate = self.trackItems
                    .first(where: { self.selectedTrackIDs.contains($0.id) })?
                    .tags[TagKey.date]
                return DateTagFormatter.parse(firstSelectedDate) ?? .now
            },
            set: { newValue in
                for index in self.trackItems.indices where self.selectedTrackIDs.contains(self.trackItems[index].id) {
                    guard !self.trackItems[index].isLocked else {
                        continue
                    }
                    self.trackItems[index].tags[TagKey.date] = DateTagFormatter.format(newValue)
                    self.clearExternallyModifiedDifference(forTrackAt: index, keys: [TagKey.date])
                }
            }
        )
    }

    func selectedDateTextBinding() -> Binding<String>? {
        let selectedTracks = trackItems.filter { selectedTrackIDs.contains($0.id) }
        guard !selectedTracks.isEmpty else {
            return nil
        }

        return Binding(
            get: {
                let selectedValues = self.trackItems
                    .filter { self.selectedTrackIDs.contains($0.id) }
                    .map { $0.tags[TagKey.date] ?? "" }

                guard let firstValue = selectedValues.first else {
                    return ""
                }

                let allMatch = selectedValues.allSatisfy { $0 == firstValue }
                return allMatch ? firstValue : self.mixedSelectionMarker
            },
            set: { newValue in
                guard newValue != self.mixedSelectionMarker else {
                    return
                }
                for index in self.trackItems.indices where self.selectedTrackIDs.contains(self.trackItems[index].id) {
                    guard !self.trackItems[index].isLocked else {
                        continue
                    }
                    self.trackItems[index].tags[TagKey.date] = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.clearExternallyModifiedDifference(forTrackAt: index, keys: [TagKey.date])
                }
            }
        )
    }

    func normalizedTagKey(_ value: String) -> String {
        TagNormalization.normalizeTagKey(value)
    }

    func hasInternalTagDifference(for trackID: UUID, key: String) -> Bool {
        hasTrackToFileTagDifference(for: trackID, key: key)
    }

    func hasTrackToFileTagDifference(for trackID: UUID, key: String) -> Bool {
        guard let track = trackItems.first(where: { $0.id == trackID }) else {
            return false
        }

        let normalizedKey = normalizedTagKey(key)
        let currentValue = normalizedTagValue(currentValue(for: track, key: normalizedKey))
        guard let snapshotValue = snapshotValue(for: track, key: normalizedKey) else {
            return false
        }

        return currentValue != snapshotValue
    }

    func hasTrackToTrackDifference(forAnyOf keys: [String], in selection: Set<UUID>? = nil) -> Bool {
        let trackIDs = selection ?? selectedTrackIDs
        let selectedTracks = trackItems.filter { trackIDs.contains($0.id) }
        guard selectedTracks.count >= 2 else {
            return false
        }

        let normalizedKeys = keys.map(normalizedTagKey)
        return normalizedKeys.contains { key in
            let currentValues = selectedTracks.map { normalizedTagValue(currentValue(for: $0, key: key)) }
            return Set(currentValues).count > 1
        }
    }

    func hasTrackToFileDifference(forAnyOf keys: [String], in selection: Set<UUID>? = nil) -> Bool {
        let trackIDs = selection ?? selectedTrackIDs
        let selectedTracks = trackItems.filter { trackIDs.contains($0.id) }
        guard !selectedTracks.isEmpty else {
            return false
        }

        let normalizedKeys = keys.map(normalizedTagKey)

        for key in normalizedKeys {
            for track in selectedTracks {
                let currentValue = normalizedTagValue(currentValue(for: track, key: key))
                guard let snapshotValue = snapshotValue(for: track, key: key) else {
                    continue
                }

                if currentValue != snapshotValue {
                    return true
                }
            }
        }

        return false
    }

    func hasTrackToFileDifference(forMiscTagRow row: MiscTagRow) -> Bool {
        let key = normalizedTagKey(row.key)
        guard !key.isEmpty else {
            return false
        }

        let selectedTracks = trackItems.filter { selectedTrackIDs.contains($0.id) }
        guard !selectedTracks.isEmpty else {
            return false
        }

        for track in selectedTracks {
            let currentValue = normalizedTagValue(track.tags[key] ?? "")
            let snapshotValue = normalizedTagValue(track.latestFileSnapshot?.tags[key] ?? "")
            if currentValue != snapshotValue {
                return true
            }
        }

        return false
    }

    func hasInternalDifference(forAnyOf keys: [String], in selection: Set<UUID>? = nil) -> Bool {
        hasTrackToTrackDifference(forAnyOf: keys, in: selection) ||
            hasTrackToFileDifference(forAnyOf: keys, in: selection)
    }

    func isExplicitTagKey(_ value: String) -> Bool {
        TagNormalization.isExplicitTagKey(value)
    }

    func reloadMiscTagRowsFromSelection() {
        selectedMiscTagRowIDs.removeAll()

        var existingRowsByKey: [String: MiscTagRow] = [:]
        for row in miscTagRows {
            let key = normalizedTagKey(row.key)
            guard !key.isEmpty else {
                continue
            }

            if existingRowsByKey[key] == nil {
                existingRowsByKey[key] = row
            }
        }

        let allMiscKeys = Set(
            trackItems
                .flatMap(\.tags.keys)
                .filter { !isExplicitTagKey($0) }
                .map { normalizedTagKey($0) }
        ).union(
            miscTagRows
                .map(\.key)
                .map(normalizedTagKey)
                .filter { !$0.isEmpty && !isExplicitTagKey($0) }
        )

        miscTagRows = allMiscKeys
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { key in
                let selectedTracks = trackItems.filter { selectedTrackIDs.contains($0.id) }
                let value: String

                if selectedTracks.isEmpty {
                    value = ""
                } else {
                    let selectedValues = selectedTracks.map { $0.tags[key] ?? "" }
                    if let firstValue = selectedValues.first, selectedValues.allSatisfy({ $0 == firstValue }) {
                        value = firstValue
                    } else {
                        value = mixedSelectionMarker
                    }
                }

                return MiscTagRow(
                    id: existingRowsByKey[key]?.id ?? UUID(),
                    key: key,
                    value: value
                )
            }
    }

    func addMiscTagRow() -> MiscTagRow.ID {
        let newRow = MiscTagRow(id: UUID(), key: "", value: "")
        miscTagRows.append(newRow)
        selectedMiscTagRowIDs = [newRow.id]
        return newRow.id
    }

    func deleteSelectedMiscTagRows() {
        guard !selectedMiscTagRowIDs.isEmpty, isSelectionEditable() else {
            return
        }

        let rowsToDelete = miscTagRows
            .filter { selectedMiscTagRowIDs.contains($0.id) }

        let keysToDelete = rowsToDelete
            .map(\.key)
            .map(normalizedTagKey)

        for row in rowsToDelete {
            originalMiscTagKeyByRowID.removeValue(forKey: row.id)
        }

        miscTagRows.removeAll { selectedMiscTagRowIDs.contains($0.id) }

        for index in trackItems.indices {
            for key in keysToDelete where !isExplicitTagKey(key) {
                trackItems[index].tags.removeValue(forKey: key)
            }
        }

        selectedMiscTagRowIDs.removeAll()
        reloadMiscTagRowsFromSelection()
    }

    func miscTagKeyBinding(for rowID: MiscTagRow.ID) -> Binding<String>? {
        guard miscTagRows.contains(where: { $0.id == rowID }) else {
            return nil
        }

        return Binding(
            get: {
                guard let rowIndex = self.miscTagRows.firstIndex(where: { $0.id == rowID }) else {
                    return ""
                }
                return self.miscTagRows[rowIndex].key
            },
            set: { newValue in
                guard let rowIndex = self.miscTagRows.firstIndex(where: { $0.id == rowID }) else {
                    return
                }
                self.miscTagRows[rowIndex].key = newValue
            }
        )
    }

    func isInvalidMiscTagKeyInput(_ rawKey: String, for rowID: MiscTagRow.ID) -> Bool {
        if TagNormalization.hasInvalidWhitespace(rawKey) {
            return true
        }

        let normalizedKey = normalizedTagKey(rawKey)
        guard !normalizedKey.isEmpty else {
            return false
        }

        return isExplicitTagKey(normalizedKey) || isDuplicateMiscTagKey(normalizedKey, excluding: rowID)
    }

    func recordOriginalMiscTagKeyIfNeeded(for rowID: MiscTagRow.ID) {
        guard originalMiscTagKeyByRowID[rowID] == nil,
              let row = miscTagRows.first(where: { $0.id == rowID }) else {
            return
        }

        originalMiscTagKeyByRowID[rowID] = normalizedTagKey(row.key)
    }

    func finalizeMiscTagKeyEditing(for rowID: MiscTagRow.ID) {
        guard let rowIndex = miscTagRows.firstIndex(where: { $0.id == rowID }) else {
            originalMiscTagKeyByRowID.removeValue(forKey: rowID)
            return
        }

        let row = miscTagRows[rowIndex]
        let normalizedCurrentKey = normalizedTagKey(row.key)
        let normalizedOriginalKey = originalMiscTagKeyByRowID[rowID] ?? normalizedCurrentKey
        let isNewRow = normalizedOriginalKey.isEmpty
        let hasInvalidFinalKey = normalizedCurrentKey.isEmpty || isInvalidMiscTagKeyInput(row.key, for: rowID)

        if hasInvalidFinalKey {
            if isNewRow {
                miscTagRows.removeAll { $0.id == rowID }
                selectedMiscTagRowIDs.remove(rowID)
            } else {
                miscTagRows[rowIndex].key = normalizedOriginalKey
            }

            originalMiscTagKeyByRowID.removeValue(forKey: rowID)
            reloadMiscTagRowsFromSelection()
            return
        }

        miscTagRows[rowIndex].key = normalizedCurrentKey

        if !normalizedOriginalKey.isEmpty, normalizedOriginalKey != normalizedCurrentKey {
            for index in trackItems.indices {
                if let value = trackItems[index].tags.removeValue(forKey: normalizedOriginalKey) {
                    trackItems[index].tags[normalizedCurrentKey] = value
                }
            }
        }

        originalMiscTagKeyByRowID.removeValue(forKey: rowID)
        reloadMiscTagRowsFromSelection()
    }

    func miscTagValueBinding(for rowID: MiscTagRow.ID) -> Binding<String>? {
        guard miscTagRows.contains(where: { $0.id == rowID }) else {
            return nil
        }

        return Binding(
            get: {
                guard let rowIndex = self.miscTagRows.firstIndex(where: { $0.id == rowID }) else {
                    return ""
                }
                return self.miscTagRows[rowIndex].value
            },
            set: { newValue in
                guard let rowIndex = self.miscTagRows.firstIndex(where: { $0.id == rowID }) else {
                    return
                }
                self.miscTagRows[rowIndex].value = newValue
                self.setMiscTagValueForSelectedTracks(key: self.miscTagRows[rowIndex].key, value: newValue)
            }
        )
    }

    func positiveIntegerStringBinding(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                if newValue.isEmpty {
                    source.wrappedValue = ""
                    return
                }

                guard let value = Int(newValue), value > 0, String(value) == newValue else {
                    return
                }

                source.wrappedValue = newValue
            }
        )
    }

    func tomlText() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var lines: [String] = [
            "album = '''\(sharedDisplayValue(for: trackItems.map(\.album)))'''",
            "album_artist = '''\(sharedDisplayValue(for: trackItems.map(\.albumArtist)))'''",
            ""
        ]

        let sortedTracks = trackItems.sorted {
            let lhs = Int($0.tags[TagKey.trackNumber] ?? "") ?? 0
            let rhs = Int($1.tags[TagKey.trackNumber] ?? "") ?? 0
            if lhs == rhs {
                return ($0.tags[TagKey.title] ?? "") < ($1.tags[TagKey.title] ?? "")
            }
            return lhs < rhs
        }

        for track in sortedTracks {
            lines.append("[[tracks]]")
            lines.append("number = \(track.tags[TagKey.trackNumber] ?? "0")")
            lines.append("title = '''\(track.tags[TagKey.title] ?? "")'''")
            lines.append("filename = '''\(track.tags[TagKey.filename] ?? "")'''")
            lines.append("artist = '''\(track.tags[TagKey.artist] ?? "")'''")
            lines.append("composer = '''\(track.tags[TagKey.composer] ?? "")'''")
            lines.append("location = '''\(track.tags[TagKey.location] ?? "")'''")
            lines.append("date = \(track.tags[TagKey.date] ?? dateFormatter.string(from: .now))")
            lines.append("description = '''\(track.tags[TagKey.description] ?? "")'''")
            lines.append("")
        }

        if lines.last?.isEmpty == true {
            lines.removeLast()
        }

        return lines.joined(separator: "\n")
    }

    func importFlacFiles(_ flacFiles: [URL], locked: Bool = false, append: Bool = false) async throws {
        try importFlacFilesSynchronously(flacFiles, locked: locked, append: append)
    }

    func importFlacFilesSynchronously(
        _ flacFiles: [URL],
        locked: Bool = false,
        append: Bool = false
    ) throws {
        guard !flacFiles.isEmpty else {
            return
        }

        var importedTracks: [Track] = []
        var importedPicturesByType: [Int: Data] = [:]

        for fileURL in flacFiles {
            let metadata = try FlacMetadataService.readTags(for: fileURL)
            let tags = metadata.tags
            let trackPicturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
            let trackPictureRecords = FlacImportMapper.mapWritablePictureRecords(
                metadata.pictures,
                normalizeImageMetadata: true
            )
            let bookmarkData = try fileURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            let initialValues = FlacImportMapper.initialValues(from: tags)

            for (pictureType, pictureData) in trackPicturesByType where importedPicturesByType[pictureType] == nil {
                importedPicturesByType[pictureType] = pictureData
            }

            let trackTags = FlacImportMapper.mapTrackTags(
                sourceTags: tags,
                fileURL: fileURL,
                defaultDate: .now
            )
            importedTracks.append(
                Track(
                    album: initialValues.album,
                    albumArtist: initialValues.albumArtist,
                    totalTracks: initialValues.totalTracks,
                    tags: trackTags,
                    flacPicturesByType: trackPicturesByType,
                    flacPictureRecords: trackPictureRecords,
                    sourceFileURL: fileURL,
                    securityScopedBookmarkData: bookmarkData,
                    latestFileSnapshot: makeFileSnapshot(
                        tags: tags,
                        picturesByType: trackPicturesByType,
                        pictureRecords: trackPictureRecords,
                        fingerprint: metadata.fingerprint
                    ),
                    fingerprint: metadata.fingerprint,
                    duration: metadata.duration,
                    sampleRate: metadata.sampleRate,
                    totalSamples: metadata.totalSamples,
                    bitsPerSample: metadata.bitsPerSample,
                    channels: metadata.channels,
                    isLocked: locked
                )
            )
        }

        if append {
            trackItems.append(contentsOf: importedTracks)
            importedFlacPicturesByType.merge(importedPicturesByType) { existing, _ in existing }
        } else {
            cancelPendingSwiftTagDocumentMissingRefresh()
            rememberedSwiftTagDocumentSaveState = .init()
            referencedSwiftTagDocumentTrackListBaseline = nil
            importedFlacPicturesByType = importedPicturesByType
            trackItems = importedTracks
            selectedTrackIDs.removeAll()
        }
        reloadMiscTagRowsFromSelection()
    }

    func setTrackTotal(_ total: Int) {
        let normalizedTotal = String(max(0, total))
        for index in trackItems.indices {
            guard !trackItems[index].isDeletedInTable else {
                continue
            }
            if trackItems[index].isLocked {
                continue
            }
            trackItems[index].totalTracks = normalizedTotal
            clearExternallyModifiedDifference(forTrackAt: index, keys: totalTrackTagKeys)
        }
    }

    func setTrackTotalToCurrentCount() {
        setTrackTotal(nonDeletedTrackCount)
    }

    func removeTracks(withIDs trackIDs: Set<UUID>) {
        guard !trackIDs.isEmpty else {
            return
        }
        trackItems.removeAll(where: { trackIDs.contains($0.id) })
        selectedTrackIDs.subtract(trackIDs)
        reloadMiscTagRowsFromSelection()
    }

    func appleScriptUpsertTag(key rawKey: String, value rawValue: String, forTrackID trackID: UUID) throws {
        guard let index = trackItems.firstIndex(where: { $0.id == trackID }) else {
            throw SwiftTagAppleScriptCommandError.invalidTagTrackTarget
        }
        guard !trackItems[index].isLocked else {
            throw SwiftTagAppleScriptCommandError.trackLocked
        }

        let normalizedKey = SwiftTagAppleScriptTagKey.normalizedKey(rawKey)
        guard !normalizedKey.isEmpty else {
            throw SwiftTagAppleScriptCommandError.invalidTagKey
        }

        let normalizedValue = SwiftTagAppleScriptTagKey.normalizedValue(rawValue)
        switch normalizedKey {
        case SwiftTagAppleScriptTagKey.totalTracks:
            trackItems[index].totalTracks = normalizedValue
        case SwiftTagAppleScriptTagKey.totalDiscs:
            setCurrentTotalDiscsValue(normalizedValue, forTrackAt: index)
        case TagKey.compilation:
            if let normalizedCompilation = CompilationTag.normalizedValue(normalizedValue) {
                trackItems[index].tags[TagKey.compilation] = normalizedCompilation
            } else {
                trackItems[index].tags.removeValue(forKey: TagKey.compilation)
            }
        default:
            for key in SwiftTagAppleScriptTagKey.relatedKeys(for: normalizedKey) where key != normalizedKey {
                trackItems[index].tags.removeValue(forKey: key)
            }
            trackItems[index].tags[normalizedKey] = normalizedValue
        }

        clearExternallyModifiedDifference(
            forTrackAt: index,
            keys: SwiftTagAppleScriptTagKey.relatedKeys(for: normalizedKey)
        )
        reloadMiscTagRowsFromSelection()
    }

    func appleScriptDeleteTag(key rawKey: String, forTrackID trackID: UUID) throws {
        guard let index = trackItems.firstIndex(where: { $0.id == trackID }) else {
            throw SwiftTagAppleScriptCommandError.invalidTagTrackTarget
        }
        guard !trackItems[index].isLocked else {
            throw SwiftTagAppleScriptCommandError.trackLocked
        }

        let normalizedKey = SwiftTagAppleScriptTagKey.normalizedKey(rawKey)
        guard !normalizedKey.isEmpty else {
            throw SwiftTagAppleScriptCommandError.invalidTagKey
        }

        switch normalizedKey {
        case SwiftTagAppleScriptTagKey.totalTracks:
            trackItems[index].tags.removeValue(forKey: "TOTALTRACKS")
            trackItems[index].tags.removeValue(forKey: "TRACKTOTAL")
        case SwiftTagAppleScriptTagKey.totalDiscs:
            setCurrentTotalDiscsValue("", forTrackAt: index)
        default:
            for key in SwiftTagAppleScriptTagKey.relatedKeys(for: normalizedKey) {
                trackItems[index].tags.removeValue(forKey: key)
            }
        }

        clearExternallyModifiedDifference(
            forTrackAt: index,
            keys: SwiftTagAppleScriptTagKey.relatedKeys(for: normalizedKey)
        )
        reloadMiscTagRowsFromSelection()
    }

    func appleScriptUpdatePictureDescription(
        _ description: String,
        forTrackID trackID: UUID,
        pictureIndex: Int
    ) throws {
        guard let trackIndex = trackItems.firstIndex(where: { $0.id == trackID }) else {
            throw SwiftTagAppleScriptCommandError.invalidPictureObject
        }
        guard !trackItems[trackIndex].isLocked else {
            throw SwiftTagAppleScriptCommandError.trackLocked
        }
        guard trackItems[trackIndex].flacPictureRecords.indices.contains(pictureIndex) else {
            throw SwiftTagAppleScriptCommandError.invalidPictureObject
        }

        let currentRecord = trackItems[trackIndex].flacPictureRecords[pictureIndex]
        trackItems[trackIndex].flacPictureRecords[pictureIndex] = FlacWritablePictureRecord(
            type: currentRecord.type,
            mimeType: currentRecord.mimeType,
            description: description,
            data: currentRecord.data,
            width: currentRecord.width,
            height: currentRecord.height,
            depth: currentRecord.depth,
            colors: currentRecord.colors
        )
    }

    func appleScriptUpsertPicture(
        _ payload: SwiftTagAppleScriptPicturePayload,
        forTrackID trackID: UUID
    ) throws -> Int {
        guard let trackIndex = trackItems.firstIndex(where: { $0.id == trackID }) else {
            throw SwiftTagAppleScriptCommandError.invalidPictureObject
        }
        guard !trackItems[trackIndex].isLocked else {
            throw SwiftTagAppleScriptCommandError.trackLocked
        }

        var records = trackItems[trackIndex].flacPictureRecords
        if let existingIndex = records.firstIndex(where: { $0.type == payload.type && $0.data == payload.data }) {
            if payload.hasExplicitDescription {
                records[existingIndex] = payload.record(defaultDescription: records[existingIndex].description)
                updatePictureRecords(records, forTrackAt: trackIndex)
            }
            return existingIndex
        }

        let insertIndex = records.lastIndex(where: { $0.type == payload.type })
            .map { records.index(after: $0) } ?? records.endIndex
        records.insert(payload.record(), at: insertIndex)
        updatePictureRecords(records, forTrackAt: trackIndex)
        return insertIndex
    }

    func appleScriptReplacePicture(
        _ payload: SwiftTagAppleScriptPicturePayload,
        replacingPictureAt pictureIndex: Int,
        forTrackID trackID: UUID
    ) throws -> Int {
        guard let trackIndex = trackItems.firstIndex(where: { $0.id == trackID }) else {
            throw SwiftTagAppleScriptCommandError.invalidPictureObject
        }
        guard !trackItems[trackIndex].isLocked else {
            throw SwiftTagAppleScriptCommandError.trackLocked
        }
        guard trackItems[trackIndex].flacPictureRecords.indices.contains(pictureIndex) else {
            throw SwiftTagAppleScriptCommandError.invalidPictureObject
        }

        var records = trackItems[trackIndex].flacPictureRecords
        let currentRecord = records[pictureIndex]
        if let existingIndex = records.indices.first(where: {
            $0 != pictureIndex && records[$0].type == payload.type && records[$0].data == payload.data
        }) {
            records[existingIndex] = payload.record(defaultDescription: records[existingIndex].description)
            records.remove(at: pictureIndex)
            updatePictureRecords(records, forTrackAt: trackIndex)
            return existingIndex > pictureIndex ? existingIndex - 1 : existingIndex
        }

        records[pictureIndex] = payload.record(defaultDescription: currentRecord.description)
        updatePictureRecords(records, forTrackAt: trackIndex)
        return pictureIndex
    }

    func appleScriptDeletePicture(
        forTrackID trackID: UUID,
        pictureIndex: Int
    ) throws {
        guard let trackIndex = trackItems.firstIndex(where: { $0.id == trackID }) else {
            throw SwiftTagAppleScriptCommandError.invalidPictureObject
        }
        guard !trackItems[trackIndex].isLocked else {
            throw SwiftTagAppleScriptCommandError.trackLocked
        }
        guard trackItems[trackIndex].flacPictureRecords.indices.contains(pictureIndex) else {
            throw SwiftTagAppleScriptCommandError.invalidPictureObject
        }

        var records = trackItems[trackIndex].flacPictureRecords
        records.remove(at: pictureIndex)
        updatePictureRecords(records, forTrackAt: trackIndex)
    }

    func appleScriptPictureIndex(
        matching payload: SwiftTagAppleScriptPicturePayload,
        forTrackID trackID: UUID
    ) -> Int? {
        guard let trackIndex = trackItems.firstIndex(where: { $0.id == trackID }) else {
            return nil
        }

        return trackItems[trackIndex].flacPictureRecords.firstIndex {
            $0.type == payload.type && $0.data == payload.data
        }
    }

    func setPictureRecordsByTrackID(
        _ recordsByTrackID: [UUID: [FlacWritablePictureRecord]],
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) {
        guard !recordsByTrackID.isEmpty else {
            return
        }

        var updatedTrackItems = trackItems
        for index in updatedTrackItems.indices {
            guard let records = recordsByTrackID[updatedTrackItems[index].id] else {
                continue
            }
            updatedTrackItems[index].flacPictureRecords = records
            updatedTrackItems[index].flacPicturesByType = writablePicturesByType(from: records)
            if let latestFileSnapshot = updatedTrackItems[index].latestFileSnapshot {
                trackItems = updatedTrackItems
                updatedTrackItems[index].externalDifferences = externalDifferences(
                    for: index,
                    fileSnapshot: latestFileSnapshot,
                    tagWriteOptions: tagWriteOptions,
                    albumArtPictures: albumArtPictures
                )
            }
        }

        trackItems = updatedTrackItems
    }

    private func updatePictureRecords(_ records: [FlacWritablePictureRecord], forTrackAt index: Int) {
        trackItems[index].flacPictureRecords = records
        trackItems[index].flacPicturesByType = writablePicturesByType(from: records)
    }

    func removeDuplicateImportURLsByBookmarkIdentity(_ urls: [URL]) -> [URL] {
        guard !urls.isEmpty else {
            return []
        }

        var existingIdentities = Set(trackItems.compactMap(bookmarkIdentity(for:)))
        var uniqueURLs: [URL] = []
        for fileURL in urls {
            let identity = bookmarkIdentity(for: fileURL)
            guard !existingIdentities.contains(identity) else {
                continue
            }
            existingIdentities.insert(identity)
            uniqueURLs.append(fileURL)
        }

        return uniqueURLs
    }

    func save(
        payload: SavePayloadOption,
        scope: SaveScopeOption,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord],
        editorSessionID: UUID,
        progress: ((Int, Int, String) -> Void)? = nil
    ) async throws -> SaveOperationResult {
        let trackIndices = try preparedSaveTrackIndices(
            payload: payload,
            scope: scope,
            tagWriteOptions: tagWriteOptions,
            albumArtPictures: albumArtPictures
        )
        var failures: [String] = []
        var savedTrackReferences: [ImportedTrackReference] = []
        let totalTrackCount = trackIndices.count

        for (offset, index) in trackIndices.enumerated() {
            let track = trackItems[index]
            progress?(offset + 1, totalTrackCount, saveStatusDisplayName(for: track))
            await Task.yield()

            do {
                let refreshedTrackReference = try saveTrack(
                    at: index,
                    payload: payload,
                    tagWriteOptions: tagWriteOptions,
                    albumArtPictures: albumArtPictures
                )
                savedTrackReferences.append(refreshedTrackReference)
            } catch {
                failures.append(saveFailureMessage(for: track, error: error))
            }
        }

        return try finalizeSaveResult(
            failures: failures,
            savedTrackReferences: savedTrackReferences,
            payload: payload,
            editorSessionID: editorSessionID
        )
    }

    func saveSynchronously(
        payload: SavePayloadOption,
        scope: SaveScopeOption,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord],
        editorSessionID: UUID,
        progress: ((Int, Int, String) -> Void)? = nil
    ) throws -> SaveOperationResult {
        let trackIndices = try preparedSaveTrackIndices(
            payload: payload,
            scope: scope,
            tagWriteOptions: tagWriteOptions,
            albumArtPictures: albumArtPictures
        )
        var failures: [String] = []
        var savedTrackReferences: [ImportedTrackReference] = []
        let totalTrackCount = trackIndices.count

        for (offset, index) in trackIndices.enumerated() {
            let track = trackItems[index]
            progress?(offset + 1, totalTrackCount, saveStatusDisplayName(for: track))

            do {
                let refreshedTrackReference = try saveTrack(
                    at: index,
                    payload: payload,
                    tagWriteOptions: tagWriteOptions,
                    albumArtPictures: albumArtPictures
                )
                savedTrackReferences.append(refreshedTrackReference)
            } catch {
                failures.append(saveFailureMessage(for: track, error: error))
            }
        }

        return try finalizeSaveResult(
            failures: failures,
            savedTrackReferences: savedTrackReferences,
            payload: payload,
            editorSessionID: editorSessionID
        )
    }

    func canSave(
        payload: SavePayloadOption,
        scope: SaveScopeOption,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> Bool {
        let trackIndices = saveTrackIndices(for: scope)
        guard !trackIndices.isEmpty else {
            return false
        }

        return trackIndices.contains { index in
            hasDifferencesForSavePayload(
                at: index,
                payload: payload,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures
            )
        }
    }

    private func preparedSaveTrackIndices(
        payload: SavePayloadOption,
        scope: SaveScopeOption,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) throws -> [Int] {
        let trackIndices = saveTrackIndices(for: scope).filter { index in
            hasDifferencesForSavePayload(
                at: index,
                payload: payload,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures
            )
        }
        guard !trackIndices.isEmpty else {
            throw TagEditorSaveError.noTracksToSave
        }

        return trackIndices
    }

    private func saveTrack(
        at index: Int,
        payload: SavePayloadOption,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) throws -> ImportedTrackReference {
        let track = trackItems[index]
        return try withAccessingSecurityScopedTrackURL(for: index) { fileURL in
            let tags = payload.writesTags
                ? FlacWriteMapper.makeTags(
                    for: track,
                    totalDiscs: currentTotalDiscsValue(for: track),
                    options: tagWriteOptions
                )
                : [:]
            let picturesForTrack = picturesForTrack(at: index, fallback: albumArtPictures)

            try FlacMetadataService.writeMetadata(
                tags: tags,
                pictures: payload.writesPictures ? picturesForTrack : [],
                to: fileURL,
                writeTags: payload.writesTags,
                writePictures: payload.writesPictures
            )

            let refreshedTrackReference = try refreshedImportedTrackReference(
                for: fileURL,
                trackIndex: index
            )
            try refreshSnapshotAfterWrite(
                for: index,
                fileURL: fileURL,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: picturesForTrack,
                wroteTags: payload.writesTags,
                wrotePictures: payload.writesPictures
            )
            return refreshedTrackReference
        }
    }

    private func finalizeSaveResult(
        failures: [String],
        savedTrackReferences: [ImportedTrackReference],
        payload: SavePayloadOption,
        editorSessionID: UUID
    ) throws -> SaveOperationResult {
        guard failures.isEmpty else {
            throw TagEditorSaveError.partialFailure(messages: failures)
        }

        return SaveOperationResult(
            sourceSessionID: editorSessionID,
            payload: payload,
            trackReferences: savedTrackReferences,
            fingerprint: TrackSetFingerprint.make(from: savedTrackReferences)
        )
    }

    private func saveFailureMessage(for track: Track, error: Error) -> String {
        let path = track.sourceFileURL?.path ?? track.tags[TagKey.filename] ?? "Unknown file"
        return "\(path): \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)"
    }

    func trackStatusPresentation(
        for trackID: UUID,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> TrackStatusPresentation? {
        guard let index = trackItems.firstIndex(where: { $0.id == trackID }) else {
            return nil
        }

        let track = trackItems[index]
        guard track.sourceFileURL != nil else {
            return nil
        }

        if track.isLocked {
            return TrackStatusPresentation(systemImageName: "lock.fill", help: "Track is locked.")
        }

        if let externalDifferences = track.externalDifferences, externalDifferences.hasStatusPresentationDifferences {
            return TrackStatusPresentation(
                systemImageName: "exclamationmark.triangle",
                help: hoverHelp(for: externalDifferences)
            )
        }

        let differences = differencesForTrack(
            at: index,
            tagWriteOptions: tagWriteOptions,
            albumArtPictures: albumArtPictures
        )
        if differences.hasTagDifferences || differences.hasPictureDifferences {
            return TrackStatusPresentation(systemImageName: "fish", help: "Editor has unsaved differences.")
        }

        return TrackStatusPresentation(systemImageName: "fish.fill", help: "Editor matches file.")
    }

    func refreshTrackFileState(
        for trackID: UUID,
        currentPath: String? = nil,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) {
        guard let index = trackItems.firstIndex(where: { $0.id == trackID }) else {
            return
        }

        refreshTrackFileState(
            at: index,
            currentPath: currentPath,
            tagWriteOptions: tagWriteOptions,
            albumArtPictures: albumArtPictures,
            allowMissingRetry: true
        )
    }

    func hasDeletedFile(for trackID: UUID) -> Bool {
        trackItems.first(where: { $0.id == trackID })?.externalDifferences?.isDeleted ?? false
    }

    func hasExternalTagDifference(for trackID: UUID, key: String) -> Bool {
        guard let track = trackItems.first(where: { $0.id == trackID }) else {
            return false
        }

        return track.externalDifferences?.fileValuesByTag.keys.contains(normalizedTagKey(key)) ?? false
    }

    func hasExternalDifference(forAnyOf keys: [String], in selection: Set<UUID>? = nil) -> Bool {
        let trackIDs = selection ?? selectedTrackIDs
        let normalizedKeys = Set(keys.map(normalizedTagKey))
        guard !trackIDs.isEmpty else {
            return false
        }

        return trackItems.contains { track in
            trackIDs.contains(track.id) &&
                !(track.externalDifferences?.fileValuesByTag.keys.filter(normalizedKeys.contains).isEmpty ?? true)
        }
    }

    func hasExternalDifferenceForAnyLoadedTrack(keys: [String]) -> Bool {
        let normalizedKeys = Set(keys.map(normalizedTagKey))
        return trackItems.contains { track in
            !(track.externalDifferences?.fileValuesByTag.keys.filter(normalizedKeys.contains).isEmpty ?? true)
        }
    }

    func selectedExternalFileValue(forAnyOf keys: [String], in selection: Set<UUID>? = nil) -> String? {
        let trackIDs = selection ?? selectedTrackIDs
        let normalizedKeys = keys.map(normalizedTagKey)
        guard !trackIDs.isEmpty else {
            return nil
        }

        let values = trackItems.compactMap { track -> String? in
            guard trackIDs.contains(track.id), let differences = track.externalDifferences else {
                return nil
            }

            for key in normalizedKeys {
                if let value = differences.fileValuesByTag[key] {
                    return value
                }
            }

            return nil
        }

        guard let firstValue = values.first else {
            return nil
        }

        return values.allSatisfy { $0 == firstValue } ? firstValue : mixedSelectionMarker
    }

    func hasExternalPictureDifference(in selection: Set<UUID>? = nil) -> Bool {
        let trackIDs = selection ?? Set(trackItems.map(\.id))
        return trackItems.contains { track in
            trackIDs.contains(track.id) && !(track.externalDifferences?.externallyModifiedPictureTypes.isEmpty ?? true)
        }
    }

    func hasExternalPictureDifference(
        for pictureType: Int,
        in selection: Set<UUID>? = nil,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> Bool {
        let trackIDs = selection ?? Set(trackItems.map(\.id))
        return trackItems.contains { track in
            trackIDs.contains(track.id) &&
                track.externalDifferences?.externallyModifiedPictureTypes.contains(pictureType) == true
        }
    }

    func hasInternalPictureDifference(
        for pictureType: Int,
        in selection: Set<UUID>? = nil,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> Bool {
        let trackIDs = selection ?? Set(trackItems.map(\.id))
        return trackItems.indices.contains { index in
            let track = trackItems[index]
            guard trackIDs.contains(track.id),
                  let latestFileSnapshot = track.latestFileSnapshot else {
                return false
            }

            let currentPictures = picturesForTrack(at: index, fallback: albumArtPictures)
            guard pictureRecordsDiffer(
                currentPictures: currentPictures,
                snapshot: latestFileSnapshot,
                pictureType: pictureType
            ) else {
                return false
            }

            return !(track.externalDifferences?.externallyModifiedPictureTypes.contains(pictureType) ?? false)
        }
    }

    func hasExternalDifference(forMiscTagRow row: MiscTagRow) -> Bool {
        let key = normalizedTagKey(row.key)
        guard !key.isEmpty else {
            return false
        }

        return hasExternalDifference(forAnyOf: [key])
    }

    func syncCurrentStateAsSaved(
        for trackIDs: Set<UUID>? = nil,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) {
        for index in trackItems.indices {
            if let trackIDs, !trackIDs.contains(trackItems[index].id) {
                continue
            }
            let picturesForTrack = picturesForTrack(at: index, fallback: albumArtPictures)
            trackItems[index].latestFileSnapshot = TrackFileSnapshot(
                tags: expectedFileTags(forTrackAt: index, tagWriteOptions: tagWriteOptions),
                picturesByType: writablePicturesByType(from: picturesForTrack),
                pictureRecords: canonicalPictureRecords(picturesForTrack),
                fingerprint: trackItems[index].fingerprint
            )
            trackItems[index].externalDifferences = nil
        }
    }

    func editorDifferenceCounts(
        for trackIDs: Set<UUID>,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> (tagEdits: Int, pictureEdits: Int) {
        var tagEditCount = 0
        var pictureEditCount = 0

        for index in trackItems.indices where trackIDs.contains(trackItems[index].id) {
            let differences = editorDifferencesForTrack(
                at: index,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures
            )
            if differences.hasTagDifferences {
                tagEditCount += 1
            }
            if differences.hasPictureDifferences {
                pictureEditCount += 1
            }
        }

        return (tagEditCount, pictureEditCount)
    }

    func differenceCounts(
        for trackIDs: Set<UUID>,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> (tagEdits: Int, pictureEdits: Int) {
        var tagEditCount = 0
        var pictureEditCount = 0

        for index in trackItems.indices where trackIDs.contains(trackItems[index].id) {
            let differences = differencesForTrack(
                at: index,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures
            )
            if differences.hasTagDifferences {
                tagEditCount += 1
            }
            if differences.hasPictureDifferences {
                pictureEditCount += 1
            }
        }

        return (tagEditCount, pictureEditCount)
    }

    func hasDifferences(
        in trackIDs: Set<UUID>,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> Bool {
        for index in trackItems.indices where trackIDs.contains(trackItems[index].id) {
            let differences = differencesForTrack(
                at: index,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures
            )
            if differences.hasTagDifferences || differences.hasPictureDifferences {
                return true
            }
        }

        return false
    }

    func reloadTracksWithDifferences(
        in trackIDs: Set<UUID>,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) throws {
        guard !trackIDs.isEmpty else {
            return
        }

        var updatedTrackItems = trackItems
        var didUpdateTrackItems = false

        for index in updatedTrackItems.indices where trackIDs.contains(updatedTrackItems[index].id) {
            let differences = differencesForTrack(
                at: index,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures
            )
            guard differences.hasTagDifferences || differences.hasPictureDifferences else {
                continue
            }

            try withAccessingSecurityScopedTrackURL(for: index) { fileURL in
                let metadata = try FlacMetadataService.readTags(for: fileURL)
                let initialValues = FlacImportMapper.initialValues(from: metadata.tags)
                let mappedTrackTags = FlacImportMapper.mapTrackTags(
                    sourceTags: metadata.tags,
                    fileURL: fileURL,
                    defaultDate: .now
                )
                let picturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
                let pictureRecords = FlacImportMapper.mapWritablePictureRecords(
                    metadata.pictures,
                    normalizeImageMetadata: true
                )
                let refreshedBookmarkData = try fileURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                updatedTrackItems[index].tags = mappedTrackTags
                if let album = initialValues.album {
                    updatedTrackItems[index].album = album
                }
                if let albumArtist = initialValues.albumArtist {
                    updatedTrackItems[index].albumArtist = albumArtist
                }
                if let totalTracks = initialValues.totalTracks {
                    updatedTrackItems[index].totalTracks = totalTracks
                }
                updatedTrackItems[index].flacPictureRecords = pictureRecords
                updatedTrackItems[index].flacPicturesByType = picturesByType
                updatedTrackItems[index].sourceFileURL = fileURL
                updatedTrackItems[index].securityScopedBookmarkData = refreshedBookmarkData
                updatedTrackItems[index].fingerprint = metadata.fingerprint
                updatedTrackItems[index].sampleRate = metadata.sampleRate
                updatedTrackItems[index].totalSamples = metadata.totalSamples
                updatedTrackItems[index].bitsPerSample = metadata.bitsPerSample
                updatedTrackItems[index].channels = metadata.channels
                updatedTrackItems[index].duration = metadata.duration
                updatedTrackItems[index].preservesEditorStateDuringFileRefresh = false
                updatedTrackItems[index].latestFileSnapshot = TrackFileSnapshot(
                    tags: FlacWriteMapper.makeTags(
                        for: updatedTrackItems[index],
                        totalDiscs: currentTotalDiscsValue(for: updatedTrackItems[index]),
                        options: tagWriteOptions
                    ),
                    picturesByType: writablePicturesByType(from: pictureRecords),
                    pictureRecords: canonicalPictureRecords(pictureRecords),
                    fingerprint: metadata.fingerprint
                )
                updatedTrackItems[index].externalDifferences = nil
                didUpdateTrackItems = true
            }
        }

        if didUpdateTrackItems {
            trackItems = updatedTrackItems
            reloadMiscTagRowsFromSelection()
        }
    }

    private func refreshedImportedTrackReference(
        for fileURL: URL,
        trackIndex: Int
    ) throws -> ImportedTrackReference {
        let refreshedBookmarkData = try fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        trackItems[trackIndex].sourceFileURL = fileURL
        trackItems[trackIndex].securityScopedBookmarkData = refreshedBookmarkData

        return ImportedTrackReference(
            filePath: fileURL.path,
            securityScopedBookmarkData: refreshedBookmarkData
        )
    }

    private func setMiscTagValueForSelectedTracks(key: String, value: String) {
        let normalizedKey = normalizedTagKey(key)
        guard !normalizedKey.isEmpty, !isExplicitTagKey(normalizedKey) else {
            return
        }

        for index in trackItems.indices where selectedTrackIDs.contains(trackItems[index].id) {
            trackItems[index].tags[normalizedKey] = value
            clearExternallyModifiedDifference(forTrackAt: index, keys: [normalizedKey])
        }
    }

    private func isDuplicateMiscTagKey(_ normalizedKey: String, excluding rowID: MiscTagRow.ID) -> Bool {
        guard !normalizedKey.isEmpty else {
            return false
        }

        return miscTagRows.contains { row in
            row.id != rowID && normalizedTagKey(row.key) == normalizedKey
        }
    }

    private func refreshSnapshotAfterWrite(
        for index: Int,
        fileURL: URL,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord],
        wroteTags: Bool,
        wrotePictures: Bool
    ) throws {
        let metadata = try FlacMetadataService.readTags(for: fileURL)
        let filePictureRecords = FlacImportMapper.mapWritablePictureRecords(
            metadata.pictures,
            normalizeImageMetadata: true
        )
        let filePicturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
        let snapshotTags = wroteTags
            ? expectedFileTags(forTrackAt: index, tagWriteOptions: tagWriteOptions)
            : metadata.tags
        let snapshotPictureRecords = wrotePictures ? albumArtPictures : filePictureRecords
        let snapshotPicturesByType = wrotePictures
            ? writablePicturesByType(from: albumArtPictures)
            : filePicturesByType
        let fileSnapshot = makeFileSnapshot(
            tags: snapshotTags,
            picturesByType: snapshotPicturesByType,
            pictureRecords: snapshotPictureRecords,
            fingerprint: metadata.fingerprint
        )

        trackItems[index].fingerprint = metadata.fingerprint
        trackItems[index].sampleRate = metadata.sampleRate
        trackItems[index].totalSamples = metadata.totalSamples
        trackItems[index].bitsPerSample = metadata.bitsPerSample
        trackItems[index].channels = metadata.channels
        trackItems[index].duration = metadata.duration
        trackItems[index].preservesEditorStateDuringFileRefresh = false
        trackItems[index].latestFileSnapshot = fileSnapshot
        trackItems[index].flacPictureRecords = albumArtPictures
        if wrotePictures {
            trackItems[index].flacPicturesByType = snapshotPicturesByType
        }
        trackItems[index].externalDifferences = externalDifferences(
            for: index,
            fileSnapshot: fileSnapshot,
            tagWriteOptions: tagWriteOptions,
            albumArtPictures: albumArtPictures
        )
    }

    private func refreshTrackFileState(
        at index: Int,
        currentPath: String? = nil,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord],
        allowMissingRetry: Bool
    ) {
        guard trackItems.indices.contains(index) else {
            return
        }

        do {
            try withResolvedTrackFileURL(for: index, currentPath: currentPath) { resolvedReference in
                let metadata: FlacMetadataRecord
                do {
                    metadata = try FlacMetadataService.readTags(for: resolvedReference.fileURL)
                } catch {
                    if !FileManager.default.fileExists(atPath: resolvedReference.fileURL.path) {
                        throw TagEditorSaveError.failedToResolveAccess(path: resolvedReference.fileURL.path)
                    }

                    throw error
                }

                let livePicturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
                let pictureRecords = FlacImportMapper.mapWritablePictureRecords(
                    metadata.pictures,
                    normalizeImageMetadata: true
                )
                let fileSnapshot = self.makeFileSnapshot(
                    tags: metadata.tags,
                    picturesByType: livePicturesByType,
                    pictureRecords: pictureRecords,
                    fingerprint: metadata.fingerprint
                )
                let preservesEditorStateDuringFileRefresh = self.trackItems[index].preservesEditorStateDuringFileRefresh
                let shouldAdoptLivePictureState = !preservesEditorStateDuringFileRefresh &&
                    self.pictureRecordsSemanticallyMatch(
                        currentPictures: self.picturesForTrack(at: index, fallback: albumArtPictures),
                        snapshot: fileSnapshot
                    )
                let previousFileSnapshot = self.trackItems[index].latestFileSnapshot

                self.applyResolvedTrackFileReference(resolvedReference, at: index)
                if shouldAdoptLivePictureState {
                    self.trackItems[index].flacPictureRecords = pictureRecords
                    self.trackItems[index].flacPicturesByType = livePicturesByType
                }
                self.cancelPendingMissingRefresh(for: self.trackItems[index].id)
                self.trackItems[index].fingerprint = metadata.fingerprint
                self.trackItems[index].sampleRate = metadata.sampleRate
                self.trackItems[index].totalSamples = metadata.totalSamples
                self.trackItems[index].bitsPerSample = metadata.bitsPerSample
                self.trackItems[index].channels = metadata.channels
                self.trackItems[index].duration = metadata.duration
                if !preservesEditorStateDuringFileRefresh {
                    self.trackItems[index].latestFileSnapshot = fileSnapshot
                }
                self.trackItems[index].externalDifferences = self.externalDifferences(
                    for: index,
                    fileSnapshot: fileSnapshot,
                    previousFileSnapshot: previousFileSnapshot,
                    tagWriteOptions: tagWriteOptions,
                    albumArtPictures: albumArtPictures
                )
            }
        } catch {
            if isTrackFileResolutionFailure(error) {
                handleMissingTrackFileState(
                    at: index,
                    tagWriteOptions: tagWriteOptions,
                    albumArtPictures: albumArtPictures,
                    allowMissingRetry: allowMissingRetry
                )
            }
        }
    }

    private func handleMissingTrackFileState(
        at index: Int,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord],
        allowMissingRetry: Bool
    ) {
        guard trackItems.indices.contains(index) else {
            return
        }

        if allowMissingRetry {
            scheduleMissingTrackRefresh(
                for: trackItems[index].id,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures
            )
            return
        }

        trackItems[index].externalDifferences = TrackExternalDifferences(
            isDeleted: true,
            fileValuesByTag: [:],
            hasPictureDifference: false
        )
    }

    private func scheduleMissingTrackRefresh(
        for trackID: UUID,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) {
        guard pendingMissingRefreshTasks[trackID] == nil else {
            return
        }

        pendingMissingRefreshTasks[trackID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let self else {
                return
            }

            guard let index = self.trackItems.firstIndex(where: { $0.id == trackID }) else {
                self.pendingMissingRefreshTasks[trackID] = nil
                return
            }

            self.pendingMissingRefreshTasks[trackID] = nil
            self.refreshTrackFileState(
                at: index,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures,
                allowMissingRetry: false
            )
        }
    }

    private func cancelPendingMissingRefresh(for trackID: UUID) {
        pendingMissingRefreshTasks.removeValue(forKey: trackID)?.cancel()
    }

    private func makeFileSnapshot(
        tags: [String: String],
        picturesByType: [Int: Data],
        pictureRecords: [FlacWritablePictureRecord] = [],
        fingerprint: String? = nil
    ) -> TrackFileSnapshot {
        TrackFileSnapshot(
            tags: normalizeFileTags(tags),
            picturesByType: picturesByType,
            pictureRecords: pictureRecords,
            fingerprint: fingerprint
        )
    }

    private func editorTagsForSwiftTagDocumentTrack(
        sourceTags: [String: String],
        sourceFileURL: URL?
    ) -> [String: String] {
        var trackTags = normalizeFileTags(sourceTags)

        let normalizedTrackNumber = trackTags[TagKey.trackNumber]
            .map { Int($0).map(String.init) ?? $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let normalizedDiscNumber = trackTags[TagKey.discNumber]
            .map { Int($0).map(String.init) ?? $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let titleFallback = sourceFileURL?.deletingPathExtension().lastPathComponent ?? ""

        trackTags[TagKey.trackNumber] = normalizedTrackNumber ?? ""
        trackTags[TagKey.discNumber] = normalizedDiscNumber ?? ""
        trackTags[TagKey.title] = normalizedTagValue(trackTags[TagKey.title] ?? "").isEmpty
            ? titleFallback
            : (trackTags[TagKey.title] ?? "")
        if let sourceFileURL {
            trackTags[TagKey.filename] = sourceFileURL.lastPathComponent
        }
        trackTags[TagKey.artist] = trackTags[TagKey.artist] ?? ""
        trackTags[TagKey.composer] = trackTags[TagKey.composer] ?? ""
        trackTags[TagKey.genre] = trackTags[TagKey.genre] ?? ""
        trackTags[TagKey.location] = trackTags[TagKey.location] ?? ""
        trackTags[TagKey.description] = trackTags[TagKey.description] ?? ""

        let defaultDate = DateTagFormatter.parse(trackTags[TagKey.date]) ?? .now
        trackTags[TagKey.date] = DateTagFormatter.format(defaultDate)

        return trackTags
    }

    private func normalizeFileTags(_ tags: [String: String]) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: tags.compactMap { key, value in
                let normalizedKey = normalizedTagKey(key)
                guard !normalizedKey.isEmpty else {
                    return nil
                }

                if normalizedKey == TagKey.compilation {
                    guard let normalizedValue = CompilationTag.normalizedValue(value) else {
                        return nil
                    }
                    return (normalizedKey, normalizedValue)
                }

                return (normalizedKey, value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        )
    }

    private func swiftTagDocumentTags(forTrackAt index: Int) -> [String: String] {
        guard trackItems.indices.contains(index) else {
            return [:]
        }

        var tags = normalizeFileTags(trackItems[index].tags)
        tags.removeValue(forKey: TagKey.filename)
        tags.removeValue(forKey: "TRACK")
        tags.removeValue(forKey: "DISC")
        tags.removeValue(forKey: "TRACKTOTAL")
        tags.removeValue(forKey: "DISCTOTAL")

        let trimmedAlbum = trackItems[index].album.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAlbum.isEmpty {
            tags.removeValue(forKey: TagKey.album)
        } else {
            tags[TagKey.album] = trackItems[index].album
        }

        let trimmedAlbumArtist = trackItems[index].albumArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAlbumArtist.isEmpty {
            tags.removeValue(forKey: TagKey.albumArtist)
        } else {
            tags[TagKey.albumArtist] = trackItems[index].albumArtist
        }

        let trimmedTotalTracks = trackItems[index].totalTracks.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTotalTracks.isEmpty {
            tags.removeValue(forKey: "TOTALTRACKS")
        } else {
            tags["TOTALTRACKS"] = trackItems[index].totalTracks
        }

        let totalDiscs = currentTotalDiscsValue(for: trackItems[index])
        if totalDiscs.isEmpty {
            tags.removeValue(forKey: "TOTALDISCS")
        } else {
            tags["TOTALDISCS"] = totalDiscs
        }

        if let normalizedCompilation = CompilationTag.normalizedValue(trackItems[index].tags[TagKey.compilation]) {
            tags[TagKey.compilation] = normalizedCompilation
        } else {
            tags.removeValue(forKey: TagKey.compilation)
        }

        return tags
    }

    private func expectedFileTags(forTrackAt index: Int, tagWriteOptions: TagWriteOptions) -> [String: String] {
        FlacWriteMapper.makeTags(
            for: trackItems[index],
            totalDiscs: currentTotalDiscsValue(for: trackItems[index]),
            options: tagWriteOptions
        )
    }

    private func currentEditorTagsForExternalComparison(
        at index: Int,
        matching fileTags: [String: String]
    ) -> [String: String] {
        var tags = normalizeFileTags(trackItems[index].tags)
        tags.removeValue(forKey: TagKey.filename)

        if let trackNumber = tags[TagKey.trackNumber] {
            tags[TagKey.trackNumber] = formattedNumericComparisonValue(
                trackNumber,
                matching: fileTags[TagKey.trackNumber]
            )
        }

        if let discNumber = tags[TagKey.discNumber] {
            tags[TagKey.discNumber] = formattedNumericComparisonValue(
                discNumber,
                matching: fileTags[TagKey.discNumber]
            )
        }

        let trimmedAlbum = trackItems[index].album.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAlbum.isEmpty {
            tags[TagKey.album] = trimmedAlbum
        }

        let trimmedAlbumArtist = trackItems[index].albumArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAlbumArtist.isEmpty {
            tags[TagKey.albumArtist] = trimmedAlbumArtist
        }

        let normalizedTotalTracks = trackItems[index].totalTracks.trimmingCharacters(in: .whitespacesAndNewlines)
        for key in totalTrackTagKeys {
            if let fileValue = fileTags[key], !fileValue.isEmpty {
                tags[key] = formattedNumericComparisonValue(normalizedTotalTracks, matching: fileValue)
            }
        }

        let normalizedTotalDiscs = currentTotalDiscsValue(for: trackItems[index])
        for key in totalDiscTagKeys {
            if let fileValue = fileTags[key], !fileValue.isEmpty {
                tags[key] = formattedNumericComparisonValue(normalizedTotalDiscs, matching: fileValue)
            }
        }

        return tags
    }

    private func formattedNumericComparisonValue(_ rawValue: String, matching fileValue: String?) -> String {
        let trimmedRawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let numericValue = Int(trimmedRawValue), numericValue >= 0 else {
            return trimmedRawValue
        }

        let canonicalValue = String(numericValue)
        guard let fileValue else {
            return canonicalValue
        }

        let trimmedFileValue = fileValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let fileNumericValue = Int(trimmedFileValue), fileNumericValue == numericValue else {
            return canonicalValue
        }

        let shouldPreservePadding = trimmedFileValue.count > canonicalValue.count && trimmedFileValue.allSatisfy(\.isNumber)
        guard shouldPreservePadding else {
            return canonicalValue
        }

        return String(format: "%0*d", trimmedFileValue.count, numericValue)
    }

    private func writablePicturesByType(from pictures: [FlacWritablePictureRecord]) -> [Int: Data] {
        var byType: [Int: Data] = [:]
        for picture in pictures where byType[picture.type] == nil {
            byType[picture.type] = picture.data
        }
        return byType
    }

    private func pictureRecordsDiffer(
        currentPictures: [FlacWritablePictureRecord],
        snapshot: TrackFileSnapshot
    ) -> Bool {
        pictureRecordsDiffer(
            currentPictures: currentPictures,
            snapshot: snapshot,
            pictureType: nil
        )
    }

    private func pictureRecordsSemanticallyMatch(
        currentPictures: [FlacWritablePictureRecord],
        snapshot: TrackFileSnapshot
    ) -> Bool {
        if !snapshot.pictureRecords.isEmpty || !currentPictures.isEmpty {
            return canonicalPictureRecords(currentPictures) == canonicalPictureRecords(snapshot.pictureRecords)
        }

        return writablePicturesByType(from: currentPictures) == snapshot.picturesByType
    }

    private func pictureRecordsDiffer(
        between lhs: TrackFileSnapshot,
        and rhs: TrackFileSnapshot,
        pictureType: Int?
    ) -> Bool {
        let filteredLhsPictureRecords = pictureType.map { pictureType in
            lhs.pictureRecords.filter { $0.type == pictureType }
        } ?? lhs.pictureRecords
        let filteredRhsPictureRecords = pictureType.map { pictureType in
            rhs.pictureRecords.filter { $0.type == pictureType }
        } ?? rhs.pictureRecords

        if !filteredLhsPictureRecords.isEmpty || !filteredRhsPictureRecords.isEmpty {
            return canonicalPictureRecords(filteredLhsPictureRecords, normalizeImageMetadata: false) !=
                canonicalPictureRecords(filteredRhsPictureRecords, normalizeImageMetadata: false)
        }

        let lhsPicturesByType = pictureType.map { pictureType in
            lhs.picturesByType[pictureType].map { [pictureType: $0] } ?? [:]
        } ?? lhs.picturesByType
        let rhsPicturesByType = pictureType.map { pictureType in
            rhs.picturesByType[pictureType].map { [pictureType: $0] } ?? [:]
        } ?? rhs.picturesByType

        return lhsPicturesByType != rhsPicturesByType
    }

    private func pictureRecordsDiffer(
        currentPictures: [FlacWritablePictureRecord],
        snapshot: TrackFileSnapshot,
        pictureType: Int?
    ) -> Bool {
        let filteredCurrentPictures = pictureType.map { pictureType in
            currentPictures.filter { $0.type == pictureType }
        } ?? currentPictures
        let filteredSnapshotPictureRecords = pictureType.map { pictureType in
            snapshot.pictureRecords.filter { $0.type == pictureType }
        } ?? snapshot.pictureRecords

        if !filteredSnapshotPictureRecords.isEmpty || !filteredCurrentPictures.isEmpty {
            return canonicalPictureRecords(filteredCurrentPictures, normalizeImageMetadata: false) !=
                canonicalPictureRecords(filteredSnapshotPictureRecords, normalizeImageMetadata: false)
        }

        let currentPicturesByType = writablePicturesByType(from: filteredCurrentPictures)
        let snapshotPicturesByType = pictureType.map { pictureType in
            snapshot.picturesByType[pictureType].map { [pictureType: $0] } ?? [:]
        } ?? snapshot.picturesByType

        return currentPicturesByType != snapshotPicturesByType
    }

    private func canonicalPictureRecords(
        _ pictures: [FlacWritablePictureRecord],
        normalizeImageMetadata: Bool = true
    ) -> [FlacWritablePictureRecord] {
        PictureRecordCanonicalizer.canonicalize(pictures, normalizeImageMetadata: normalizeImageMetadata)
    }

    private func differingFileValues(
        expectedTags: [String: String],
        fileTags: [String: String],
        ignoreMissingFileValues: Bool = false
    ) -> [String: String] {
        let allKeys = Set(expectedTags.keys).union(fileTags.keys)
        var differences: [String: String] = [:]

        for key in allKeys {
            let expectedValue = expectedTags[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let fileValue = fileTags[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if ignoreMissingFileValues, fileValue.isEmpty {
                continue
            }
            if expectedValue != fileValue {
                differences[key] = fileValue.isEmpty ? "<missing>" : fileValue
            }
        }

        return differences
    }

    private func externalDifferences(
        for index: Int,
        fileSnapshot: TrackFileSnapshot,
        previousFileSnapshot: TrackFileSnapshot? = nil,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> TrackExternalDifferences? {
        let differences = differingFileValues(
            expectedTags: currentEditorTagsForExternalComparison(
                at: index,
                matching: fileSnapshot.tags
            ),
            fileTags: fileSnapshot.tags,
            ignoreMissingFileValues: true
        )
        let picturesForTrack = picturesForTrack(at: index, fallback: albumArtPictures)
        let hasPictureDifference = pictureRecordsDiffer(currentPictures: picturesForTrack, snapshot: fileSnapshot)
        let existingExternallyModifiedPictureTypes = trackItems[index].externalDifferences?.externallyModifiedPictureTypes ?? []
        let currentDifferingPictureTypes = Set(
            existingExternallyModifiedPictureTypes.union(
                externallyModifiedPictureTypes(
                    previousSnapshot: previousFileSnapshot,
                    currentSnapshot: fileSnapshot
                )
            ).filter { pictureType in
                pictureRecordsDiffer(
                    currentPictures: picturesForTrack,
                    snapshot: fileSnapshot,
                    pictureType: pictureType
                )
            }
        )

        let result = TrackExternalDifferences(
            isDeleted: false,
            fileValuesByTag: differences,
            hasPictureDifference: hasPictureDifference,
            externallyModifiedPictureTypes: currentDifferingPictureTypes
        )
        return result.hasDifferences ? result : nil
    }

    private func externallyModifiedPictureTypes(
        previousSnapshot: TrackFileSnapshot?,
        currentSnapshot: TrackFileSnapshot
    ) -> Set<Int> {
        guard let previousSnapshot else {
            return []
        }

        let pictureTypes = Set(previousSnapshot.pictureRecords.map(\.type))
            .union(previousSnapshot.picturesByType.keys)
            .union(currentSnapshot.pictureRecords.map(\.type))
            .union(currentSnapshot.picturesByType.keys)

        return Set(pictureTypes.filter { pictureType in
            pictureRecordsDiffer(
                between: previousSnapshot,
                and: currentSnapshot,
                pictureType: pictureType
            )
        })
    }

    private func hoverHelp(for differences: TrackExternalDifferences) -> String {
        var lines: [String] = []

        if differences.isDeleted {
            lines.append("\(TagKey.filename): <deleted>")
        }

        for key in differences.fileValuesByTag.keys.sorted() {
            lines.append("\(key): \(differences.fileValuesByTag[key] ?? "<missing>")")
        }

        if differences.hasExternallyModifiedPictureDifference {
            lines.append("PICTURE: <different>")
        }

        return lines.joined(separator: "\n")
    }

    private func editorDifferencesForTrack(
        at index: Int,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> (hasTagDifferences: Bool, hasPictureDifferences: Bool) {
        guard let latestFileSnapshot = trackItems[index].latestFileSnapshot else {
            return (false, false)
        }

        let tagDifferences = !differingFileValues(
            expectedTags: expectedFileTags(forTrackAt: index, tagWriteOptions: tagWriteOptions),
            fileTags: latestFileSnapshot.tags
        ).isEmpty
        let picturesForTrack = picturesForTrack(at: index, fallback: albumArtPictures)
        let pictureDifferences = pictureRecordsDiffer(currentPictures: picturesForTrack, snapshot: latestFileSnapshot)

        return (tagDifferences, pictureDifferences)
    }

    private func picturesForTrack(at index: Int, fallback: [FlacWritablePictureRecord]) -> [FlacWritablePictureRecord] {
        guard trackItems.indices.contains(index) else {
            return fallback
        }

        let track = trackItems[index]

        // Imported tracks own picture state per track. An empty record array can be
        // an intentional editor change, so do not mask it with the shared fallback.
        if track.sourceFileURL != nil || track.latestFileSnapshot != nil {
            return track.flacPictureRecords
        }

        return track.flacPictureRecords.isEmpty
            ? fallback
            : track.flacPictureRecords
    }

    private func differencesForTrack(
        at index: Int,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> (hasTagDifferences: Bool, hasPictureDifferences: Bool) {
        let editorDifferences = editorDifferencesForTrack(
            at: index,
            tagWriteOptions: tagWriteOptions,
            albumArtPictures: albumArtPictures
        )
        let externalDifferences = trackItems[index].externalDifferences
        let hasExternalTagDifferences = !(externalDifferences?.fileValuesByTag.isEmpty ?? true)
        let hasExternalPictureDifferences = externalDifferences?.hasPictureDifference ?? false

        return (
            editorDifferences.hasTagDifferences || hasExternalTagDifferences,
            editorDifferences.hasPictureDifferences || hasExternalPictureDifferences
        )
    }

    private func hasDifferencesForSavePayload(
        at index: Int,
        payload: SavePayloadOption,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) -> Bool {
        if trackItems[index].latestFileSnapshot == nil {
            return true
        }

        let differences = differencesForTrack(
            at: index,
            tagWriteOptions: tagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        switch payload {
        case .writeTagsAndPictures:
            return differences.hasTagDifferences || differences.hasPictureDifferences
        case .writeTags:
            return differences.hasTagDifferences
        case .writePictures:
            return differences.hasPictureDifferences
        }
    }

    private func saveTrackIndices(for scope: SaveScopeOption) -> [Int] {
        switch scope {
        case .selectedTracks:
            return trackItems.indices.filter { index in
                selectedTrackIDs.contains(trackItems[index].id) &&
                    trackItems[index].isImportedFlacTrack &&
                    !trackItems[index].isLocked
            }
        case .allTracks:
            return trackItems.indices.filter { trackItems[$0].isImportedFlacTrack && !trackItems[$0].isLocked }
        }
    }

    private func saveStatusDisplayName(for track: Track) -> String {
        let title = track.tags[TagKey.title]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !title.isEmpty {
            return title
        }

        let filename = track.displayFileName
        if !filename.isEmpty {
            return filename
        }

        if let sourceFileURL = track.sourceFileURL {
            return sourceFileURL.lastPathComponent
        }

        return "Unknown track"
    }

    private func makeSwiftTagDocumentSaveState(
        destinationURL: URL?,
        documentID: UUID?,
        securityScopedBookmarkData: Data?,
        availability: SwiftTagDocumentAvailability
    ) -> SwiftTagDocumentSaveState {
        let normalizedDestinationURL = destinationURL?.standardizedFileURL
        let lastKnownDisplayName = normalizedDestinationURL?.lastPathComponent ??
            rememberedSwiftTagDocumentSaveState.lastKnownDisplayName

        return SwiftTagDocumentSaveState(
            destinationURL: normalizedDestinationURL,
            documentID: documentID,
            securityScopedBookmarkData: securityScopedBookmarkData,
            lastKnownDisplayName: lastKnownDisplayName,
            availability: availability
        )
    }

    private func makeDeletedSwiftTagDocumentSaveState() -> SwiftTagDocumentSaveState {
        SwiftTagDocumentSaveState(
            destinationURL: rememberedSwiftTagDocumentSaveState.navigationDocumentURL,
            documentID: rememberedSwiftTagDocumentSaveState.documentID,
            securityScopedBookmarkData: rememberedSwiftTagDocumentSaveState.securityScopedBookmarkData,
            lastKnownDisplayName: rememberedSwiftTagDocumentSaveState.documentDisplayName,
            availability: .deleted
        )
    }

    private func resolvedSwiftTagDocumentReference(
        currentPath: String? = nil
    ) -> ResolvedTrackFileReference? {
        let currentFileURL: URL? = {
            guard let currentPath else {
                return nil
            }

            let trimmedCurrentPath = currentPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedCurrentPath.isEmpty else {
                return nil
            }

            let candidateURL = URL(fileURLWithPath: trimmedCurrentPath).standardizedFileURL
            guard FileManager.default.fileExists(atPath: candidateURL.path) else {
                return nil
            }

            return candidateURL
        }()

        if let bookmarkData = rememberedSwiftTagDocumentSaveState.securityScopedBookmarkData {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ).standardizedFileURL
                let didAccess = resolvedURL.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        resolvedURL.stopAccessingSecurityScopedResource()
                    }
                }

                if didAccess, FileManager.default.fileExists(atPath: resolvedURL.path) {
                    return ResolvedTrackFileReference(
                        fileURL: resolvedURL,
                        refreshedBookmarkData: try? resolvedURL.bookmarkData(
                            options: URL.BookmarkCreationOptions.withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                    )
                }
            } catch {
                // Fall back to the remembered URL when the bookmark can no longer resolve.
            }
        }

        if let currentFileURL,
           FileManager.default.fileExists(atPath: currentFileURL.path) {
            return ResolvedTrackFileReference(
                fileURL: currentFileURL,
                refreshedBookmarkData: try? currentFileURL.bookmarkData(
                    options: URL.BookmarkCreationOptions.withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            )
        }

        if let rememberedURL = rememberedSwiftTagDocumentSaveState.navigationDocumentURL,
           FileManager.default.fileExists(atPath: rememberedURL.path) {
            return ResolvedTrackFileReference(
                fileURL: rememberedURL,
                refreshedBookmarkData: try? rememberedURL.bookmarkData(
                    options: URL.BookmarkCreationOptions.withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            )
        }

        return nil
    }

    private func scheduleMissingSwiftTagDocumentRefresh() {
        guard pendingSwiftTagDocumentMissingRefreshTask == nil else {
            return
        }

        pendingSwiftTagDocumentMissingRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let self else {
                return
            }

            self.pendingSwiftTagDocumentMissingRefreshTask = nil
            _ = self.refreshSwiftTagDocumentSaveState(allowMissingRetry: false)
        }
    }

    private func cancelPendingSwiftTagDocumentMissingRefresh() {
        pendingSwiftTagDocumentMissingRefreshTask?.cancel()
        pendingSwiftTagDocumentMissingRefreshTask = nil
    }

    private func acceptCurrentTrackListAsReferencedSwiftTagDocumentBaseline() {
        guard rememberedSwiftTagDocumentSaveState.hasReferencedDocument else {
            referencedSwiftTagDocumentTrackListBaseline = nil
            return
        }

        referencedSwiftTagDocumentTrackListBaseline = ReferencedSwiftTagDocumentTrackList.make(from: trackItems)
    }

    private func editorNavigationTitle(
        documentState: SwiftTagDocumentSaveState,
        hasReferencedSwiftTagDocumentTrackListDifference: Bool
    ) -> String {
        if let documentDisplayName = documentState.documentDisplayName,
           !documentDisplayName.isEmpty {
            let markedDocumentDisplayName = hasReferencedSwiftTagDocumentTrackListDifference
                ? "\(documentDisplayName)*"
                : documentDisplayName
            return documentState.isDeleted
                ? "\(markedDocumentDisplayName) (deleted)"
                : markedDocumentDisplayName
        }

        let selectedTracks = trackItems.filter { selectedTrackIDs.contains($0.id) }
        let titleTracks = selectedTracks.isEmpty ? trackItems : selectedTracks
        guard !titleTracks.isEmpty else {
            return "SwiftTag"
        }

        let sharedAlbum = sharedDisplayValue(for: titleTracks.map(\.album))
        if sharedAlbum == mixedSelectionMarker {
            return "Mixed"
        }

        return sharedAlbum.isEmpty ? "Untitled" : sharedAlbum
    }

    private func selectedTrackValueBinding(
        _ keyPath: WritableKeyPath<Track, String>
    ) -> Binding<String>? {
        let selectedTracks = trackItems.filter { selectedTrackIDs.contains($0.id) }
        guard !selectedTracks.isEmpty else {
            return nil
        }

        return Binding(
            get: {
                self.sharedDisplayValue(
                    for: self.trackItems
                        .filter { self.selectedTrackIDs.contains($0.id) }
                        .map { $0[keyPath: keyPath] }
                )
            },
            set: { newValue in
                guard newValue != self.mixedSelectionMarker else {
                    return
                }

                let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let keysToClear = self.keysForTrackProperty(keyPath)
                for index in self.trackItems.indices where self.selectedTrackIDs.contains(self.trackItems[index].id) {
                    guard !self.trackItems[index].isLocked else {
                        continue
                    }
                    self.trackItems[index][keyPath: keyPath] = trimmedValue
                    self.clearExternallyModifiedDifference(forTrackAt: index, keys: keysToClear)
                }
            }
        )
    }

    private func isMixedSelectedTrackValue(_ keyPath: KeyPath<Track, String>) -> Bool {
        let selectedTracks = trackItems.filter { selectedTrackIDs.contains($0.id) }
        guard !selectedTracks.isEmpty else {
            return false
        }

        let normalizedValues = selectedTracks.map { $0[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines) }
        return Set(normalizedValues).count > 1
    }

    private func sharedDisplayValue(for values: [String]) -> String {
        let normalizedValues = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let firstValue = normalizedValues.first else {
            return ""
        }

        return normalizedValues.allSatisfy { $0 == firstValue }
            ? firstValue
            : mixedSelectionMarker
    }

    private func currentValue(for track: Track, key: String) -> String {
        switch key {
        case TagKey.album:
            return track.album
        case TagKey.albumArtist:
            return track.albumArtist
        case TagKey.compilation:
            return CompilationTag.normalizedValue(track.tags[TagKey.compilation]) ?? ""
        case "TOTALTRACKS", "TRACKTOTAL":
            return track.totalTracks
        case "TOTALDISCS", "DISCTOTAL":
            return currentTotalDiscsValue(for: track)
        default:
            return track.tags[key] ?? ""
        }
    }

    private func snapshotValue(for track: Track, key: String) -> String? {
        let rawValue = track.latestFileSnapshot?.tags[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawValue.isEmpty else {
            return nil
        }

        return normalizedTagValue(rawValue)
    }

    private func normalizedTagValue(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmedValue).map(String.init) ?? trimmedValue
    }

    private func currentTotalDiscsValue(for track: Track) -> String {
        for key in totalDiscTagKeys {
            let value = normalizedTagValue(track.tags[key] ?? "")
            if !value.isEmpty {
                return value
            }
        }

        return normalizedTagValue(totalDiscs)
    }

    private func compilationStateTrackIndices(applyToAllTracks: Bool) -> [Int] {
        let editableTrackIndices = compilationEditableTrackIndices(applyToAllTracks: applyToAllTracks)
        if !editableTrackIndices.isEmpty {
            return editableTrackIndices
        }

        return compilationScopedTrackIndices(applyToAllTracks: applyToAllTracks)
    }

    private func compilationEditableTrackIndices(applyToAllTracks: Bool) -> [Int] {
        trackItems.indices.filter { index in
            guard !trackItems[index].isLocked else {
                return false
            }

            if applyToAllTracks {
                return true
            }

            return selectedTrackIDs.contains(trackItems[index].id)
        }
    }

    private func compilationScopedTrackIndices(applyToAllTracks: Bool) -> [Int] {
        trackItems.indices.filter { index in
            if applyToAllTracks {
                return true
            }

            return selectedTrackIDs.contains(trackItems[index].id)
        }
    }

    private func setCurrentTotalDiscsValue(_ value: String, forTrackAt index: Int) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldWriteDiscTotal = !trackItems[index].tags["DISCTOTAL", default: ""].isEmpty
        let shouldWriteTotalDiscs = !trackItems[index].tags["TOTALDISCS", default: ""].isEmpty || !shouldWriteDiscTotal

        if trimmedValue.isEmpty {
            trackItems[index].tags.removeValue(forKey: "TOTALDISCS")
            trackItems[index].tags.removeValue(forKey: "DISCTOTAL")
            return
        }

        if shouldWriteTotalDiscs {
            trackItems[index].tags["TOTALDISCS"] = trimmedValue
        }

        if shouldWriteDiscTotal {
            trackItems[index].tags["DISCTOTAL"] = trimmedValue
        }
    }

    private func keysForTrackProperty(_ keyPath: WritableKeyPath<Track, String>) -> [String] {
        if keyPath == \Track.album {
            return [TagKey.album]
        }
        if keyPath == \Track.albumArtist {
            return [TagKey.albumArtist]
        }
        if keyPath == \Track.totalTracks {
            return totalTrackTagKeys
        }
        return []
    }

    private func clearExternallyModifiedDifference(forTrackAt index: Int, keys: [String]) {
        guard !keys.isEmpty else {
            return
        }

        guard var differences = trackItems[index].externalDifferences else {
            return
        }

        let normalizedKeys = Set(keys.map(normalizedTagKey))
        for key in normalizedKeys {
            differences.fileValuesByTag.removeValue(forKey: key)
        }

        trackItems[index].externalDifferences = differences.hasDifferences ? differences : nil
    }

    private func updateTrackFileURL(_ fileURL: URL, at index: Int) {
        trackItems[index].sourceFileURL = fileURL
        trackItems[index].securityScopedBookmarkData = try? fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func validateSwiftTagDocumentTrackReferenceForExport(at index: Int) throws {
        guard trackItems.indices.contains(index) else {
            return
        }

        guard trackItems[index].sourceFileURL != nil || trackItems[index].securityScopedBookmarkData != nil else {
            return
        }

        var resolvedReference: ResolvedTrackFileReference?
        try withResolvedTrackFileURL(for: index) { reference in
            resolvedReference = reference
        }

        if let resolvedReference {
            applyResolvedTrackFileReference(resolvedReference, at: index)
        }
    }

    private func applyResolvedTrackFileReference(_ resolvedReference: ResolvedTrackFileReference, at index: Int) {
        let normalizedURL = resolvedReference.fileURL.standardizedFileURL
        trackItems[index].sourceFileURL = normalizedURL
        trackItems[index].tags[TagKey.filename] = normalizedURL.lastPathComponent
        if let refreshedBookmarkData = resolvedReference.refreshedBookmarkData {
            trackItems[index].securityScopedBookmarkData = refreshedBookmarkData
        }
    }

    private func isTrackFileResolutionFailure(_ error: Error) -> Bool {
        guard let error = error as? TagEditorSaveError else {
            return false
        }

        switch error {
        case .failedToResolveAccess, .failedToAccessFile:
            return true
        case .noTracksToSave, .partialFailure:
            return false
        }
    }

    private func bookmarkIdentity(for track: Track) -> String {
        TrackBookmarkIdentityResolver.identity(for: track) ?? ""
    }

    private func bookmarkIdentity(for fileURL: URL?) -> String {
        TrackBookmarkIdentityResolver.identity(for: fileURL)
    }

    private func resolvedPathFromBookmarkData(_ bookmarkData: Data) -> String? {
        TrackBookmarkIdentityResolver.resolvedPath(from: bookmarkData)
    }

    private func applyLegacySharedMetadataIfNeeded() {
        let normalizedTrackCount = String(trackItems.count)

        for index in trackItems.indices {
            if !hasTagStorage(in: trackItems[index], keys: [TagKey.album]),
               trackItems[index].album.isEmpty,
               !pendingAlbumValue.isEmpty {
                trackItems[index].album = pendingAlbumValue
            }

            if !hasTagStorage(in: trackItems[index], keys: [TagKey.albumArtist]),
               trackItems[index].albumArtist.isEmpty,
               !pendingAlbumArtistValue.isEmpty {
                trackItems[index].albumArtist = pendingAlbumArtistValue
            }

            if !hasTagStorage(in: trackItems[index], keys: totalTrackTagKeys),
               trackItems[index].totalTracks.isEmpty {
                trackItems[index].totalTracks = normalizedTrackCount
            }
        }
    }

    private func hasTagStorage(in track: Track, keys: [String]) -> Bool {
        let normalizedKeys = Set(keys.map(normalizedTagKey).filter { !$0.isEmpty })
        guard !normalizedKeys.isEmpty else {
            return false
        }

        return track.tags.keys.contains { normalizedKeys.contains(normalizedTagKey($0)) }
    }

    private func withAccessingSecurityScopedTrackURL<T>(
        for index: Int,
        _ body: (URL) throws -> T
    ) throws -> T {
        try withResolvedTrackFileURL(for: index) { resolvedReference in
            try body(resolvedReference.fileURL)
        }
    }

    private func withResolvedTrackFileURL<T>(
        for index: Int,
        currentPath: String? = nil,
        _ body: (ResolvedTrackFileReference) throws -> T
    ) throws -> T {
        guard trackItems.indices.contains(index) else {
            throw TagEditorSaveError.noTracksToSave
        }

        let track = trackItems[index]
        let currentFileURL: URL? = {
            guard let currentPath else {
                return nil
            }

            let trimmedCurrentPath = currentPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedCurrentPath.isEmpty else {
                return nil
            }

            let candidateURL = URL(fileURLWithPath: trimmedCurrentPath).standardizedFileURL
            guard FileManager.default.fileExists(atPath: candidateURL.path) else {
                return nil
            }

            return candidateURL
        }()

        if let bookmarkData = track.securityScopedBookmarkData {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ).standardizedFileURL
                let didAccess = resolvedURL.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        resolvedURL.stopAccessingSecurityScopedResource()
                    }
                }

                if didAccess, let currentFileURL {
                    return try body(
                        ResolvedTrackFileReference(
                            fileURL: currentFileURL,
                            refreshedBookmarkData: try? currentFileURL.bookmarkData(
                                options: .withSecurityScope,
                                includingResourceValuesForKeys: nil,
                                relativeTo: nil
                            )
                        )
                    )
                }

                if didAccess, FileManager.default.fileExists(atPath: resolvedURL.path) {
                    return try body(
                        ResolvedTrackFileReference(
                            fileURL: resolvedURL,
                            refreshedBookmarkData: try? resolvedURL.bookmarkData(
                                options: .withSecurityScope,
                                includingResourceValuesForKeys: nil,
                                relativeTo: nil
                            )
                        )
                    )
                }
            } catch {
                // Fall through to the saved file URL when the bookmark can no longer resolve.
            }
        }

        if let currentFileURL,
           FileManager.default.isReadableFile(atPath: currentFileURL.path) {
            return try body(
                ResolvedTrackFileReference(
                    fileURL: currentFileURL,
                    refreshedBookmarkData: try? currentFileURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                )
            )
        }

        if let sourceFileURL = track.sourceFileURL?.standardizedFileURL,
           FileManager.default.fileExists(atPath: sourceFileURL.path) {
            return try body(
                ResolvedTrackFileReference(
                    fileURL: sourceFileURL,
                    refreshedBookmarkData: try? sourceFileURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                )
            )
        }

        throw TagEditorSaveError.failedToResolveAccess(
            path: track.sourceFileURL?.path ?? track.tags[TagKey.filename] ?? "Unknown file"
        )
    }
}
