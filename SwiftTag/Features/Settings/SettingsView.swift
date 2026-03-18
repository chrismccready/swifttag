import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
            .accessibilityIdentifier("settings.tab.general")

            Tab("Tags", systemImage: "tag") {
                TagWriteSettingsView()
            }
            .accessibilityIdentifier("settings.tab.tags")

            Tab("Feedback", systemImage: "bell.badge") {
                FeedbackSettingsView()
            }
            .accessibilityIdentifier("settings.tab.feedback")
        }
        .accessibilityIdentifier("settings.tabView")
        .padding(4)
        .frame(width: 340, height: 380)
    }
}
