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
    }

    @State private var artist: String = ""
    @State private var venue: String = ""
    @State private var date: Date = .now
    @State private var description: String = ""
    @State private var trackItems: [Track] = [
        Track(number: 1, title: "Intro", filename: "01-intro.wav"),
        Track(number: 2, title: "Verse", filename: "02-verse.wav"),
        Track(number: 3, title: "Outro", filename: "03-outro.wav")
    ]

    var tracks: some View {
        Table(trackItems) {
            TableColumn("Number") { track in
                Text("\(track.number)")
            }
            .width(80)

            TableColumn("Title") { track in
                if let title = titleBinding(for: track.id) {
                    TextField("Title", text: title)
                }
            }

            TableColumn("Filename", value: \.filename)
        }
        .frame(minHeight: 104)
    }

    private func titleBinding(for trackID: UUID) -> Binding<String>? {
        guard let index = trackItems.firstIndex(where: { $0.id == trackID }) else {
            return nil
        }

        return $trackItems[index].title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Artist")
                TextField("Artist", text: $artist)
            }

            HStack {
                Text("Venue")
                TextField("Venue", text: $venue)

                Text("Date")
                TextField("Date", value: $date, format: .dateTime.year().month().day())
            }

            VSplitView {
                tracks

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                        TextEditor(text: $description)
                            .frame(minHeight: 60, idealHeight: 80)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cover")
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.quaternary)

                            VStack(spacing: 6) {
                                Image(systemName: "photo")
                                Text("Image Well")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .frame(width: 100, height: 100)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 520, idealHeight: 620)
    }
}

#Preview {
    ContentView()
}
