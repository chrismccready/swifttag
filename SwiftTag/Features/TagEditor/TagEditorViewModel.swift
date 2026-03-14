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
    var album: String = ""
    var albumArtist: String = ""
    var totalDiscs: String = ""
    var selectedTrackIDs: Set<UUID> = []
    var miscTagRows: [MiscTagRow] = []
    var selectedMiscTagRowIDs: Set<MiscTagRow.ID> = []
    var originalMiscTagKeyByRowID: [MiscTagRow.ID: String] = [:]
    var trackItems: [Track]
    var importedFlacPicturesByType: [Int: Data] = [:]

    private let totalTrackTagKeys: [String] = ["TOTALTRACKS", "TRACKTOTAL"]
    private let totalDiscTagKeys: [String] = ["TOTALDISCS", "DISCTOTAL"]
    private var pendingMissingRefreshTasks: [UUID: Task<Void, Never>] = [:]

    init() {
        trackItems = []
    }

    var totalTracks: String {
        String(trackItems.count)
    }

    var totalTracksHoverMessage: String {
        if hasTotalTracksMismatch {
            return "Track count mismatch: one or more TOTALTRACKS/TRACKTOTAL tag values do not match the current album track count. This value will overwrite any existing values."
        }

        return "Album track count is \(totalTracks)."
    }

    var hasTotalTracksMismatch: Bool {
        let expectedValue = totalTracks

        for track in trackItems {
            for key in totalTrackTagKeys {
                let rawValue = track.tags[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !rawValue.isEmpty else {
                    continue
                }

                let normalizedValue = Int(rawValue).map(String.init) ?? rawValue
                if normalizedValue != expectedValue {
                    return true
                }
            }
        }

        return false
    }

    var hasTotalDiscsMismatch: Bool {
        for track in trackItems {
            let rawValue = track.tags["TOTALDISCS"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !rawValue.isEmpty else {
                continue
            }

            let normalizedValue = Int(rawValue).map(String.init) ?? rawValue
            if normalizedValue != normalizedTotalDiscsValue {
                return true
            }
        }

        return false
    }

    var totalDiscsHoverMessage: String {
        if hasTotalDiscsMismatch {
            return "Disc count mismatch: one or more TOTALDISCS tag values do not match this total discs value."
        }

        if totalDiscs.isEmpty {
            return "Set total discs. Empty TOTALDISCS values are ignored."
        }

        return "Album disc count is \(normalizedTotalDiscsValue)."
    }

    private var normalizedTotalDiscsValue: String {
        Int(totalDiscs).map(String.init) ?? totalDiscs
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

    func canSave(scope: SaveScopeOption) -> Bool {
        saveTrackCount(for: scope) > 0
    }

    func saveTrackCount(for scope: SaveScopeOption) -> Int {
        saveTrackIndices(for: scope).count
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

    func tagBinding(for trackID: UUID, tagName: String) -> Binding<String>? {
        guard let index = trackItems.firstIndex(where: { $0.id == trackID }) else {
            return nil
        }

        return Binding(
            get: { self.trackItems[index].tags[tagName] ?? "" },
            set: { newValue in
                guard !self.trackItems[index].isLocked else {
                    return
                }
                self.trackItems[index].tags[tagName] = newValue
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
                return allMatch ? firstValue : ""
            },
            set: { newValue in
                for index in self.trackItems.indices where self.selectedTrackIDs.contains(self.trackItems[index].id) {
                    guard !self.trackItems[index].isLocked else {
                        continue
                    }
                    self.trackItems[index].tags[tagName] = newValue
                }
            }
        )
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
                }
            }
        )
    }

    func normalizedTagKey(_ value: String) -> String {
        TagNormalization.normalizeTagKey(value)
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
                        value = ""
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
            "album = '''\(album)'''",
            "album_artist = '''\(albumArtist)'''",
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

    func importFlacFiles(_ flacFiles: [URL], locked: Bool = false) async throws {
        guard !flacFiles.isEmpty else {
            return
        }

        var importedTracks: [Track] = []
        var importedPicturesByType: [Int: Data] = [:]

        for fileURL in flacFiles {
            let metadata = try FlacMetadataService.readTags(for: fileURL)
            let tags = metadata.tags
            let trackPicturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
            let bookmarkData = try fileURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)

            for (pictureType, pictureData) in trackPicturesByType where importedPicturesByType[pictureType] == nil {
                importedPicturesByType[pictureType] = pictureData
            }

            if importedTracks.isEmpty {
                let initialValues = FlacImportMapper.initialValues(from: tags)
                if let albumValue = initialValues.album {
                    album = albumValue
                }
                if let albumArtistValue = initialValues.albumArtist {
                    albumArtist = albumArtistValue
                }
                if let totalDiscsValue = initialValues.totalDiscs {
                    totalDiscs = totalDiscsValue
                }
            }

            let trackTags = FlacImportMapper.mapTrackTags(
                sourceTags: tags,
                fileURL: fileURL,
                defaultDate: .now
            )
            importedTracks.append(
                Track(
                    tags: trackTags,
                    flacPicturesByType: trackPicturesByType,
                    sourceFileURL: fileURL,
                    securityScopedBookmarkData: bookmarkData,
                    latestFileSnapshot: makeFileSnapshot(tags: tags, picturesByType: trackPicturesByType),
                    isLocked: locked
                )
            )
        }

        importedFlacPicturesByType = importedPicturesByType
        trackItems = importedTracks
        selectedTrackIDs.removeAll()
        reloadMiscTagRowsFromSelection()
    }

    func save(
        payload: SavePayloadOption,
        scope: SaveScopeOption,
        tagWriteOptions: TagWriteOptions,
        albumArtPictures: [FlacWritablePictureRecord],
        editorSessionID: UUID,
        progress: ((Int, Int, String) -> Void)? = nil
    ) async throws -> SaveOperationResult {
        let trackIndices = saveTrackIndices(for: scope)
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
                            album: album,
                            albumArtist: albumArtist,
                            totalTracks: trackItems.count,
                            totalDiscs: totalDiscs,
                            options: tagWriteOptions
                        )
                        : [:]

                    try FlacMetadataService.writeMetadata(
                        tags: tags,
                        pictures: payload.writesPictures ? albumArtPictures : [],
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
                        albumArtPictures: albumArtPictures
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
        let picturesByType = writablePicturesByType(from: albumArtPictures)

        for index in trackItems.indices {
            trackItems[index].latestFileSnapshot = TrackFileSnapshot(
                tags: expectedFileTags(forTrackAt: index, tagWriteOptions: tagWriteOptions),
                picturesByType: picturesByType
            )
            trackItems[index].externalDifferences = nil
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
        _ = try FlacMetadataService.readTags(for: fileURL)
        let picturesByType = writablePicturesByType(from: albumArtPictures)
        trackItems[index].latestFileSnapshot = TrackFileSnapshot(
            tags: expectedFileTags(forTrackAt: index, tagWriteOptions: tagWriteOptions),
            picturesByType: picturesByType
        )
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
            let fileSnapshot = makeFileSnapshot(
                tags: metadata.tags,
                picturesByType: FlacImportMapper.mapPicturesByType(metadata.pictures)
            )
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

    private func makeFileSnapshot(tags: [String: String], picturesByType: [Int: Data]) -> TrackFileSnapshot {
        TrackFileSnapshot(
            tags: normalizeFileTags(tags),
            picturesByType: picturesByType
        )
    }

    private func normalizeFileTags(_ tags: [String: String]) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: tags.compactMap { key, value in
                let normalizedKey = normalizedTagKey(key)
                guard !normalizedKey.isEmpty else {
                    return nil
                }
                return (normalizedKey, value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        )
    }

    private func expectedFileTags(forTrackAt index: Int, tagWriteOptions: TagWriteOptions) -> [String: String] {
        FlacWriteMapper.makeTags(
            for: trackItems[index],
            album: album,
            albumArtist: albumArtist,
            totalTracks: trackItems.count,
            totalDiscs: totalDiscs,
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

        let trimmedAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAlbum.isEmpty {
            tags["ALBUM"] = trimmedAlbum
        }

        let trimmedAlbumArtist = albumArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAlbumArtist.isEmpty {
            tags["ALBUMARTIST"] = trimmedAlbumArtist
        }

        let normalizedTotalTracks = totalTracks.trimmingCharacters(in: .whitespacesAndNewlines)
        for key in totalTrackTagKeys {
            if let fileValue = fileTags[key], !fileValue.isEmpty {
                tags[key] = formattedNumericComparisonValue(normalizedTotalTracks, matching: fileValue)
            }
        }

        let normalizedTotalDiscs = normalizedTotalDiscsValue.trimmingCharacters(in: .whitespacesAndNewlines)
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
        Dictionary(uniqueKeysWithValues: pictures.map { ($0.type, $0.data) })
    }

    private func differingFileValues(
        expectedTags: [String: String],
        fileTags: [String: String]
    ) -> [String: String] {
        let allKeys = Set(expectedTags.keys).union(fileTags.keys)
        var differences: [String: String] = [:]

        for key in allKeys {
            let expectedValue = expectedTags[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let fileValue = fileTags[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
            fileTags: fileSnapshot.tags
        )
        let hasPictureDifference = writablePicturesByType(from: albumArtPictures) != fileSnapshot.picturesByType

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

    private func differencesForTrack(
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
        let pictureDifferences = writablePicturesByType(from: albumArtPictures) != latestFileSnapshot.picturesByType

        let externalDifferences = trackItems[index].externalDifferences
        let hasExternalTagDifferences = !(externalDifferences?.fileValuesByTag.isEmpty ?? true)
        let hasExternalPictureDifferences = externalDifferences?.hasPictureDifference ?? false

        return (
            tagDifferences || hasExternalTagDifferences,
            pictureDifferences || hasExternalPictureDifferences
        )
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

    private func updateTrackFileURL(_ fileURL: URL, at index: Int) {
        trackItems[index].sourceFileURL = fileURL
        trackItems[index].securityScopedBookmarkData = try? fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
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
