import SwiftUI

struct TagWriteSettingsView: View {
    @AppStorage(SaveSettingsKey.zeroPadTrackNumber) private var zeroPadTrackNumber: Bool = SaveSettingsDefaults.zeroPadTrackNumber
    @AppStorage(SaveSettingsKey.trackCountKeyStrategy) private var trackCountKeyStrategyRawValue: String = SaveSettingsDefaults.trackCountKeyStrategy.rawValue
    @AppStorage(SaveSettingsKey.zeroPadDiscNumber) private var zeroPadDiscNumber: Bool = SaveSettingsDefaults.zeroPadDiscNumber
    @AppStorage(SaveSettingsKey.discCountKeyStrategy) private var discCountKeyStrategyRawValue: String = SaveSettingsDefaults.discCountKeyStrategy.rawValue

    private var trackCountKeyStrategy: Binding<TrackCountKeyStrategy> {
        Binding(
            get: { TrackCountKeyStrategy(rawValue: trackCountKeyStrategyRawValue) ?? SaveSettingsDefaults.trackCountKeyStrategy },
            set: { trackCountKeyStrategyRawValue = $0.rawValue }
        )
    }

    private var discCountKeyStrategy: Binding<DiscCountKeyStrategy> {
        Binding(
            get: { DiscCountKeyStrategy(rawValue: discCountKeyStrategyRawValue) ?? SaveSettingsDefaults.discCountKeyStrategy },
            set: { discCountKeyStrategyRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Toggle("Zero Pad Track Number", isOn: $zeroPadTrackNumber)
                .accessibilityIdentifier("settings.tags.zeroPadTrackNumber")
                .accessibilityValue(zeroPadTrackNumber ? "On" : "Off")
            
            Toggle("Zero Pad Disc Number", isOn: $zeroPadDiscNumber)
                .accessibilityIdentifier("settings.tags.zeroPadDiscNumber")
                .accessibilityValue(zeroPadDiscNumber ? "On" : "Off")

            Picker("Write track count key as", selection: trackCountKeyStrategy) {
                ForEach(TrackCountKeyStrategy.allCases) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("settings.tags.trackCountKeyStrategy")

            Picker("Write disc count key as", selection: discCountKeyStrategy) {
                ForEach(DiscCountKeyStrategy.allCases) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("settings.tags.discCountKeyStrategy")
        }
        .formStyle(.grouped)
    }
}
