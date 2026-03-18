import AppKit
import SwiftUI

struct FeedbackSettingsView: View {
    @AppStorage(FeedbackSettingsKey.saveNotificationMode)
    private var saveNotificationModeRawValue: String = FeedbackSettingsDefaults.saveNotificationMode.rawValue

    @AppStorage(FeedbackSettingsKey.themePreference)
    private var themePreferenceRawValue: String = FeedbackSettingsDefaults.themePreference.rawValue

    @AppStorage(FeedbackSettingsKey.trackToTrackDiffColor)
    private var trackToTrackDiffColorRawValue: String = FeedbackSettingsDefaults.trackToTrackDiffColor

    @AppStorage(FeedbackSettingsKey.trackToFileDiffColor)
    private var trackToFileDiffColorRawValue: String = FeedbackSettingsDefaults.trackToFileDiffColor

    @AppStorage(FeedbackSettingsKey.externallyModifiedDiffColor)
    private var externallyModifiedDiffColorRawValue: String = FeedbackSettingsDefaults.externallyModifiedDiffColor

    @AppStorage(FeedbackSettingsKey.trackDiscTotalMismatchColor)
    private var trackDiscTotalMismatchColorRawValue: String = FeedbackSettingsDefaults.trackDiscTotalMismatchColor

    private var saveNotificationMode: Binding<SaveNotificationMode> {
        Binding(
            get: { SaveNotificationMode(rawValue: saveNotificationModeRawValue) ?? FeedbackSettingsDefaults.saveNotificationMode },
            set: { saveNotificationModeRawValue = $0.rawValue }
        )
    }

    private var themePreference: Binding<AppThemePreference> {
        Binding(
            get: { AppThemePreference(rawValue: themePreferenceRawValue) ?? FeedbackSettingsDefaults.themePreference },
            set: { themePreferenceRawValue = $0.rawValue }
        )
    }

    private var trackToTrackDiffColor: Binding<Color> {
        AppColorStorage.binding(rawValue: $trackToTrackDiffColorRawValue, fallback: .systemOrange)
    }

    private var trackToFileDiffColor: Binding<Color> {
        AppColorStorage.binding(rawValue: $trackToFileDiffColorRawValue, fallback: .labelColor)
    }

    private var externallyModifiedDiffColor: Binding<Color> {
        AppColorStorage.binding(rawValue: $externallyModifiedDiffColorRawValue, fallback: .systemRed)
    }

    private var trackDiscTotalMismatchColor: Binding<Color> {
        AppColorStorage.binding(rawValue: $trackDiscTotalMismatchColorRawValue, fallback: .systemRed)
    }

    var body: some View {
        Form {
            Picker("Send Save Notifications", selection: saveNotificationMode) {
                ForEach(SaveNotificationMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.feedback.saveNotifications")

            Picker("Theme", selection: themePreference) {
                ForEach(AppThemePreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.feedback.theme")

            ColorPicker("Track to Track Diff Color", selection: trackToTrackDiffColor)
                .accessibilityIdentifier("settings.feedback.trackToTrackDiffColor")

            ColorPicker("Track to File Diff Color", selection: trackToFileDiffColor)
                .accessibilityIdentifier("settings.feedback.trackToFileDiffColor")

            ColorPicker("Externally Modified Diff Color", selection: externallyModifiedDiffColor)
                .accessibilityIdentifier("settings.feedback.externallyModifiedDiffColor")

            ColorPicker("Track/Disc Total Mismatch Color", selection: trackDiscTotalMismatchColor)
                .accessibilityIdentifier("settings.feedback.trackDiscTotalMismatchColor")
        }
        .formStyle(.grouped)
    }
}
