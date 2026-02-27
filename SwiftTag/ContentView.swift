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
        let id = UUID()
        let number: Int
        var title: String
        let filename: String
        var artist: String
        var composer: String
        var location: String
        var date: Date
        var description: String
    }

    @State private var isTomlSheetPresented: Bool = false
    @State private var isFlacImporterPresented: Bool = false
    @State private var isImportErrorPresented: Bool = false
    @State private var importErrorMessage: String = ""
    @State private var album: String = ""
    @State private var albumArtist: String = ""
    @State private var selectedTrackIDs: Set<UUID> = []
    @State private var trackItems: [Track] = [
        Track(number: 1, title: "Intro", filename: "01-intro.wav", artist: "", composer: "", location: "", date: .now, description: "Opening track"),
        Track(number: 2, title: "Verse", filename: "02-verse.wav", artist: "", composer: "", location: "", date: .now, description: "Main section"),
        Track(number: 3, title: "Outro", filename: "03-outro.wav", artist: "", composer: "", location: "", date: .now, description: "Closing section")
    ]

    var tracks: some View {
        Table(trackItems, selection: $selectedTrackIDs) {
            TableColumn("#") { track in
                Text("\(track.number)")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(16)

            TableColumn("Title") { track in
                if let title = titleBinding(for: track.id) {
                    TextField("Title", text: title)
                }
            }
            .width(min: 140, max: 800)

            TableColumn("Filename", value: \.filename)
                .width(min: 52)
        }
        .frame(minHeight: 104, idealHeight: .infinity)
    }

    private func titleBinding(for trackID: UUID) -> Binding<String>? {
        guard let index = trackItems.firstIndex(where: { $0.id == trackID }) else {
            return nil
        }

        return $trackItems[index].title
    }

    private func selectedStringBinding(for keyPath: WritableKeyPath<Track, String>) -> Binding<String>? {
        guard !selectedTrackIDs.isEmpty else {
            return nil
        }

        return Binding(
            get: {
                let selectedValues = trackItems
                    .filter { selectedTrackIDs.contains($0.id) }
                    .map { $0[keyPath: keyPath] }

                guard let firstValue = selectedValues.first else {
                    return ""
                }

                let allMatch = selectedValues.allSatisfy { $0 == firstValue }
                return allMatch ? firstValue : ""
            },
            set: { newValue in
                for index in trackItems.indices where selectedTrackIDs.contains(trackItems[index].id) {
                    trackItems[index][keyPath: keyPath] = newValue
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
                trackItems.first(where: { selectedTrackIDs.contains($0.id) })?.date ?? .now
            },
            set: { newValue in
                for index in trackItems.indices where selectedTrackIDs.contains(trackItems[index].id) {
                    trackItems[index].date = newValue
                }
            }
        )
    }

    private var selectedArtistBinding: Binding<String>? {
        selectedStringBinding(for: \.artist)
    }

    private var selectedComposerBinding: Binding<String>? {
        selectedStringBinding(for: \.composer)
    }

    private var selectedLocationBinding: Binding<String>? {
        selectedStringBinding(for: \.location)
    }

    private var selectedDescriptionsBinding: Binding<String>? {
        selectedStringBinding(for: \.description)
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

        for track in trackItems.sorted(by: { $0.number < $1.number }) {
            lines.append("[[tracks]]")
            lines.append("number = \(track.number)")
            lines.append("title = '''\(track.title)'''")
            lines.append("filename = '''\(track.filename)'''")
            lines.append("artist = '''\(track.artist)'''")
            lines.append("composer = '''\(track.composer)'''")
            lines.append("location = '''\(track.location)'''")
            lines.append("date = \(dateFormatter.string(from: track.date))")
            lines.append("description = '''\(track.description)'''")
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

        let nextTrackNumber = (trackItems.map(\.number).max() ?? 0) + 1
        var importedTracks: [Track] = []

        for (index, fileURL) in flacFiles.enumerated() {
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

            let parsedDate = parseDate(from: tags["DATE"]) ?? .now
            let description = tags["DESCRIPTION"] ?? tags["COMMENT"] ?? ""
            let location = tags["LOCATION"] ?? tags["VENUE"] ?? ""

            if index == 0 {
                if let albumTag = tags["ALBUM"], !albumTag.isEmpty {
                    album = albumTag
                }

                let albumArtistTag = tags["ALBUMARTIST"] ?? tags["ALBUM ARTIST"]
                if let albumArtistTag, !albumArtistTag.isEmpty {
                    albumArtist = albumArtistTag
                }
            }

            importedTracks.append(
                Track(
                    number: nextTrackNumber + index,
                    title: title,
                    filename: fileURL.lastPathComponent,
                    artist: tags["ARTIST"] ?? "",
                    composer: tags["COMPOSER"] ?? "",
                    location: location,
                    date: parsedDate,
                    description: description
                )
            )
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
