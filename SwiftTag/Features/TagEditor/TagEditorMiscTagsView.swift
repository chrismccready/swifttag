import SwiftUI

struct TagEditorMiscTagsView: View {
    @Binding var rows: [MiscTagRow]
    @Binding var selectedRowIDs: Set<MiscTagRow.ID>
    var focusedRowID: FocusState<MiscTagRow.ID?>.Binding
    let isEditingEnabled: Bool

    let onAdd: () -> Void
    let onDelete: () -> Void
    let keyBindingForRow: (MiscTagRow.ID) -> Binding<String>?
    let valueBindingForRow: (MiscTagRow.ID) -> Binding<String>?
    let isInvalidKeyInput: (String, MiscTagRow.ID) -> Bool
    let hasExternalDifferenceForRow: (MiscTagRow) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Misc Tags")
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .disabled(!isEditingEnabled)
                .help("Add Tag")
                .accessibilityIdentifier("miscTags.addButton")

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .help("Delete Selected Tags")
                .disabled(selectedRowIDs.isEmpty || !isEditingEnabled)
                .accessibilityIdentifier("miscTags.deleteButton")
            }

            Table(rows, selection: $selectedRowIDs) {
                TableColumn("Key") { row in
                    if let keyBinding = keyBindingForRow(row.id) {
                        TextField("Key", text: keyBinding)
                            .foregroundStyle(isInvalidKeyInput(row.key, row.id) || hasExternalDifferenceForRow(row) ? .red : .primary)
                            .if(hasExternalDifferenceForRow(row)) { view in view.italic() }
                            .focused(focusedRowID, equals: row.id)
                            .disabled(!isEditingEnabled)
                            .accessibilityIdentifier("miscTags.keyField.\(row.id.uuidString)")
                    }
                }
                .width(min: 120)

                TableColumn("Value") { row in
                    if let valueBinding = valueBindingForRow(row.id) {
                        TextField("Value", text: valueBinding)
                            .foregroundStyle(hasExternalDifferenceForRow(row) ? .red : .primary)
                            .if(hasExternalDifferenceForRow(row)) { view in view.italic() }
                            .disabled(!isEditingEnabled)
                    }
                }
                .width(min: 160)
            }
            .frame(minHeight: 80, maxHeight: 176)
            .accessibilityIdentifier("miscTags.table")
        }
        .padding(.top, 22)
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
