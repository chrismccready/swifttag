import SwiftUI

struct DiffToolsView: View {
    @AppStorage(FeedbackSettingsKey.formatOnTrackTotalMismatch)
    private var formatOnTrackTotalMismatch: Bool = FeedbackSettingsDefaults.formatOnTrackTotalMismatch

    @AppStorage(FeedbackSettingsKey.formatOnDiscTotalMismatch)
    private var formatOnDiscTotalMismatch: Bool = FeedbackSettingsDefaults.formatOnDiscTotalMismatch

    @AppStorage(FeedbackSettingsKey.formatOnDuplicatePicture)
    private var formatOnDuplicatePicture: Bool = FeedbackSettingsDefaults.formatOnDuplicatePicture

    @AppStorage(FeedbackSettingsKey.formatOnTrackToFileDiff)
    private var formatOnTrackToFileDiff: Bool = FeedbackSettingsDefaults.formatOnTrackToFileDiff

    @AppStorage(FeedbackSettingsKey.formatOnTrackToTrackDiff)
    private var formatOnTrackToTrackDiff: Bool = FeedbackSettingsDefaults.formatOnTrackToTrackDiff

    @AppStorage(FeedbackSettingsKey.formatOnExternallyModifiedDiff)
    private var formatOnExternallyModifiedDiff: Bool = FeedbackSettingsDefaults.formatOnExternallyModifiedDiff

    var body: some View {
        VStack(spacing: 2){
            DiffToolsToggleRow(
                title: "Format on Track to File Diff",
                isOn: $formatOnTrackToFileDiff,
                accessibilityID: "diffTools.formatOnTrackToFileDiff"
            )
            DiffToolsToggleRow(
                title: "Format on Track to Track Diff",
                isOn: $formatOnTrackToTrackDiff,
                accessibilityID: "diffTools.formatOnTrackToTrackDiff"
            )
            DiffToolsToggleRow(
                title: "Format on Externally Modified Diff",
                isOn: $formatOnExternallyModifiedDiff,
                accessibilityID: "diffTools.formatOnExternallyModifiedDiff"
            )
            DiffToolsToggleRow(
                title: "Format on Track Total Mismatch",
                isOn: $formatOnTrackTotalMismatch,
                accessibilityID: "diffTools.formatOnTrackTotalMismatch"
            )
            DiffToolsToggleRow(
                title: "Format on Disc Total Mismatch",
                isOn: $formatOnDiscTotalMismatch,
                accessibilityID: "diffTools.formatOnDiscTotalMismatch"
            )
            DiffToolsToggleRow(
                title: "Format on Duplicate Picture",
                isOn: $formatOnDuplicatePicture,
                accessibilityID: "diffTools.formatOnDuplicatePicture"
            )
        }
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        Spacer()
    }
}

struct DiffToolsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let accessibilityID: String
    let pad = 3.0
    var body: some View {
        HStack {
            Text(title)
                .padding(.bottom, pad)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .padding(.bottom, pad)
                .accessibilityIdentifier(accessibilityID)
                .accessibilityValue(isOn ? "On" : "Off")
        }
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.primary)
                .opacity(0.08),
            alignment: .bottom
        )
    }
}
