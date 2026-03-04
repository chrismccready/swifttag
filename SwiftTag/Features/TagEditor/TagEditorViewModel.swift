import Foundation
import Observation
import SwiftUI

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

    private let totalTrackTagKeys: [String] = ["TOTALTRACKS", "TRACKTOTAL"]

    init() {
        trackItems = [
            Track(tags: [
                TagKey.number: "1",
                TagKey.title: "Intro",
                TagKey.filename: "01-intro.wav",
                TagKey.artist: "",
                TagKey.composer: "",
                TagKey.location: "",
                TagKey.date: DateTagFormatter.format(.now),
                TagKey.description: "Opening track"
            ]),
            Track(tags: [
                TagKey.number: "2",
                TagKey.title: "Verse",
                TagKey.filename: "02-verse.wav",
                TagKey.artist: "",
                TagKey.composer: "",
                TagKey.location: "",
                TagKey.date: DateTagFormatter.format(.now),
                TagKey.description: "Main section"
            ]),
            Track(tags: [
                TagKey.number: "3",
                TagKey.title: "Outro",
                TagKey.filename: "03-outro.wav",
                TagKey.artist: "",
                TagKey.composer: "",
                TagKey.location: "",
                TagKey.date: DateTagFormatter.format(.now),
                TagKey.description: "Closing section"
            ])
        ]
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
                self.trackItems[index].tags[tagName] = newValue
            }
        )
    }

    func selectedTagBinding(tagName: String) -> Binding<String>? {
        guard !selectedTrackIDs.isEmpty else {
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
                    self.trackItems[index].tags[tagName] = newValue
                }
            }
        )
    }

    func selectedDateBinding() -> Binding<Date>? {
        guard !selectedTrackIDs.isEmpty else {
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
        guard !selectedMiscTagRowIDs.isEmpty else {
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
            let lhs = Int($0.tags[TagKey.number] ?? "") ?? 0
            let rhs = Int($1.tags[TagKey.number] ?? "") ?? 0
            if lhs == rhs {
                return ($0.tags[TagKey.title] ?? "") < ($1.tags[TagKey.title] ?? "")
            }
            return lhs < rhs
        }

        for track in sortedTracks {
            lines.append("[[tracks]]")
            lines.append("number = \(track.tags[TagKey.number] ?? "0")")
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

    func importFlacFiles(_ flacFiles: [URL]) async throws {
        guard !flacFiles.isEmpty else {
            return
        }

        var importedTracks: [Track] = []

        for fileURL in flacFiles {
            let tags = try FlacMetadataService.readTags(for: fileURL).tags

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
            importedTracks.append(Track(tags: trackTags))
        }

        trackItems.append(contentsOf: importedTracks)
        reloadMiscTagRowsFromSelection()
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
}
