import SwiftUI

struct TagEditorTrackView: View {
    let trackItems: [Track]
    var selection: Binding<Set<UUID>>
    let titleBindingForTrack: (UUID) -> Binding<String>?

    var body: some View {
        Table(trackItems, selection: selection) {
            TableColumn("Title") { track in
                if let title = titleBindingForTrack(track.id) {
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
}
