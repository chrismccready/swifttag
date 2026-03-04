import SwiftUI

struct TOMLUtilityView: View {
    @Environment(\.dismiss) private var dismiss
    let tomlText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: .constant(tomlText))
                .font(.body.monospaced())
                .frame(minWidth: 500, minHeight: 400)

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
        }
        .padding()
    }
}
