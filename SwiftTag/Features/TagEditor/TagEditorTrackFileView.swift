import SwiftUI
import UniformTypeIdentifiers

struct TagEditorTrackFileView: View {
    @FocusState private var focusedTitleTrackID: UUID?

    let trackItems: [Track]
    var selection: Binding<Set<UUID>>
    var showsFingerprintColumn: Binding<Bool>
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
    let onSetTrackTotalToCount: () -> Void
    let setTrackTotalMenuTitle: String
    let canSetTrackTotal: Bool
    let onAddFlacFiles: () -> Void
    let onAddReadOnlyFlacFiles: () -> Void
    let canAddFlacFiles: Bool
    let onReloadSelectedTracks: () -> Void
    let reloadSelectedTracksTitle: String
    let canReloadSelectedTracks: Bool
    let onRemoveSelectedTracks: () -> Void
    let removeSelectedTracksTitle: String
    let canRemoveSelectedTracks: Bool
    let onDropFlacFiles: ([NSItemProvider]) -> Bool

    private var sortedTrackItems: [Track] {
        trackItems.sorted {
            let lhsNumber = Int($0.tags[TagKey.trackNumber] ?? "")
            let rhsNumber = Int($1.tags[TagKey.trackNumber] ?? "")
            switch (lhsNumber, rhsNumber) {
            case let (lhs?, rhs?):
                if lhs != rhs {
                    return lhs < rhs
                }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }

            let lhsFilename = $0.displayFileName
            let rhsFilename = $1.displayFileName
            return lhsFilename.localizedStandardCompare(rhsFilename) == .orderedAscending
        }
    }

    private var fingerprintColumnMenuTitle: String {
        showsFingerprintColumn.wrappedValue ? "Hide Fingerprint Column" : "Show Fingerprint Column"
    }

    var body: some View {
        Table(sortedTrackItems, selection: selection) {
            TableColumn("") { track in
                if let statusPresentation = statusPresentationForTrack(track.id) {
                    Image(systemName: statusPresentation.systemImageName)
                        .accessibilityIdentifier("trackStatusIcon")
                        .accessibilityLabel(Text(statusPresentation.systemImageName))
                        .help(statusPresentation.help ?? "")
                        .foregroundStyle(.primary)
                        .frame(minHeight: 20, alignment: .center)
                }
            }
            .width(16)

            TableColumn("#") { track in
                Text(Int(track.tags[TagKey.trackNumber] ?? "").map(String.init) ?? "")
                    .foregroundStyle(.primary)
            }
            .width(24)
            .alignment(.center)

            TableColumn("Title") { track in
                if let title = titleBindingForTrack(track.id) {
                    TextField("Title", text: title)
                        .focused($focusedTitleTrackID, equals: track.id)
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
                Text(track.displayFileName)
                    .accessibilityIdentifier("trackFilenameText")
                    .accessibilityValue(hasDeletedFile(track.id) ? "deleted" : "available")
                    .foregroundStyle(hasDeletedFile(track.id) ? .red : .primary)
                    .strikethrough(hasDeletedFile(track.id), color: .red)
            }
            .width(min: 52)

            if showsFingerprintColumn.wrappedValue {
                TableColumn("Fingerprint (ffp)") { track in
                    Text(track.fingerprintDisplayValue)
                        .foregroundStyle(.primary)
                }
                .width(min: 90)
            }
        }
        .frame(minHeight: 64, idealHeight: .infinity)
        .contextMenu {
            Button("Add FLAC files...") {
                onAddFlacFiles()
            }
            .disabled(!canAddFlacFiles)

            Button("Add FLAC files (read-only)...") {
                onAddReadOnlyFlacFiles()
            }
            .disabled(!canAddFlacFiles)

            Divider()
            
            Button(lockMenuTitle) {
                onToggleLockSelection()
            }
            .disabled(!canToggleLockSelection)

            Divider()

            Button(setTrackTotalMenuTitle) {
                onSetTrackTotalToCount()
            }
            .disabled(!canSetTrackTotal)

            Divider()

            Button(reloadSelectedTracksTitle) {
                onReloadSelectedTracks()
            }
            .disabled(!canReloadSelectedTracks)

            Button(removeSelectedTracksTitle) {
                onRemoveSelectedTracks()
            }
            .disabled(!canRemoveSelectedTracks)

            Divider()

            Button(fingerprintColumnMenuTitle) {
                showsFingerprintColumn.wrappedValue.toggle()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: onDropFlacFiles)
    }
}
