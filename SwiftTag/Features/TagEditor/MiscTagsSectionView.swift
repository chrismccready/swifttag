import SwiftUI

struct MiscTagsSectionView: View {
    @Binding var rows: [MiscTagRow]
    @Binding var selectedRowIDs: Set<MiscTagRow.ID>
    var focusedRowID: FocusState<MiscTagRow.ID?>.Binding

    let onAdd: () -> Void
    let onDelete: () -> Void
    let keyBindingForRow: (MiscTagRow.ID) -> Binding<String>?
    let valueBindingForRow: (MiscTagRow.ID) -> Binding<String>?
    let isInvalidKeyInput: (String, MiscTagRow.ID) -> Bool

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
                .help("Add Tag")
                .accessibilityIdentifier("miscTags.addButton")

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .help("Delete Selected Tags")
                .disabled(selectedRowIDs.isEmpty)
                .accessibilityIdentifier("miscTags.deleteButton")
            }

            Table(rows, selection: $selectedRowIDs) {
                TableColumn("Key") { row in
                    if let keyBinding = keyBindingForRow(row.id) {
                        TextField("Key", text: keyBinding)
                            .foregroundStyle(isInvalidKeyInput(row.key, row.id) ? .red : .primary)
                            .focused(focusedRowID, equals: row.id)
                            .accessibilityIdentifier("miscTags.keyField.\(row.id.uuidString)")
                    }
                }
                .width(min: 120)

                TableColumn("Value") { row in
                    if let valueBinding = valueBindingForRow(row.id) {
                        TextField("Value", text: valueBinding)
                    }
                }
                .width(min: 160)
            }
            .frame(minHeight: 80, maxHeight: 176)
            .accessibilityIdentifier("miscTags.table")
        }
        .padding(.top, 6)
    }
}
