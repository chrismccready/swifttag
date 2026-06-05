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

    @AppStorage(FeedbackSettingsKey.pictureStatusOverlayColor)
    private var pictureStatusOverlayColorRawValue: String = FeedbackSettingsDefaults.pictureStatusOverlayColor

    @AppStorage(FeedbackSettingsKey.quitAppOnLastWindowClose)
    private var quitAppOnLastWindowClose: Bool = FeedbackSettingsDefaults.quitAppOnLastWindowClose

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

    private var pictureStatusOverlayColor: Binding<Color> {
        AppColorStorage.binding(rawValue: $pictureStatusOverlayColorRawValue, fallback: .systemOrange)
    }

    var body: some View {
        Form {
            GroupBox("Send Save Notifications") {
                Picker("Send Save Notifications", selection: saveNotificationMode) {
                    ForEach(SaveNotificationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.top, 2)
                .accessibilityIdentifier("settings.feedback.saveNotifications")
            }
            .controlSize(.regular)

            Section {
                GroupBox("Theme") {
                    Picker("Theme", selection: themePreference) {
                        ForEach(AppThemePreference.allCases) { preference in
                            Text("   \(preference.displayName)   ").tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("settings.feedback.theme")
                }
                .padding(.top, 2)
                .controlSize(.regular)
            }

            Section {
                GroupBox("Tag Value Difference Colors") {
                    ColorPicker("Track to Track Diff Color", selection: trackToTrackDiffColor)
                        .padding(.top, 6)
                        .accessibilityIdentifier("settings.feedback.trackToTrackDiffColor")
                    
                    ColorPicker("Track to File Diff Color", selection: trackToFileDiffColor)
                        .accessibilityIdentifier("settings.feedback.trackToFileDiffColor")
                    
                    ColorPicker("Externally Modified Diff Color", selection: externallyModifiedDiffColor)
                        .accessibilityIdentifier("settings.feedback.externallyModifiedDiffColor")
                    
                    ColorPicker("Track/Disc Total Mismatch Color", selection: trackDiscTotalMismatchColor)
                        .accessibilityIdentifier("settings.feedback.trackDiscTotalMismatchColor")

                    ColorPicker("Picture Status Overlay Color", selection: pictureStatusOverlayColor)
                        .accessibilityIdentifier("settings.feedback.pictureStatusOverlayColor")
                }
                .controlSize(.small)
            }

            Section {
                GroupBox("Window Management") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Quit app on last window close", isOn: $quitAppOnLastWindowClose)
                            .padding(.horizontal, 2)
                            .accessibilityIdentifier("settings.feedback.quitAppOnLastWindowClose")
                            .accessibilityValue(quitAppOnLastWindowClose ? "On" : "Off")
                    }
                    .padding(.vertical, 4)
                }
                .controlSize(.mini)
            }
        }
        .formStyle(.grouped)
    }
}
