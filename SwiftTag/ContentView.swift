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
    struct Track: Identifiable {
        let id: UUID
        var tags: [String: String]

        init(id: UUID = UUID(), tags: [String: String]) {
            self.id = id
            self.tags = tags
        }
    }

    private enum TagKey {
        static let number = "NUMBER"
        static let title = "TITLE"
        static let filename = "FILENAME"
        static let artist = "ARTIST"
        static let composer = "COMPOSER"
        static let location = "LOCATION"
        static let date = "DATE"
        static let description = "DESCRIPTION"
    }

    @State private var isTomlSheetPresented: Bool = false
    @State private var isFlacImporterPresented: Bool = false
    @State private var isImportErrorPresented: Bool = false
    @State private var importErrorMessage: String = ""
    @State private var album: String = ""
    @State private var albumArtist: String = ""
    @State private var totalTracks: String = ""
    @State private var selectedTrackIDs: Set<UUID> = []
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
        .frame(minHeight: 104, idealHeight: .infinity)
    }

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

            if importedTracks.isEmpty {
                if let albumTag = tags["ALBUM"], !albumTag.isEmpty {
                    album = albumTag
                }

                let albumArtistTag = tags["ALBUMARTIST"] ?? tags["ALBUM ARTIST"]
                if let albumArtistTag, !albumArtistTag.isEmpty {
                    albumArtist = albumArtistTag
                }
            }

            let rawTrackNumber = tags["TRACKNUMBER"] ?? tags["TRACK"] ?? ""
            let normalizedTrackNumber = Int(rawTrackNumber).map(String.init) ?? rawTrackNumber

            var trackTags = tags
            trackTags[TagKey.number] = normalizedTrackNumber
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Album")
                TextField("Album", text: $album)
            }

            HStack {
                Text("Album Artist")
                TextField("Album Artist", text: $albumArtist)
            }

            tracks

            HStack(spacing: 6) {
                Text("Number")
                if let selectedNumber = selectedNumberBinding {
                    TextField("Number", text: positiveIntegerStringBinding(selectedNumber))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                } else {
                    TextField("Number", text: .constant(""))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .disabled(true)
                }
                Text("of")
                TextField("", text: positiveIntegerStringBinding($totalTracks))
                    .multilineTextAlignment(.center)
                    .frame(width: 30)
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
                .padding(.top, 8)
            }
            .frame(height: 92)

        }
        .padding()
        .frame(minWidth: 520, minHeight: 520, idealHeight: 620)
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
