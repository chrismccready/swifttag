//
//  SwiftTagApp.swift
//  SwiftTag
//
//  Created by Christopher McCready on 2/24/26.
//

import SwiftUI
import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        SaveNotificationCoordinator.shared.handlePendingUITestRouteIfNeeded()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list, .banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            SaveNotificationCoordinator.shared.handleNotificationResponse(
                userInfo: response.notification.request.content.userInfo
            )
            completionHandler()
        }
    }
}

private struct AppCommands: Commands {
    @FocusedValue(\.showTomlSheet) private var showTomlSheet
    @FocusedValue(\.showFlacImporter) private var showFlacImporter
    @FocusedValue(\.showReadOnlyFlacImporter) private var showReadOnlyFlacImporter
    @FocusedValue(\.performDefaultSave) private var performDefaultSave
    @FocusedValue(\.performSaveTagsOnly) private var performSaveTagsOnly
    @FocusedValue(\.performSavePicturesOnly) private var performSavePicturesOnly
    @FocusedValue(\.performToggleSelectedTrackLocks) private var performToggleSelectedTrackLocks
    @FocusedValue(\.toggleSelectedTrackLocksTitle) private var toggleSelectedTrackLocksTitle
    @FocusedValue(\.canPerformDefaultSave) private var canPerformDefaultSave
    @FocusedValue(\.canPerformSaveTagsOnly) private var canPerformSaveTagsOnly
    @FocusedValue(\.canPerformSavePicturesOnly) private var canPerformSavePicturesOnly
    @FocusedValue(\.canPerformToggleSelectedTrackLocks) private var canPerformToggleSelectedTrackLocks

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Load FLAC files...") {
                showFlacImporter?()
            }
            .keyboardShortcut("l")
            .disabled(showFlacImporter == nil)

            Button("Load FLAC files (read-only)...") {
                showReadOnlyFlacImporter?()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .disabled(showReadOnlyFlacImporter == nil)

            Divider()

            Button(toggleSelectedTrackLocksTitle ?? "Toggle Selected Tracks Lock") {
                performToggleSelectedTrackLocks?()
            }
            .keyboardShortcut("l", modifiers: [.control])
            .disabled(!(canPerformToggleSelectedTrackLocks ?? false))

            Divider()

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
        seedUITestNotificationRouteIfNeeded()
    }

    var body: some Scene {
        WindowGroup(id: AppSceneID.editor, for: EditorSessionValue.self, content: { sessionValue in
            ContentView(sessionValue: sessionValue)
        }, defaultValue: {
            EditorSessionValue()
        })
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

    private func seedUITestNotificationRouteIfNeeded() {
        let environment = ProcessInfo.processInfo.environment
        let rawRecordID = environment["UITEST_OPEN_SAVE_NOTIFICATION_RECORD_ID"]
            ?? uiTestLaunchValue(for: "UITEST_OPEN_SAVE_NOTIFICATION_RECORD_ID")
        guard let rawRecordID,
              let recordID = UUID(uuidString: rawRecordID) else {
            return
        }

        SaveNotificationCoordinator.shared.setPendingUITestReopenRecordID(recordID)
    }

    private func uiTestLaunchFlagEnabled(_ key: String) -> Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment[key] == "1" {
            return true
        }

        return ProcessInfo.processInfo.arguments.contains("-\(key)")
    }

    private func uiTestLaunchValue(for key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-\(key)") else {
            return nil
        }

        let valueIndex = arguments.index(after: keyIndex)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        let value = arguments[valueIndex]
        return value.isEmpty ? nil : value
    }
}
