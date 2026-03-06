//
//  SwiftTagApp.swift
//  SwiftTag
//
//  Created by Christopher McCready on 2/24/26.
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private struct AppCommands: Commands {
    @FocusedValue(\.showTomlSheet) private var showTomlSheet
    @FocusedValue(\.showFlacImporter) private var showFlacImporter
    @FocusedValue(\.performDefaultSave) private var performDefaultSave
    @FocusedValue(\.performSaveTagsOnly) private var performSaveTagsOnly
    @FocusedValue(\.performSavePicturesOnly) private var performSavePicturesOnly
    @FocusedValue(\.canPerformDefaultSave) private var canPerformDefaultSave
    @FocusedValue(\.canPerformSaveTagsOnly) private var canPerformSaveTagsOnly
    @FocusedValue(\.canPerformSavePicturesOnly) private var canPerformSavePicturesOnly

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Load FLAC files...") {
                showFlacImporter?()
            }
            .disabled(showFlacImporter == nil)

            Button("Show TOML...") {
                showTomlSheet?()
            }
            .disabled(showTomlSheet == nil)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                performDefaultSave?()
            }
            .keyboardShortcut("s")
            .disabled(!(canPerformDefaultSave ?? false))

            Divider()

            Button("Save Tags...") {
                performSaveTagsOnly?()
            }
            .disabled(!(canPerformSaveTagsOnly ?? false))

            Button("Save Pictures...") {
                performSavePicturesOnly?()
            }
            .disabled(!(canPerformSavePicturesOnly ?? false))
        }
    }
}

@main
struct SwiftTagApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        resetUITestSaveSettingsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            AppCommands()
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }

    private func resetUITestSaveSettingsIfNeeded() {
        guard uiTestLaunchFlagEnabled("UITEST_RESET_SAVE_SETTINGS"),
              let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        UserDefaults.standard.synchronize()
    }

    private func uiTestLaunchFlagEnabled(_ key: String) -> Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment[key] == "1" {
            return true
        }

        return ProcessInfo.processInfo.arguments.contains("-\(key)")
    }
}
