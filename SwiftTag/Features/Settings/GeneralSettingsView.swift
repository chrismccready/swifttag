import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(SaveSettingsKey.defaultSavePayload) private var defaultSavePayloadRawValue: String = SaveSettingsDefaults.defaultSavePayload.rawValue
    @AppStorage(SaveSettingsKey.defaultSaveScope) private var defaultSaveScopeRawValue: String = SaveSettingsDefaults.defaultSaveScope.rawValue
    @AppStorage(SaveSettingsKey.saveReferencedSwiftTagDocument) private var saveReferencedSwiftTagDocument: Bool = SaveSettingsDefaults.saveReferencedSwiftTagDocument
    @AppStorage(SaveSettingsKey.askToSaveNewSwiftTagDocument) private var askToSaveNewSwiftTagDocument: Bool = SaveSettingsDefaults.askToSaveNewSwiftTagDocument
    
    private var defaultSavePayload: Binding<SavePayloadOption> {
        Binding(
            get: { SavePayloadOption(rawValue: defaultSavePayloadRawValue) ?? SaveSettingsDefaults.defaultSavePayload },
            set: { defaultSavePayloadRawValue = $0.rawValue }
        )
    }
    
    private var defaultSaveScope: Binding<SaveScopeOption> {
        Binding(
            get: { SaveScopeOption(rawValue: defaultSaveScopeRawValue) ?? SaveSettingsDefaults.defaultSaveScope },
            set: { defaultSaveScopeRawValue = $0.rawValue }
        )
    }
    
    var body: some View {
        Form {
            LabeledContent("FLAC File Save (⌘S)") {
                HStack {
                    Text("Write:")
                    Picker("", selection: defaultSavePayload) {
                        ForEach(SavePayloadOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .accessibilityIdentifier("settings.general.defaultSavePayload")
                }
                HStack {
                    Spacer()
                    Text("  To:")
                    Picker("", selection: defaultSaveScope) {
                        ForEach(SaveScopeOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .accessibilityIdentifier("settings.general.defaultSaveScope")
                }
                .padding(.top, 1)
            }
            .pickerStyle(.segmented)
            .controlSize(.regular)

            Section {
                GroupBox("SwiftTag Document Save (⌘S)") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Save referenced document", isOn: $saveReferencedSwiftTagDocument)
                            .accessibilityIdentifier("settings.general.saveReferencedSwiftTagDocument")
                            .accessibilityValue(saveReferencedSwiftTagDocument ? "On" : "Off")
                        
                        Toggle("Ask to save new document", isOn: $askToSaveNewSwiftTagDocument)
                            .accessibilityIdentifier("settings.general.askToSaveNewSwiftTagDocument")
                            .accessibilityValue(askToSaveNewSwiftTagDocument ? "On" : "Off")
                    }
                    .padding(EdgeInsets(top: 4, leading: 5, bottom: 4, trailing: 4))
                }
                .controlSize(.mini)
            }
        }
        .formStyle(.grouped)
    }
}
