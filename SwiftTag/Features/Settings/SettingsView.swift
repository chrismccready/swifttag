import SwiftUI
import AppKit

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
        .frame(width: 352, height: 476)
        .background(SettingsWindowRegistrar())
    }
}

private struct SettingsWindowRegistrar: NSViewRepresentable {
    func makeNSView(context: Context) -> RegistrationView {
        RegistrationView()
    }

    func updateNSView(_ nsView: RegistrationView, context: Context) {
        nsView.registerCurrentWindow()
    }

    final class RegistrationView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            registerCurrentWindow()
        }

        func registerCurrentWindow() {
            SettingsWindowCoordinator.shared.registerSettingsWindow(window)
        }
    }
}
