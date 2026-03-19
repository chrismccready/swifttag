import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(SaveSettingsKey.defaultSavePayload) private var defaultSavePayloadRawValue: String = SaveSettingsDefaults.defaultSavePayload.rawValue
    @AppStorage(SaveSettingsKey.defaultSaveScope) private var defaultSaveScopeRawValue: String = SaveSettingsDefaults.defaultSaveScope.rawValue
    
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
            LabeledContent("On Save (⌘S)") {
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
        }
        .formStyle(.grouped)
    }
}
