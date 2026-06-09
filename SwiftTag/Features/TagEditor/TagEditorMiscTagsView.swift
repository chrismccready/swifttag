import SwiftUI

struct TagEditorMiscTagsView: View {
    @Binding var rows: [MiscTagRow]
    @Binding var selectedRowIDs: Set<MiscTagRow.ID>
    var focusedRowID: FocusState<MiscTagRow.ID?>.Binding
    let isEditingEnabled: Bool
    let plusMinusButtonSize = CGSize(width: 20, height: 20)

    let onAdd: () -> Void
    let onDelete: () -> Void
    let keyBindingForRow: (MiscTagRow.ID) -> Binding<String>?
    let valueBindingForRow: (MiscTagRow.ID) -> Binding<String>?
    let isInvalidKeyInput: (String, MiscTagRow.ID) -> Bool
    let hasInternalDifferenceForRow: (MiscTagRow) -> Bool
    let hasExternalDifferenceForRow: (MiscTagRow) -> Bool
    let hasExternallyModifiedDifferenceForRow: (MiscTagRow) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Text("Misc Tags")
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: plusMinusButtonSize.width, height: plusMinusButtonSize.height, alignment: .bottom)
                .buttonStyle(.bordered)
                .disabled(!isEditingEnabled)
                .help("Add Tag")
                .accessibilityIdentifier("miscTags.addButton")

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "minus")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: plusMinusButtonSize.width, height: plusMinusButtonSize.height, alignment: .bottom)
                .buttonStyle(.bordered)
                .help("Delete Selected Tags")
                .disabled(selectedRowIDs.isEmpty || !isEditingEnabled)
                .accessibilityIdentifier("miscTags.deleteButton")
            }

            ScrollViewReader { proxy in
                Table(rows, selection: $selectedRowIDs) {
                    TableColumn("Key") { row in
                        if let keyBinding = keyBindingForRow(row.id) {
                            TextField("Key", text: keyBinding)
                                .tagDiffStyle(
                                    tag: .misc,
                                    hasTrackToTrackDifference: false,
                                    hasTrackToFileDifference: hasExternalDifferenceForRow(row),
                                    hasExternallyModifiedDifference: hasExternallyModifiedDifferenceForRow(row),
                                    isInvalid: isInvalidKeyInput(row.key, row.id)
                                )
                                .focused(focusedRowID, equals: row.id)
                                .disabled(!isEditingEnabled)
                                .accessibilityIdentifier("miscTags.keyField.\(row.id.uuidString)")
                                .id(row.id)
                        }
                    }
                    .width(min: 120)

                    TableColumn("Value") { row in
                        if let valueBinding = valueBindingForRow(row.id) {
                            TextField("<value>", text: valueBinding)
                                .tagDiffStyle(
                                    tag: .misc,
                                    hasTrackToTrackDifference: hasInternalDifferenceForRow(row),
                                    hasTrackToFileDifference: hasExternalDifferenceForRow(row),
                                    hasExternallyModifiedDifference: hasExternallyModifiedDifferenceForRow(row)
                                )
                                .disabled(!isEditingEnabled)
                                .accessibilityIdentifier("miscTags.valueField.\(row.id.uuidString)")
                        }
                    }
                    .width(min: 160)
                }
                .frame(minHeight: 80, maxHeight: 176)
                .onChange(of: selectedRowIDs) { _, newSelection in
                    guard newSelection.count == 1,
                          let selectedRowID = newSelection.first else {
                        return
                    }

                    DispatchQueue.main.async {
                        proxy.scrollTo(selectedRowID)
                    }
                }
                .accessibilityIdentifier("miscTags.table")
            }
        }
        .padding(.top, 0)
    }
}
