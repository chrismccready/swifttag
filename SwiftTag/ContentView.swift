//
//  ContentView.swift
//  SwiftTag
//
//  Created by Christopher McCready on 2/24/26.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit
import ImageIO

struct ContentView: View {
    struct Track: Identifiable {
        let id: UUID
        var tags: [String: String]

        init(id: UUID = UUID(), tags: [String: String]) {
            self.id = id
            self.tags = tags
        }
    }

    struct MiscTagRow: Identifiable, Hashable {
        let id: UUID
        var key: String
        var value: String
    }

    private enum TagKey {
        static let number = "NUMBER"
        static let disc = "DISC"
        static let genre = "GENRE"
        static let title = "TITLE"
        static let filename = "FILENAME"
        static let artist = "ARTIST"
        static let composer = "COMPOSER"
        static let location = "LOCATION"
        static let date = "DATE"
        static let description = "DESCRIPTION"
    }

    private enum AlbumArtSlot: Hashable {
        case other
        case pngIcon
        case otherIcon
        case frontCover
        case backCover
        case leaflet
        case media
        case leadArtist
        case artist
        case conductor
        case band
        case composer
        case lyricist
        case recordingStudioOrLocation
        case recordingSession
        case performance
        case captureFromMovieOrVideo
        case brightlyColoredFish
        case illustration
        case bandLogo
        case publisherLogo
    }

    private struct AlbumArtType: Identifiable {
        let number: Int
        let navigationLinkName: String
        let slot: AlbumArtSlot

        var id: Int { number }
    }

    private struct AlbumArtImageAsset {
        let image: NSImage
        let type: UTType
    }

    private struct AlbumArtExportDocument: FileDocument {
        static var readableContentTypes: [UTType] { [.png, .jpeg] }

        let data: Data

        init(data: Data) {
            self.data = data
        }

        init(configuration: ReadConfiguration) throws {
            guard let data = configuration.file.regularFileContents else {
                throw CocoaError(.fileReadCorruptFile)
            }
            self.data = data
        }

        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            FileWrapper(regularFileWithContents: data)
        }
    }

    private let albumArtTypes: [AlbumArtType] = [
        AlbumArtType(number: 3, navigationLinkName: "Front Cover", slot: .frontCover),
        AlbumArtType(number: 4, navigationLinkName: "Back Cover", slot: .backCover),
        AlbumArtType(number: 5, navigationLinkName: "Leaflet", slot: .leaflet),
        AlbumArtType(number: 6, navigationLinkName: "Media", slot: .media),
        AlbumArtType(number: 7, navigationLinkName: "Lead Artist", slot: .leadArtist),
        AlbumArtType(number: 8, navigationLinkName: "Artist", slot: .artist),
        AlbumArtType(number: 9, navigationLinkName: "Conductor", slot: .conductor),
        AlbumArtType(number: 10, navigationLinkName: "Band", slot: .band),
        AlbumArtType(number: 11, navigationLinkName: "Composer", slot: .composer),
        AlbumArtType(number: 12, navigationLinkName: "Lyricist", slot: .lyricist),
        AlbumArtType(number: 13, navigationLinkName: "Recording Studio or Location", slot: .recordingStudioOrLocation),
        AlbumArtType(number: 14, navigationLinkName: "Recording Session", slot: .recordingSession),
        AlbumArtType(number: 15, navigationLinkName: "Performance", slot: .performance),
        AlbumArtType(number: 16, navigationLinkName: "Capture from Movie or Video", slot: .captureFromMovieOrVideo),
        AlbumArtType(number: 17, navigationLinkName: "Bright(ly) Colored Fish", slot: .brightlyColoredFish),
        AlbumArtType(number: 18, navigationLinkName: "Illustration", slot: .illustration),
        AlbumArtType(number: 19, navigationLinkName: "Band Logo", slot: .bandLogo),
        AlbumArtType(number: 20, navigationLinkName: "Publisher Logo", slot: .publisherLogo),
        AlbumArtType(number: 1, navigationLinkName: "32x32 PNG Icon", slot: .pngIcon),
        AlbumArtType(number: 2, navigationLinkName: "Other Icon", slot: .otherIcon),
        AlbumArtType(number: 0, navigationLinkName: "Other", slot: .other)
    ]

    private func albumArtType(for slot: AlbumArtSlot) -> AlbumArtType? {
        albumArtTypes.first { $0.slot == slot }
    }

    @State private var isTomlSheetPresented: Bool = false
    @State private var isFlacImporterPresented: Bool = false
    @State private var isImportErrorPresented: Bool = false
    @State private var isAlbumArtSheetPresented: Bool = false
    @State private var isAlbumArtFileImporterPresented: Bool = false
    @State private var isAlbumArtFileExporterPresented: Bool = false
    @State private var importErrorMessage: String = ""
    @State private var pendingAlbumArtSlotForImport: AlbumArtSlot?
    @State private var albumArtExportDocument: AlbumArtExportDocument?
    @State private var albumArtExportContentType: UTType = .png
    @State private var albumArtExportDefaultFileName: String = "Album Art"
    @State private var albumArtNavigationPath: [AlbumArtSlot] = []
    @State private var albumArtImages: [AlbumArtSlot: AlbumArtImageAsset] = [:]
    @State private var album: String = ""
    @State private var albumArtist: String = ""
    @State private var totalDiscs: String = ""
    @State private var selectedTrackIDs: Set<UUID> = []
    @State private var miscTagRows: [MiscTagRow] = []
    @State private var selectedMiscTagRowIDs: Set<MiscTagRow.ID> = []
    @State private var originalMiscTagKeyByRowID: [MiscTagRow.ID: String] = [:]
    @FocusState private var focusedMiscTagKeyRowID: MiscTagRow.ID?
    @State private var trackItems: [Track] = [
        Track(tags: [
            TagKey.number: "1",
            TagKey.title: "Intro",
            TagKey.filename: "01-intro.wav",
            TagKey.artist: "",
            TagKey.composer: "",
            TagKey.location: "",
            TagKey.date: formatDate(.now),
            TagKey.description: "Opening track"
        ]),
        Track(tags: [
            TagKey.number: "2",
            TagKey.title: "Verse",
            TagKey.filename: "02-verse.wav",
            TagKey.artist: "",
            TagKey.composer: "",
            TagKey.location: "",
            TagKey.date: formatDate(.now),
            TagKey.description: "Main section"
        ]),
        Track(tags: [
            TagKey.number: "3",
            TagKey.title: "Outro",
            TagKey.filename: "03-outro.wav",
            TagKey.artist: "",
            TagKey.composer: "",
            TagKey.location: "",
            TagKey.date: formatDate(.now),
            TagKey.description: "Closing section"
        ])
    ]


    private func titleBinding(for trackID: UUID) -> Binding<String>? {
        tagBinding(for: trackID, tagName: TagKey.title)
    }

    private func tagBinding(for trackID: UUID, tagName: String) -> Binding<String>? {
        guard let index = trackItems.firstIndex(where: { $0.id == trackID }) else {
            return nil
        }

        return Binding(
            get: { trackItems[index].tags[tagName] ?? "" },
            set: { newValue in
                trackItems[index].tags[tagName] = newValue
            }
        )
    }

    private func selectedTagBinding(tagName: String) -> Binding<String>? {
        guard !selectedTrackIDs.isEmpty else {
            return nil
        }

        return Binding(
            get: {
                let selectedValues = trackItems
                    .filter { selectedTrackIDs.contains($0.id) }
                    .map { $0.tags[tagName] ?? "" }

                guard let firstValue = selectedValues.first else {
                    return ""
                }

                let allMatch = selectedValues.allSatisfy { $0 == firstValue }
                return allMatch ? firstValue : ""
            },
            set: { newValue in
                for index in trackItems.indices where selectedTrackIDs.contains(trackItems[index].id) {
                    trackItems[index].tags[tagName] = newValue
                }
            }
        )
    }

    private var selectedDateBinding: Binding<Date>? {
        guard !selectedTrackIDs.isEmpty else {
            return nil
        }

        return Binding(
            get: {
                let firstSelectedDate = trackItems
                    .first(where: { selectedTrackIDs.contains($0.id) })?
                    .tags[TagKey.date]
                return parseDate(from: firstSelectedDate) ?? .now
            },
            set: { newValue in
                for index in trackItems.indices where selectedTrackIDs.contains(trackItems[index].id) {
                    trackItems[index].tags[TagKey.date] = formatDate(newValue)
                }
            }
        )
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

    private var totalTrackTagKeys: [String] {
        ["TOTALTRACKS", "TRACKTOTAL"]
    }

    private var totalTracks: String {
        String(trackItems.count)
    }

    private var hasTotalTracksMismatch: Bool {
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

    private var totalTracksHoverMessage: String {
        if hasTotalTracksMismatch {
            return "Track count mismatch: one or more TOTALTRACKS/TRACKTOTAL tag values do not match the current album track count. This value will overwrite any existing values."
        }

        return "Album track count is \(totalTracks)."
    }

    private var normalizedTotalDiscsValue: String {
        Int(totalDiscs).map(String.init) ?? totalDiscs
    }

    private var hasTotalDiscsMismatch: Bool {
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

    private var totalDiscsHoverMessage: String {
        if hasTotalDiscsMismatch {
            return "Disc count mismatch: one or more TOTALDISCS tag values do not match this total discs value."
        }

        if totalDiscs.isEmpty {
            return "Set total discs. Empty TOTALDISCS values are ignored."
        }

        return "Album disc count is \(normalizedTotalDiscsValue)."
    }

    private var explicitTagKeys: Set<String> {
        [
            TagKey.number,
            TagKey.disc,
            TagKey.genre,
            TagKey.title,
            TagKey.filename,
            TagKey.artist,
            TagKey.composer,
            TagKey.location,
            TagKey.date,
            TagKey.description,
            "ALBUM",
            "TRACK",
            "TRACKNUMBER",
            "TOTALTRACKS",
            "TRACKTOTAL",
            "DISCNUMBER",
            "TOTALDISCS"
        ]
    }

    private func normalizedTagKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func isExplicitTagKey(_ value: String) -> Bool {
        explicitTagKeys.contains(normalizedTagKey(value))
    }

    private var miscTags: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Misc Tags")
                Spacer()
                Button {
                    addMiscTagRow()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add Tag")
                .accessibilityIdentifier("miscTags.addButton")

                Button {
                    deleteSelectedMiscTagRows()
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .help("Delete Selected Tags")
                .disabled(selectedMiscTagRowIDs.isEmpty)
                .accessibilityIdentifier("miscTags.deleteButton")
            }

            Table(miscTagRows, selection: $selectedMiscTagRowIDs) {
                TableColumn("Key") { row in
                    if let keyBinding = miscTagKeyBinding(for: row.id) {
                        TextField("Key", text: keyBinding)
                            .foregroundStyle(isInvalidMiscTagKeyInput(row.key, for: row.id) ? .red : .primary)
                            .focused($focusedMiscTagKeyRowID, equals: row.id)
                            .accessibilityIdentifier("miscTags.keyField.\(row.id.uuidString)")
                    }
                }
                .width(min: 120)

                TableColumn("Value") { row in
                    if let valueBinding = miscTagValueBinding(for: row.id) {
                        TextField("Value", text: valueBinding)
                    }
                }
                .width(min: 160)
            }
            .frame(minHeight: 80, maxHeight: 176)
            .accessibilityIdentifier("miscTags.table")
        }
        .padding(.top, 6)
    }

    private func reloadMiscTagRowsFromSelection() {
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

    private func setMiscTagValueForSelectedTracks(key: String, value: String) {
        let normalizedKey = normalizedTagKey(key)
        guard !normalizedKey.isEmpty, !isExplicitTagKey(normalizedKey) else {
            return
        }

        for index in trackItems.indices where selectedTrackIDs.contains(trackItems[index].id) {
            trackItems[index].tags[normalizedKey] = value
        }
    }

    private func addMiscTagRow() {
        let newRow = MiscTagRow(id: UUID(), key: "", value: "")
        miscTagRows.append(newRow)
        selectedMiscTagRowIDs = [newRow.id]
        DispatchQueue.main.async {
            focusedMiscTagKeyRowID = newRow.id
        }
    }

    private func deleteSelectedMiscTagRows() {
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

    private func miscTagKeyBinding(for rowID: MiscTagRow.ID) -> Binding<String>? {
        guard let rowIndex = miscTagRows.firstIndex(where: { $0.id == rowID }) else {
            return nil
        }

        return Binding(
            get: { miscTagRows[rowIndex].key },
            set: { newValue in
                miscTagRows[rowIndex].key = newValue
            }
        )
    }

    private func isDuplicateMiscTagKey(_ normalizedKey: String, excluding rowID: MiscTagRow.ID) -> Bool {
        guard !normalizedKey.isEmpty else {
            return false
        }

        return miscTagRows.contains { row in
            row.id != rowID && normalizedTagKey(row.key) == normalizedKey
        }
    }

    private func isInvalidMiscTagKeyInput(_ rawKey: String, for rowID: MiscTagRow.ID) -> Bool {
        let normalizedKey = normalizedTagKey(rawKey)
        guard !normalizedKey.isEmpty else {
            return false
        }

        return isExplicitTagKey(normalizedKey) || isDuplicateMiscTagKey(normalizedKey, excluding: rowID)
    }

    private func recordOriginalMiscTagKeyIfNeeded(for rowID: MiscTagRow.ID) {
        guard originalMiscTagKeyByRowID[rowID] == nil,
              let row = miscTagRows.first(where: { $0.id == rowID }) else {
            return
        }

        originalMiscTagKeyByRowID[rowID] = normalizedTagKey(row.key)
    }

    private func finalizeMiscTagKeyEditing(for rowID: MiscTagRow.ID) {
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

    private func miscTagValueBinding(for rowID: MiscTagRow.ID) -> Binding<String>? {
        guard let rowIndex = miscTagRows.firstIndex(where: { $0.id == rowID }) else {
            return nil
        }

        return Binding(
            get: { miscTagRows[rowIndex].value },
            set: { newValue in
                miscTagRows[rowIndex].value = newValue
                setMiscTagValueForSelectedTracks(key: miscTagRows[rowIndex].key, value: newValue)
            }
        )
    }

    private func positiveIntegerStringBinding(_ source: Binding<String>) -> Binding<String> {
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

    private func tomlText() -> String {
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
            await importFlacFiles(flacFiles)
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

    private func importFlacFiles(_ flacFiles: [URL]) async {
        guard !flacFiles.isEmpty else {
            return
        }

        var importedTracks: [Track] = []

        for fileURL in flacFiles {
            let tags: [String: String]
            do {
                tags = try FlacMetadataService.readTags(for: fileURL).tags
            } catch {
                importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isImportErrorPresented = true
                return
            }

            let fileTitle = fileURL.deletingPathExtension().lastPathComponent
            let title = tags["TITLE"]?.isEmpty == false ? tags["TITLE"]! : fileTitle

            let description = tags["DESCRIPTION"] ?? tags["COMMENT"] ?? ""
            let location = tags["LOCATION"] ?? tags["VENUE"] ?? ""
            let genre = tags["GENRE"] ?? ""

            if importedTracks.isEmpty {
                if let albumTag = tags["ALBUM"], !albumTag.isEmpty {
                    album = albumTag
                }

                let albumArtistTag = tags["ALBUMARTIST"] ?? tags["ALBUM ARTIST"]
                if let albumArtistTag, !albumArtistTag.isEmpty {
                    albumArtist = albumArtistTag
                }

                let rawTotalDiscs = tags["TOTALDISCS"] ?? ""
                let normalizedTotalDiscs = Int(rawTotalDiscs).map(String.init) ?? rawTotalDiscs
                if !normalizedTotalDiscs.isEmpty {
                    totalDiscs = normalizedTotalDiscs
                }
            }

            let rawTrackNumber = tags["TRACKNUMBER"] ?? tags["TRACK"] ?? ""
            let normalizedTrackNumber = Int(rawTrackNumber).map(String.init) ?? rawTrackNumber
            let rawDiscNumber = tags["DISCNUMBER"] ?? tags["DISC"] ?? ""
            let normalizedDiscNumber = Int(rawDiscNumber).map(String.init) ?? rawDiscNumber

            var trackTags = tags
            trackTags[TagKey.number] = normalizedTrackNumber
            trackTags[TagKey.disc] = normalizedDiscNumber
            trackTags[TagKey.genre] = genre
            trackTags[TagKey.title] = title
            trackTags[TagKey.filename] = fileURL.lastPathComponent
            trackTags[TagKey.artist] = tags["ARTIST"] ?? ""
            trackTags[TagKey.composer] = tags["COMPOSER"] ?? ""
            trackTags[TagKey.location] = location
            trackTags[TagKey.date] = formatDate(parseDate(from: tags["DATE"]) ?? .now)
            trackTags[TagKey.description] = description

            importedTracks.append(Track(tags: trackTags))
        }

        trackItems.append(contentsOf: importedTracks)
        reloadMiscTagRowsFromSelection()
    }

    private func parseDate(from value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "yyyy-MM", "yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        Self.formatDate(date)
    }

    var tracks: some View {
        Table(trackItems, selection: $selectedTrackIDs) {
            TableColumn("Title") { track in
                if let title = titleBinding(for: track.id) {
                    TextField("Title", text: title)
                }
            }
            .width(min: 140, max: 800)

            TableColumn("Filename") { track in
                Text(track.tags[TagKey.filename] ?? "")
            }
                .width(min: 52)
        }
        .frame(minHeight: 64, idealHeight: .infinity)
    }

    private func imageForAlbumArtSlot(_ albumArtSlot: AlbumArtSlot) -> Image {
        if let asset = albumArtImages[albumArtSlot] {
            return Image(nsImage: asset.image)
        }

        return Image(systemName: "photo.badge.plus")
    }

    private func setAlbumArtImage(_ image: NSImage, type: UTType, for albumArtSlot: AlbumArtSlot) {
        albumArtImages[albumArtSlot] = AlbumArtImageAsset(image: image, type: type)
    }

    private func albumArtType(for fileURL: URL) -> UTType {
        guard let type = UTType(filenameExtension: fileURL.pathExtension.lowercased()) else {
            return .png
        }

        if type.conforms(to: .jpeg) {
            return .jpeg
        }

        if type.conforms(to: .png) {
            return .png
        }

        return .png
    }

    private func albumArtType(for imageData: Data) -> UTType {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let sourceType = CGImageSourceGetType(source),
              let type = UTType(sourceType as String) else {
            return .png
        }

        if type.conforms(to: .jpeg) {
            return .jpeg
        }

        if type.conforms(to: .png) {
            return .png
        }

        return .png
    }

    private func imageData(from image: NSImage, as type: UTType) -> Data? {
        guard let tiffRepresentation = image.tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }

        let bitmapFileType: NSBitmapImageRep.FileType = type.conforms(to: .jpeg) ? .jpeg : .png
        return bitmapRepresentation.representation(using: bitmapFileType, properties: [:])
    }

    private func prepareAlbumArtExport(for albumArtSlot: AlbumArtSlot) {
        guard let asset = albumArtImages[albumArtSlot] else {
            return
        }

        let exportType: UTType = asset.type.conforms(to: .jpeg) ? .jpeg : .png
        let fileExtension = exportType.preferredFilenameExtension ?? (exportType.conforms(to: .jpeg) ? "jpg" : "png")
        let baseName = albumArtType(for: albumArtSlot)?.navigationLinkName ?? "Album Art"
        guard let data = imageData(from: asset.image, as: exportType) else {
            return
        }

        albumArtExportDocument = AlbumArtExportDocument(data: data)
        albumArtExportContentType = exportType
        albumArtExportDefaultFileName = "\(baseName).\(fileExtension)"
        isAlbumArtFileExporterPresented = true
    }

    private func handleAlbumArtFileExportResult(_ result: Result<URL, Error>) {
        albumArtExportDocument = nil
    }

    private func droppedFileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }

        if let text = item as? String {
            return URL(string: text)
        }

        if let text = item as? NSString {
            return URL(string: text as String)
        }

        return nil
    }

    private func handleAlbumArtDrop(_ providers: [NSItemProvider], for albumArtSlot: AlbumArtSlot) -> Bool {
        if let imageProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            imageProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data, let image = NSImage(data: data) else {
                    return
                }

                DispatchQueue.main.async {
                    setAlbumArtImage(image, type: albumArtType(for: data), for: albumArtSlot)
                }
            }
            return true
        }

        if let fileProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            fileProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = droppedFileURL(from: item),
                      let image = NSImage(contentsOf: url) else {
                    return
                }

                DispatchQueue.main.async {
                    setAlbumArtImage(image, type: albumArtType(for: url), for: albumArtSlot)
                }
            }
            return true
        }

        return false
    }

    private func handleAlbumArtFileImportResult(_ result: Result<[URL], Error>) {
        defer {
            pendingAlbumArtSlotForImport = nil
        }

        guard case .success(let urls) = result,
              let selectedURL = urls.first,
              let pendingAlbumArtSlotForImport,
              selectedURL.startAccessingSecurityScopedResource() else {
            return
        }

        defer {
            selectedURL.stopAccessingSecurityScopedResource()
        }

        guard let image = NSImage(contentsOf: selectedURL) else {
            return
        }

        setAlbumArtImage(image, type: albumArtType(for: selectedURL), for: pendingAlbumArtSlotForImport)
    }

    private func openAlbumArtFilePicker(for albumArtSlot: AlbumArtSlot) {
        pendingAlbumArtSlotForImport = albumArtSlot
        DispatchQueue.main.async {
            isAlbumArtFileImporterPresented = true
        }
    }

    private func albumArtWell(for albumArtSlot: AlbumArtSlot, dimension: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.secondary, lineWidth: 1)

            imageForAlbumArtSlot(albumArtSlot)
                .resizable()
                .scaledToFit()
                .padding(4)
        }
        .frame(width: dimension, height: dimension)
        .onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: nil) { providers in
            handleAlbumArtDrop(providers, for: albumArtSlot)
        }
    }

    private var albumArtSheet: some View {
        NavigationStack(path: $albumArtNavigationPath) {
            List {
                ForEach(albumArtTypes) { albumArtType in
                    NavigationLink(albumArtType.navigationLinkName, value: albumArtType.slot)
                }
            }
            .navigationTitle("Album Art")
            .navigationDestination(for: AlbumArtSlot.self) { albumArtSlot in
                VStack(alignment: .leading, spacing: 0) {
                    albumArtWell(for: albumArtSlot, dimension: 480)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openAlbumArtFilePicker(for: albumArtSlot)
                        }
                        .contextMenu {
                            let navigationLinkName = albumArtType(for: albumArtSlot)?.navigationLinkName ?? "Album Art"
                            Button("Import \(navigationLinkName)...") {
                                openAlbumArtFilePicker(for: albumArtSlot)
                            }
                            Button("Export \(navigationLinkName)...") {
                                prepareAlbumArtExport(for: albumArtSlot)
                            }
                            .disabled(albumArtImages[albumArtSlot] == nil)
                        }
                        .help("Click to select or drag and drop album \(albumArtType(for: albumArtSlot)?.navigationLinkName ?? "art") image.")
                }
                .padding(22)
                .navigationTitle(albumArtType(for: albumArtSlot)?.navigationLinkName ?? "Album Art")
            }
        }
        .frame(width: 524, height: 572)
        .onAppear {
            if albumArtNavigationPath.isEmpty {
                albumArtNavigationPath = [.frontCover]
            }
        }
        .fileImporter(
            isPresented: $isAlbumArtFileImporterPresented,
            allowedContentTypes: [.jpeg, .png],
            allowsMultipleSelection: false,
            onCompletion: handleAlbumArtFileImportResult
        )
        .fileExporter(
            isPresented: $isAlbumArtFileExporterPresented,
            document: albumArtExportDocument,
            contentType: albumArtExportContentType,
            defaultFilename: albumArtExportDefaultFileName,
            onCompletion: handleAlbumArtFileExportResult
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Album")
                        TextField("Album", text: $album)
                            .accessibilityIdentifier("albumTextField")
                    }

                    HStack {
                        Text("Album Artist")
                        TextField("Album Artist", text: $albumArtist)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                albumArtWell(for: .frontCover, dimension: 60)
                .contentShape(Rectangle())
                .onTapGesture {
                    isAlbumArtSheetPresented = true
                }
                .help("Click to edit album art or drag and drop an image to set album Front Cover.")
                .accessibilityIdentifier("albumArtImageWell")
            }

            tracks

            HStack(spacing: 6) {
                Text("Number")
                if let selectedNumber = selectedNumberBinding {
                    TextField("Number", text: positiveIntegerStringBinding(selectedNumber))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                } else {
                    TextField("#", text: .constant(""))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .disabled(true)
                }
                Text("of")
                Text(totalTracks)
                    .fontWeight(hasTotalTracksMismatch ? .bold : .regular)
                    .foregroundStyle(hasTotalTracksMismatch ? .red : .primary)
                    .multilineTextAlignment(.center)
                    .help(totalTracksHoverMessage)
                    .padding(.trailing, 14)

                Text("Disc")
                if let selectedDisc = selectedDiscBinding {
                    TextField("#", text: positiveIntegerStringBinding(selectedDisc))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                } else {
                    TextField("#", text: .constant(""))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .disabled(true)
                }
                Text("of")
                TextField("#", text: positiveIntegerStringBinding($totalDiscs))
                    .fontWeight(hasTotalDiscsMismatch ? .bold : .regular)
                    .foregroundStyle(hasTotalDiscsMismatch ? .red : .primary)
                    .multilineTextAlignment(.center)
                    .frame(width: 30)
                    .help(totalDiscsHoverMessage)
                    .padding(.trailing, 40)

                Text("Genre")
                if let selectedGenre = selectedGenreBinding {
                    TextField("Genre", text: selectedGenre)
                } else {
                    TextField("Genre", text: .constant("Select track(s) to edit genre."))
                        .disabled(true)
                }
            }

            HStack {
                Text("Artist")
                if let selectedArtist = selectedArtistBinding {
                    TextField("Artist", text: selectedArtist)
                } else {
                    TextField("Artist", text: .constant("Select track(s) to edit artist."))
                        .disabled(true)
                }
            }

            HStack {
                Text("Composer")
                if let selectedComposer = selectedComposerBinding {
                    TextField("Composer", text: selectedComposer)
                } else {
                    TextField("Composer", text: .constant("Select track(s) to edit composer."))
                        .disabled(true)
                }
            }

            HStack {
                Text("Location")
                if let selectedLocation = selectedLocationBinding {
                    TextField("Location", text: selectedLocation)
                } else {
                    TextField("Location", text: .constant("Select track(s) to edit location."))
                        .disabled(true)
                }

                Text("Date")
                if let selectedDate = selectedDateBinding {
                    TextField("Date", value: selectedDate, format: .dateTime.year().month().day())
                        .frame(width: 130)
                } else {
                    TextField("Date", value: .constant(.now), format: .dateTime.year().month().day())
                        .frame(width: 130)
                        .disabled(true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                    if let selectedDescriptions = selectedDescriptionsBinding {
                        TextEditor(text: selectedDescriptions)
                            .frame(minHeight: 60, idealHeight: 60)
                    } else {
                        TextEditor(text: .constant("Select track(s) to edit description."))
                            .frame(minHeight: 60, idealHeight: 60)
                            .disabled(true)
                    }
                }
            }
            .frame(height: 60)

            miscTags

        }
        .padding()
        .frame(minWidth: 520, minHeight: 530, idealHeight: 640, alignment: .topLeading)
        .onAppear {
            reloadMiscTagRowsFromSelection()
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
            albumArtSheet
        }
        .alert("FLAC Import Error", isPresented: $isImportErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
    }
}

struct TOMLUtilityView: View {
    @Environment(\.dismiss) private var dismiss
    let tomlText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: .constant(tomlText))
                .font(.body.monospaced())
                .frame(minWidth: 500, minHeight: 400)

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
        }
        .padding()
    }
}

extension FocusedValues {
    @Entry var showTomlSheet: (() -> Void)?
    @Entry var showFlacImporter: (() -> Void)?
}

#Preview {
    ContentView()
}
