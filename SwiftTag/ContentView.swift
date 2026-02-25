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
        let title: String
        let filename: String
    }

    @State private var artist: String = ""
    @State private var venue: String = ""
    @State private var date: Date = .now
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

            TableColumn("Title", value: \.title)

            TableColumn("Filename", value: \.filename)
        }
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

            tracks
        }
        .padding()
        .frame(minWidth: 520, minHeight: 320)
    }
}

#Preview {
    ContentView()
}
