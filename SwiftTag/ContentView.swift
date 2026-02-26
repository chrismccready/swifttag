//
//  ContentView.swift
//  SwiftTag
//
//  Created by Christopher McCready on 2/24/26.
//

import SwiftUI

struct ContentView: View {
    struct Track: Identifiable {
        let id = UUID()
        let number: Int
        var title: String
        let filename: String
        var description: String
    }

    @State private var artist: String = ""
    @State private var venue: String = ""
    @State private var album: String = ""
    @State private var date: Date = .now
    @State private var selectedTrackID: UUID?
    @State private var trackItems: [Track] = [
        Track(number: 1, title: "Intro", filename: "01-intro.wav", description: "Opening track"),
        Track(number: 2, title: "Verse", filename: "02-verse.wav", description: "Main section"),
        Track(number: 3, title: "Outro", filename: "03-outro.wav", description: "Closing section")
    ]

    var tracks: some View {
        Table(trackItems, selection: $selectedTrackID) {
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

    private func descriptionBinding(for trackID: UUID?) -> Binding<String>? {
        guard let trackID,
              let index = trackItems.firstIndex(where: { $0.id == trackID }) else {
            return nil
        }

        return $trackItems[index].description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Artist")
                TextField("Artist", text: $artist)
            }

            HStack {
                Text("Venue")
                TextField("Venue", text: $venue)

                Text("Date")
                TextField("Date", value: $date, format: .dateTime.year().month().day())
                    .frame(width: 130)
            }

            HStack {
                Text("Album")
                TextField("Album", text: $album)
            }

            tracks

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                    if let selectedDescription = descriptionBinding(for: selectedTrackID) {
                        TextEditor(text: selectedDescription)
                            .frame(minHeight: 60, idealHeight: 60)
                    } else {
                        TextEditor(text: .constant("Select a track to edit its description."))
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
    }
}

#Preview {
    ContentView()
}
