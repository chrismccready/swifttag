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
            GroupBox("Default on Save (⌘S) behavior") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Data", selection: defaultSavePayload) {
                        ForEach(SavePayloadOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .accessibilityIdentifier("settings.general.defaultSavePayload")

                    Picker("Scope", selection: defaultSaveScope) {
                        ForEach(SaveScopeOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .accessibilityIdentifier("settings.general.defaultSaveScope")
                }
                .pickerStyle(.radioGroup)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 0))
            }
        }
        .formStyle(.grouped)
    }
}
