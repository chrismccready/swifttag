import SwiftUI

struct TagEditorTrackFileView: View {
    let trackItems: [Track]
    var selection: Binding<Set<UUID>>
    let titleBindingForTrack: (UUID) -> Binding<String>?
    let statusPresentationForTrack: (UUID) -> TrackStatusPresentation?
    let isTrackLocked: (UUID) -> Bool
    let hasDeletedFile: (UUID) -> Bool
    let hasTrackToTrackTitleDifference: (UUID) -> Bool
    let hasTrackToFileTitleDifference: (UUID) -> Bool
    let hasExternallyModifiedTitleDifference: (UUID) -> Bool
    let onToggleLockSelection: () -> Void
    let lockMenuTitle: String
    let canToggleLockSelection: Bool

    var body: some View {
        Table(trackItems, selection: selection) {
            TableColumn("") { track in
                if let statusPresentation = statusPresentationForTrack(track.id) {
                    Image(systemName: statusPresentation.systemImageName)
                        .help(statusPresentation.help ?? "")
                        .foregroundStyle(.primary)
                        .frame(minHeight: 20, alignment: .center)
                }
            }
            .width(16)

            TableColumn("Title") { track in
                if let title = titleBindingForTrack(track.id) {
                    TextField("Title", text: title)
                        .tagDiffStyle(
                            tag: .title,
                            hasTrackToTrackDifference: hasTrackToTrackTitleDifference(track.id),
                            hasTrackToFileDifference: hasTrackToFileTitleDifference(track.id),
                            hasExternallyModifiedDifference: hasExternallyModifiedTitleDifference(track.id)
                        )
                        .disabled(isTrackLocked(track.id))
                } else {
                    Text(track.tags[TagKey.title] ?? "")
                        .tagDiffStyle(
                            tag: .title,
                            hasTrackToTrackDifference: hasTrackToTrackTitleDifference(track.id),
                            hasTrackToFileDifference: hasTrackToFileTitleDifference(track.id),
                            hasExternallyModifiedDifference: hasExternallyModifiedTitleDifference(track.id)
                        )
                }
            }
            .width(min: 140, max: 800)

            TableColumn("Filename") { track in
                Text(track.tags[TagKey.filename] ?? "")
                    .foregroundStyle(hasDeletedFile(track.id) ? .red : .primary)
                    .strikethrough(hasDeletedFile(track.id), color: .red)
            }
            .width(min: 52)
        }
        .frame(minHeight: 64, idealHeight: .infinity)
        .contextMenu {
            Button(lockMenuTitle) {
                onToggleLockSelection()
            }
            .disabled(!canToggleLockSelection)
        }
    }
}
