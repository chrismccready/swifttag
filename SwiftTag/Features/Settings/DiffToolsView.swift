import SwiftUI

struct DiffToolsView: View {
    @AppStorage(FeedbackSettingsKey.warnOnTrackTotalMismatch)
    private var warnOnTrackTotalMismatch: Bool = FeedbackSettingsDefaults.warnOnTrackTotalMismatch

    @AppStorage(FeedbackSettingsKey.warnOnDiscTotalMismatch)
    private var warnOnDiscTotalMismatch: Bool = FeedbackSettingsDefaults.warnOnDiscTotalMismatch

    @AppStorage(FeedbackSettingsKey.formatOnTrackToFileDiff)
    private var formatOnTrackToFileDiff: Bool = FeedbackSettingsDefaults.formatOnTrackToFileDiff

    @AppStorage(FeedbackSettingsKey.formatOnTrackToTrackDiff)
    private var formatOnTrackToTrackDiff: Bool = FeedbackSettingsDefaults.formatOnTrackToTrackDiff

    @AppStorage(FeedbackSettingsKey.formatOnExternallyModifiedDiff)
    private var formatOnExternallyModifiedDiff: Bool = FeedbackSettingsDefaults.formatOnExternallyModifiedDiff

    var body: some View {
        Form {
            Toggle("Format on Track Total Mismatch", isOn: $warnOnTrackTotalMismatch)
                .accessibilityIdentifier("diffTools.warnOnTrackTotalMismatch")

            Toggle("Format on Disc Total Mismatch", isOn: $warnOnDiscTotalMismatch)
                .accessibilityIdentifier("diffTools.warnOnDiscTotalMismatch")

            Toggle("Format on Track to File Diff", isOn: $formatOnTrackToFileDiff)
                .accessibilityIdentifier("diffTools.formatOnTrackToFileDiff")

            Toggle("Format on Track to Track Diff", isOn: $formatOnTrackToTrackDiff)
                .accessibilityIdentifier("diffTools.formatOnTrackToTrackDiff")

            Toggle("Format on Externally Modified Diff", isOn: $formatOnExternallyModifiedDiff)
                .accessibilityIdentifier("diffTools.formatOnExternallyModifiedDiff")
        }
        .formStyle(.grouped)
        .frame(width: 308, height: 230, alignment: .init(horizontal: .center, vertical: .top))
        .contentMargins([.horizontal, .top], -8, for: .automatic)
    }

}
