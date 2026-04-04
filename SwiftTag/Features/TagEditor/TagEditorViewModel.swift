import Foundation
import Observation
import SwiftUI

enum TagEditorSaveError: LocalizedError {
    case noTracksToSave
    case failedToResolveAccess(path: String)
    case failedToAccessFile(path: String)
    case partialFailure(messages: [String])

    var errorDescription: String? {
        switch self {
        case .noTracksToSave:
            return "There are no imported FLAC tracks available for the requested save operation."
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
    let mixedSelectionMarker: String = "*"
    var totalDiscs: String = ""
    var selectedTrackIDs: Set<UUID> = []
    var miscTagRows: [MiscTagRow] = []
    var selectedMiscTagRowIDs: Set<MiscTagRow.ID> = []
    var originalMiscTagKeyByRowID: [MiscTagRow.ID: String] = [:]
    var trackItems: [Track] {
        didSet {
            applyLegacySharedMetadataIfNeeded()
        }
    }
    var importedFlacPicturesByType: [Int: Data] = [:]

    private let totalTrackTagKeys: [String] = ["TOTALTRACKS", "TRACKTOTAL"]
    private let totalDiscTagKeys: [String] = ["TOTALDISCS", "DISCTOTAL"]
    private var pendingMissingRefreshTasks: [UUID: Task<Void, Never>] = [:]
    private var pendingAlbumValue: String = ""
    private var pendingAlbumArtistValue: String = ""
    private var rememberedSwiftTagDocumentSaveState: SwiftTagDocumentSaveState = .init()

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
        !trackItems.isEmpty
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
                flacFingerprint: track.fingerprint
            )
        }
    }

    func swiftTagDocumentSaveState() -> SwiftTagDocumentSaveState {
        rememberedSwiftTagDocumentSaveState
    }

    func rememberSwiftTagDocumentSave(_ result: SwiftTagDocumentSaveResult) {
        rememberedSwiftTagDocumentSaveState.destinationURL = result.destinationURL
        rememberedSwiftTagDocumentSaveState.documentID = result.documentID
    }

    func loadSwiftTagDocument(
        _ document: SwiftTagDocumentImportResult,
        tagWriteOptions: TagWriteOptions
    ) {
        rememberedSwiftTagDocumentSaveState.destinationURL = document.documentURL
        rememberedSwiftTagDocumentSaveState.documentID = document.documentID
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
                preservesEditorStateDuringFileRefresh: true
            )
        }

        importedFlacPicturesByType = importedPicturesByType
        trackItems = loadedTracks
        syncCurrentStateAsSaved(tagWriteOptions: tagWriteOptions, albumArtPictures: [])
        reloadMiscTagRowsFromSelection()
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
        let trackIndices = compilationTrackIndices(applyToAllTracks: applyToAllTracks)
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
        Set(compilationTrackIndices(applyToAllTracks: applyToAllTracks).map { trackItems[$0].id })
    }

    func canEditCompilation(applyToAllTracks: Bool) -> Bool {
        !compilationTrackIndices(applyToAllTracks: applyToAllTracks).isEmpty
    }

    func setCompilationEnabled(_ isEnabled: Bool, applyToAllTracks: Bool) {
        for index in compilationTrackIndices(applyToAllTracks: applyToAllTracks) {
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
                    value = existingRowsByKey[key]?.value ?? ""
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
            let importedPictureRecords = FlacImportMapper.mapWritablePictureRecords(metadata.pictures)
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
                        pictureRecords: importedPictureRecords,
                        fingerprint: metadata.fingerprint
                    ),
                    fingerprint: metadata.fingerprint,
                    isLocked: locked
                )
            )
        }

        if append {
            trackItems.append(contentsOf: importedTracks)
            importedFlacPicturesByType.merge(importedPicturesByType) { existing, _ in existing }
        } else {
            rememberedSwiftTagDocumentSaveState = .init()
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

    func setPictureRecordsByTrackID(_ recordsByTrackID: [UUID: [FlacWritablePictureRecord]]) {
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
        }

        trackItems = updatedTrackItems
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

        var failures: [String] = []
        var savedTrackReferences: [ImportedTrackReference] = []
        let totalTrackCount = trackIndices.count

        for (offset, index) in trackIndices.enumerated() {
            let track = trackItems[index]
            progress?(offset + 1, totalTrackCount, saveStatusDisplayName(for: track))
            await Task.yield()

            do {
                try withAccessingSecurityScopedTrackURL(for: index) { fileURL in
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
                        albumArtPictures: picturesForTrack
                    )
                    savedTrackReferences.append(refreshedTrackReference)
                }
            } catch {
                let path = track.sourceFileURL?.path ?? track.tags[TagKey.filename] ?? "Unknown file"
                failures.append("\(path): \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
            }
        }

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

        if let externalDifferences = track.externalDifferences, externalDifferences.hasDifferences {
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

    func hasExternalPictureDifference(in selection: Set<UUID>? = nil) -> Bool {
        let trackIDs = selection ?? Set(trackItems.map(\.id))
        return trackItems.contains { track in
            trackIDs.contains(track.id) && (track.externalDifferences?.hasPictureDifference ?? false)
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
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord]
    ) {
        for index in trackItems.indices {
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
                let importedPictureRecords = FlacImportMapper.mapWritablePictureRecords(metadata.pictures)
                let refreshedBookmarkData = try fileURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                updatedTrackItems[index].album = (initialValues.album ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                updatedTrackItems[index].albumArtist = (initialValues.albumArtist ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                updatedTrackItems[index].totalTracks = Int(initialValues.totalTracks ?? "").map(String.init) ?? (initialValues.totalTracks ?? "")
                updatedTrackItems[index].tags = mappedTrackTags
                updatedTrackItems[index].flacPictureRecords = pictureRecords
                updatedTrackItems[index].flacPicturesByType = picturesByType
                updatedTrackItems[index].sourceFileURL = fileURL
                updatedTrackItems[index].securityScopedBookmarkData = refreshedBookmarkData
                updatedTrackItems[index].fingerprint = metadata.fingerprint
                updatedTrackItems[index].preservesEditorStateDuringFileRefresh = false
                updatedTrackItems[index].latestFileSnapshot = TrackFileSnapshot(
                    tags: FlacWriteMapper.makeTags(
                        for: updatedTrackItems[index],
                        totalDiscs: currentTotalDiscsValue(for: updatedTrackItems[index]),
                        options: tagWriteOptions
                    ),
                    picturesByType: writablePicturesByType(from: pictureRecords),
                    pictureRecords: canonicalPictureRecords(importedPictureRecords),
                    fingerprint: metadata.fingerprint
                )
                updatedTrackItems[index].externalDifferences = nil
                didUpdateTrackItems = true
            }
        }

        if didUpdateTrackItems {
            trackItems = updatedTrackItems
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
        albumArtPictures: [FlacWritablePictureRecord]
    ) throws {
        let metadata = try FlacMetadataService.readTags(for: fileURL)
        let picturesByType = writablePicturesByType(from: albumArtPictures)
        trackItems[index].fingerprint = metadata.fingerprint
        trackItems[index].preservesEditorStateDuringFileRefresh = false
        trackItems[index].latestFileSnapshot = TrackFileSnapshot(
            tags: expectedFileTags(forTrackAt: index, tagWriteOptions: tagWriteOptions),
            picturesByType: picturesByType,
            pictureRecords: canonicalPictureRecords(albumArtPictures),
            fingerprint: metadata.fingerprint
        )
        trackItems[index].flacPictureRecords = albumArtPictures
        trackItems[index].flacPicturesByType = picturesByType
        trackItems[index].externalDifferences = nil
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

        if let currentPath, !currentPath.isEmpty,
           FileManager.default.fileExists(atPath: currentPath) {
            refreshTrackFileState(
                at: index,
                fileURL: URL(fileURLWithPath: currentPath),
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures,
                allowMissingRetry: allowMissingRetry
            )
            return
        }

        do {
            try withAccessingSecurityScopedTrackURL(for: index) { fileURL in
                self.refreshTrackFileState(
                    at: index,
                    fileURL: fileURL,
                    tagWriteOptions: tagWriteOptions,
                    albumArtPictures: albumArtPictures,
                    allowMissingRetry: allowMissingRetry
                )
            }
        } catch {
            handleMissingTrackFileState(
                at: index,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures,
                allowMissingRetry: allowMissingRetry
            )
        }
    }

    private func refreshTrackFileState(
        at index: Int,
        fileURL: URL,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord],
        allowMissingRetry: Bool
    ) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            handleMissingTrackFileState(
                at: index,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures,
                allowMissingRetry: allowMissingRetry
            )
            return
        }

        cancelPendingMissingRefresh(for: trackItems[index].id)

        if fileURL.path != trackItems[index].sourceFileURL?.path {
            updateTrackFileURL(fileURL, at: index)
            trackItems[index].tags[TagKey.filename] = fileURL.lastPathComponent
        }

        do {
            let metadata = try FlacMetadataService.readTags(for: fileURL)
            let livePicturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
            let pictureRecords = FlacImportMapper.mapWritablePictureRecords(
                metadata.pictures,
                normalizeImageMetadata: true
            )
            let importedPictureRecords = FlacImportMapper.mapWritablePictureRecords(metadata.pictures)
            let fileSnapshot = makeFileSnapshot(
                tags: metadata.tags,
                picturesByType: livePicturesByType,
                pictureRecords: importedPictureRecords,
                fingerprint: metadata.fingerprint
            )
            if !trackItems[index].preservesEditorStateDuringFileRefresh {
                trackItems[index].flacPictureRecords = pictureRecords
                trackItems[index].flacPicturesByType = livePicturesByType
            }
            trackItems[index].fingerprint = metadata.fingerprint
            trackItems[index].externalDifferences = externalDifferences(
                for: index,
                fileSnapshot: fileSnapshot,
                tagWriteOptions: tagWriteOptions,
                albumArtPictures: albumArtPictures
            )
        } catch {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
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
            tags.removeValue(forKey: "ALBUM ARTIST")
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
        if !snapshot.pictureRecords.isEmpty || !currentPictures.isEmpty {
            return canonicalPictureRecords(currentPictures) != canonicalPictureRecords(snapshot.pictureRecords)
        }

        return writablePicturesByType(from: currentPictures) != snapshot.picturesByType
    }

    private func canonicalPictureRecords(_ pictures: [FlacWritablePictureRecord]) -> [FlacWritablePictureRecord] {
        pictures.enumerated()
            .sorted { lhs, rhs in
                let lhsType = lhs.element.type == 3 ? Int.max : lhs.element.type
                let rhsType = rhs.element.type == 3 ? Int.max : rhs.element.type
                if lhsType != rhsType {
                    return lhsType < rhsType
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
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

        let result = TrackExternalDifferences(
            isDeleted: false,
            fileValuesByTag: differences,
            hasPictureDifference: hasPictureDifference
        )
        return result.hasDifferences ? result : nil
    }

    private func hoverHelp(for differences: TrackExternalDifferences) -> String {
        var lines: [String] = []

        if differences.isDeleted {
            lines.append("\(TagKey.filename): <deleted>")
        }

        for key in differences.fileValuesByTag.keys.sorted() {
            lines.append("\(key): \(differences.fileValuesByTag[key] ?? "<missing>")")
        }

        if differences.hasPictureDifference {
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

        let filename = track.tags[TagKey.filename]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !filename.isEmpty {
            return filename
        }

        if let sourceFileURL = track.sourceFileURL {
            return sourceFileURL.lastPathComponent
        }

        return "Unknown track"
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

    private func compilationTrackIndices(applyToAllTracks: Bool) -> [Int] {
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

    private func bookmarkIdentity(for track: Track) -> String {
        if let bookmarkData = track.securityScopedBookmarkData,
           let resolvedPath = resolvedPathFromBookmarkData(bookmarkData) {
            return resolvedPath
        }

        return bookmarkIdentity(for: track.sourceFileURL)
    }

    private func bookmarkIdentity(for fileURL: URL?) -> String {
        guard let fileURL else {
            return ""
        }
        if let bookmarkData = try? fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ),
           let resolvedPath = resolvedPathFromBookmarkData(bookmarkData) {
            return resolvedPath
        }

        return fileURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func resolvedPathFromBookmarkData(_ bookmarkData: Data) -> String? {
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
            return resolvedURL.standardizedFileURL.resolvingSymlinksInPath().path
        } catch {
            return nil
        }
    }

    private func applyLegacySharedMetadataIfNeeded() {
        let normalizedTrackCount = String(trackItems.count)

        for index in trackItems.indices {
            if trackItems[index].album.isEmpty, !pendingAlbumValue.isEmpty {
                trackItems[index].album = pendingAlbumValue
            }

            if trackItems[index].albumArtist.isEmpty, !pendingAlbumArtistValue.isEmpty {
                trackItems[index].albumArtist = pendingAlbumArtistValue
            }

            if trackItems[index].totalTracks.isEmpty {
                trackItems[index].totalTracks = normalizedTrackCount
            }
        }
    }

    private func withAccessingSecurityScopedTrackURL<T>(
        for index: Int,
        _ body: (URL) throws -> T
    ) throws -> T {
        guard trackItems.indices.contains(index) else {
            throw TagEditorSaveError.noTracksToSave
        }

        let track = trackItems[index]
        guard let bookmarkData = track.securityScopedBookmarkData else {
            guard let sourceFileURL = track.sourceFileURL else {
                throw TagEditorSaveError.failedToResolveAccess(path: track.tags[TagKey.filename] ?? "Unknown file")
            }

            return try body(sourceFileURL)
        }

        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            trackItems[index].securityScopedBookmarkData = try resolvedURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }

        let didAccess = resolvedURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }

        guard didAccess else {
            throw TagEditorSaveError.failedToAccessFile(path: resolvedURL.path)
        }

        return try body(resolvedURL)
    }
}
