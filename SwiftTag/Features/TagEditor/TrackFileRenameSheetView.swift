import SwiftUI

struct TrackFileRenameSheetView: View {
    let renameExample: String
    @Binding var renameFormat: String
    @Binding var renameFormatSelection: TextSelection?
    @Binding var invalidReplacementText: TrackFileRenameInvalidReplacementText
    @Binding var strict: Bool
    @Binding var spaceReplacement: TrackFileRenameSpaceReplacement
    let canRenameSelectedTracks: Bool
    let canRenameAllTracks: Bool
    let onCancel: () -> Void
    let onRenameSelectedTracks: () -> Void
    let onRenameAllTracks: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename Track Files")
                .font(.title3.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Rename Example")
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(renameExample)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 6)
                }

                GridRow {
                    Text("Rename Format")
                    TextField("Rename Format", text: $renameFormat, selection: $renameFormatSelection)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("trackFileRename.format")
                }

                GridRow {
                    Text("Invalid Replacement")
                    HStack(spacing: 0) {
                        Picker("", selection: $invalidReplacementText) {
                            ForEach(TrackFileRenameInvalidReplacementText.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("trackFileRename.invalidReplacementText")
                        
                        Text("Strict")
                            .padding(.leading, 12)
                        Toggle("", isOn: $strict)
                            .labelsHidden()
                            .padding(.leading, 10)
                            .accessibilityIdentifier("trackFileRename.strict")
                    }
                }

                GridRow {
                    Text("Space Replacement")
                    Picker("", selection: $spaceReplacement) {
                        ForEach(TrackFileRenameSpaceReplacement.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("trackFileRename.spaceReplacement")
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                Button("Rename Selected Track Files") {
                    onRenameSelectedTracks()
                }
                .disabled(!canRenameSelectedTracks)
                Button("Rename All Track Files") {
                    onRenameAllTracks()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canRenameAllTracks)
            }
        }
        .padding(20)
        .presentationSizing(.fitted)
        .frame(
            minWidth: 560, idealWidth: 560, maxWidth: 1280,
            minHeight: 234, maxHeight: 234
        )
    }
}
