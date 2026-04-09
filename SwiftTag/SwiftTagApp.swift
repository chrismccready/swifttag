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

    func applicationWillFinishLaunching(_ notification: Notification) {
        handlePendingUITestDocumentOpenIfNeeded()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        SaveNotificationCoordinator.shared.handlePendingUITestRouteIfNeeded()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        routeFinderOpenedFiles(
            [URL(fileURLWithPath: filename)],
            appIsActive: sender.isActive
        )
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        _ = routeFinderOpenedFiles(urls, appIsActive: application.isActive)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let didRouteFiles = routeFinderOpenedFiles(
            filenames.map(URL.init(fileURLWithPath:)),
            appIsActive: sender.isActive
        )
        sender.reply(toOpenOrPrint: didRouteFiles ? .success : .failure)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        UnsavedChangesCoordinator.shared.applicationShouldTerminate(sender)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let options: UNNotificationPresentationOptions = SaveNotificationCoordinator.shared.allowsNotificationDelivery(
            appIsFrontmost: NSApp.isActive
        ) ? [.list, .banner, .badge, .sound] : []
        completionHandler(options)
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

    private func handlePendingUITestDocumentOpenIfNeeded() {
        guard let documentURL = uiTestDocumentOpenURLIfPresent() else {
            return
        }

        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        let shouldTreatAppAsActive = environment["UITEST_OPEN_DOCUMENT_WHILE_ACTIVE"] == "1"
            || arguments.contains("-UITEST_OPEN_DOCUMENT_WHILE_ACTIVE")

        _ = routeFinderOpenedFiles(
            [documentURL],
            appIsActive: shouldTreatAppAsActive
        )
    }

    @discardableResult
    private func routeFinderOpenedFiles(_ urls: [URL], appIsActive: Bool) -> Bool {
        EditorWindowCoordinator.shared.routeOpenedDocuments(urls, appIsActive: appIsActive)
    }

    private func uiTestDocumentOpenURLIfPresent() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        guard let rawDocumentPath = environment["UITEST_OPEN_DOCUMENT_FLAC_PATH"],
              !rawDocumentPath.isEmpty else {
            return nil
        }

        guard let base64Value = environment["UITEST_OPEN_DOCUMENT_FLAC_DATA_BASE64"],
              let fileData = Data(base64Encoded: base64Value) else {
            return URL(fileURLWithPath: rawDocumentPath)
        }

        let fileURL = uiTestMaterializedFLACDirectoryURL()
            .appendingPathComponent("SwiftTagUITestOpenedDocument")
            .appendingPathExtension("flac")
        try? fileData.write(to: fileURL, options: .atomic)
        try? UITestFlacOverrideWriter.applyOverrides(
            to: fileURL,
            albumMode: environment["UITEST_OPEN_DOCUMENT_FLAC_ALBUM_MODE"],
            titleOverride: environment["UITEST_OPEN_DOCUMENT_FLAC_TITLE_OVERRIDE"],
            pictureProfile: environment["UITEST_OPEN_DOCUMENT_FLAC_PICTURE_PROFILE"]
        )
        return fileURL
    }

    private func uiTestMaterializedFLACDirectoryURL() -> URL {
        let directoryURL = (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("SwiftTagUITestFixtures", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}

private struct AppCommands: Commands {
    @FocusedValue(\.showTomlSheet) private var showTomlSheet
    @FocusedValue(\.showFlacImporter) private var showFlacImporter
    @FocusedValue(\.showReadOnlyFlacImporter) private var showReadOnlyFlacImporter
    @FocusedValue(\.showAddFlacImporter) private var showAddFlacImporter
    @FocusedValue(\.showAddReadOnlyFlacImporter) private var showAddReadOnlyFlacImporter
    @FocusedValue(\.togglePictureBrowser) private var togglePictureBrowser
    @FocusedValue(\.pictureBrowserMenuTitle) private var pictureBrowserMenuTitle
    @FocusedValue(\.canTogglePictureBrowser) private var canTogglePictureBrowser
    @FocusedValue(\.performDefaultSave) private var performDefaultSave
    @FocusedValue(\.performSaveTagsOnly) private var performSaveTagsOnly
    @FocusedValue(\.performSavePicturesOnly) private var performSavePicturesOnly
    @FocusedValue(\.performSaveSwiftTagDocument) private var performSaveSwiftTagDocument
    @FocusedValue(\.performToggleSelectedTrackLocks) private var performToggleSelectedTrackLocks
    @FocusedValue(\.performSetTrackTotal) private var performSetTrackTotal
    @FocusedValue(\.performReloadSelectedTracks) private var performReloadSelectedTracks
    @FocusedValue(\.performRemoveSelectedTracks) private var performRemoveSelectedTracks
    @FocusedValue(\.toggleSelectedTrackLocksTitle) private var toggleSelectedTrackLocksTitle
    @FocusedValue(\.setTrackTotalTitle) private var setTrackTotalTitle
    @FocusedValue(\.reloadSelectedTracksTitle) private var reloadSelectedTracksTitle
    @FocusedValue(\.removeSelectedTracksTitle) private var removeSelectedTracksTitle
    @FocusedValue(\.canPerformDefaultSave) private var canPerformDefaultSave
    @FocusedValue(\.canPerformSaveTagsOnly) private var canPerformSaveTagsOnly
    @FocusedValue(\.canPerformSavePicturesOnly) private var canPerformSavePicturesOnly
    @FocusedValue(\.canPerformSaveSwiftTagDocument) private var canPerformSaveSwiftTagDocument
    @FocusedValue(\.canPerformToggleSelectedTrackLocks) private var canPerformToggleSelectedTrackLocks
    @FocusedValue(\.canPerformSetTrackTotal) private var canPerformSetTrackTotal
    @FocusedValue(\.canPerformReloadSelectedTracks) private var canPerformReloadSelectedTracks
    @FocusedValue(\.canPerformRemoveSelectedTracks) private var canPerformRemoveSelectedTracks

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add FLAC files...") {
                if showAddFlacImporter != nil {
                    showAddFlacImporter?()
                } else if let uiTestFLACURL = uiTestMenuFlacURLIfPresent() {
                    _ = EditorWindowCoordinator.shared.routeOpenedDocuments(
                        [uiTestFLACURL],
                        appIsActive: NSApp.isActive
                    )
                }
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(showAddFlacImporter == nil && uiTestMenuFlacURLIfPresent() == nil)
            .modifierKeyAlternate(.shift) {
                Button("Add FLAC files (replace existing)...") {
                    showFlacImporter?()
                }
                .disabled(showFlacImporter == nil)
            }

            Button("Add FLAC files (read-only)...") {
                if showAddReadOnlyFlacImporter != nil {
                    showAddReadOnlyFlacImporter?()
                } else if let uiTestFLACURL = uiTestMenuFlacURLIfPresent() {
                    _ = EditorWindowCoordinator.shared.routeOpenedDocuments(
                        [uiTestFLACURL],
                        appIsActive: NSApp.isActive
                    )
                }
            }
            .keyboardShortcut("o", modifiers: [.command, .option])
            .disabled(showAddReadOnlyFlacImporter == nil && uiTestMenuFlacURLIfPresent() == nil)
            .modifierKeyAlternate(.shift) {
                Button("Add FLAC files (read-only)(replace existing)...") {
                    showReadOnlyFlacImporter?()
                }
                .disabled(showReadOnlyFlacImporter == nil)
            }

            Button("Open SwiftTag Document...") {
                openSwiftTagDocument()
            }
            .keyboardShortcut("o", modifiers: [.control])
            
            Divider()

            Button("Close Window") {
                closeKeyWindow()
            }
            .keyboardShortcut("w")

            Divider()

            Button(toggleSelectedTrackLocksTitle ?? "Toggle Selected Tracks Lock") {
                performToggleSelectedTrackLocks?()
            }
            .keyboardShortcut("l", modifiers: [.control])
            .disabled(!(canPerformToggleSelectedTrackLocks ?? false))

            Divider()

            Button(setTrackTotalTitle ?? "Set Track Total (0)") {
                performSetTrackTotal?()
            }
            .disabled(!(canPerformSetTrackTotal ?? false))

            Divider()

            Button(reloadSelectedTracksTitle ?? "Reload Selected Tracks") {
                performReloadSelectedTracks?()
            }
            .disabled(!(canPerformReloadSelectedTracks ?? false))

            Button(removeSelectedTracksTitle ?? "Remove Selected Tracks") {
                performRemoveSelectedTracks?()
            }
            .disabled(!(canPerformRemoveSelectedTracks ?? false))

            Divider()

            Button("Show TOML...") {
                showTomlSheet?()
            }
            .disabled(showTomlSheet == nil)
        }

        CommandGroup(before: .toolbar) {
            Button(pictureBrowserMenuTitle ?? "Show Picture Browser") {
                togglePictureBrowser?()
            }
            .keyboardShortcut("1")
            .disabled(!(canTogglePictureBrowser ?? false))

            Divider()
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                performDefaultSave?()
            }
            .keyboardShortcut("s")
            .disabled(!(canPerformDefaultSave ?? false))
            .modifierKeyAlternate(.shift) {
                Button("Save Tags") {
                    performSaveTagsOnly?()
                }
                .disabled(!(canPerformSaveTagsOnly ?? false))
            }
            .modifierKeyAlternate(.option) {
                Button("Save Pictures") {
                    performSavePicturesOnly?()
                }
                .disabled(!(canPerformSavePicturesOnly ?? false))
            }
        }

        CommandGroup(after: .saveItem) {
            Button("Save SwiftTag Document...") {
                performSaveSwiftTagDocument?()
            }
            .keyboardShortcut("s", modifiers: [.control])
            .disabled(!(canPerformSaveSwiftTagDocument ?? false))
        }
    }

    private func openSwiftTagDocument() {
        if let uiTestDocumentURL = uiTestOpenSwiftTagDocumentURLIfPresent() {
            _ = EditorWindowCoordinator.shared.routeOpenedDocuments(
                [uiTestDocumentURL],
                appIsActive: NSApp.isActive
            )
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.swiftTagDocument]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.resolvesAliases = true

        guard openPanel.runModal() == .OK else {
            return
        }

        _ = EditorWindowCoordinator.shared.routeOpenedSwiftTagDocuments(openPanel.urls)
    }

    private func closeKeyWindow() {
        if NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil) {
            return
        }

        if let keyWindow = NSApp.keyWindow {
            keyWindow.performClose(nil)
            return
        }

        NSApp.mainWindow?.performClose(nil)
    }

    private func uiTestOpenSwiftTagDocumentURLIfPresent() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        if let rawPath = environment["UITEST_OPEN_SWIFTTAG_PATH"],
           !rawPath.isEmpty {
            return URL(fileURLWithPath: rawPath)
        }

        guard let rawPath = uiTestControlValueIfPresent(fileName: "open-swifttag-path.txt") else {
            return nil
        }

        return URL(fileURLWithPath: rawPath)
    }

    private func uiTestMenuFlacURLIfPresent() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        if let materializedURL = uiTestMaterializedFLACURL(
            pathValue: environment["UITEST_MENU_FLAC_PATH"],
            dataValue: environment["UITEST_MENU_FLAC_DATA_BASE64"],
            fileStem: "SwiftTagUITestMenuFixture",
            albumMode: environment["UITEST_MENU_FLAC_ALBUM_MODE"],
            titleOverride: environment["UITEST_MENU_FLAC_TITLE_OVERRIDE"],
            pictureProfile: environment["UITEST_MENU_FLAC_PICTURE_PROFILE"]
        ) {
            return materializedURL
        }

        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-UITEST_MENU_FLAC_PATH") else {
            return nil
        }

        let valueIndex = arguments.index(after: keyIndex)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        let rawPath = arguments[valueIndex]
        return rawPath.isEmpty ? nil : URL(fileURLWithPath: rawPath)
    }

    private func uiTestMaterializedFLACURL(
        pathValue: String?,
        dataValue: String?,
        fileStem: String,
        albumMode: String?,
        titleOverride: String?,
        pictureProfile: String?
    ) -> URL? {
        let trimmedPath = pathValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathExtension = URL(fileURLWithPath: trimmedPath ?? "").pathExtension
        guard let dataValue,
              let fileData = Data(base64Encoded: dataValue) else {
            guard let trimmedPath, !trimmedPath.isEmpty else {
                return nil
            }
            return URL(fileURLWithPath: trimmedPath)
        }

        let fileURL = uiTestMaterializedFLACDirectoryURL()
            .appendingPathComponent(fileStem)
            .appendingPathExtension(pathExtension.isEmpty ? "flac" : pathExtension)
        try? fileData.write(to: fileURL, options: .atomic)
        try? UITestFlacOverrideWriter.applyOverrides(
            to: fileURL,
            albumMode: albumMode,
            titleOverride: titleOverride,
            pictureProfile: pictureProfile
        )
        return fileURL
    }

    private func uiTestMaterializedFLACDirectoryURL() -> URL {
        let directoryURL = (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("SwiftTagUITestFixtures", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func uiTestControlValueIfPresent(fileName: String) -> String? {
        let controlURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("SwiftTagUITestControls", isDirectory: true)
            .appendingPathComponent(fileName)

        guard let rawValue = try? String(contentsOf: controlURL, encoding: .utf8) else {
            return nil
        }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

@main
struct SwiftTagApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(FeedbackSettingsKey.themePreference)
    private var themePreferenceRawValue: String = FeedbackSettingsDefaults.themePreference.rawValue

    private var preferredScheme: ColorScheme? {
        (AppThemePreference(rawValue: themePreferenceRawValue) ?? FeedbackSettingsDefaults.themePreference).preferredColorScheme
    }

    init() {
        resetUITestSaveSettingsIfNeeded()
        applyUITestSaveSettingsOverridesIfNeeded()
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
                .preferredColorScheme(preferredScheme)
        }

        UtilityWindow("Diff Tools", id: AppSceneID.diffTools) {
            DiffToolsView()
                .frame(width: 278, height: 170)
                .preferredColorScheme(preferredScheme)
        }
        .keyboardShortcut("d", modifiers: [.command])
        .windowResizability(.contentSize)
        .windowIdealSize(.fitToContent)
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

    private func applyUITestSaveSettingsOverridesIfNeeded() {
        let environment = ProcessInfo.processInfo.environment

        if let rawValue = environment["UITEST_SAVE_REFERENCED_SWIFTTAG_DOCUMENT"] {
            UserDefaults.standard.set(rawValue == "1", forKey: SaveSettingsKey.saveReferencedSwiftTagDocument)
        }

        if let rawValue = environment["UITEST_ASK_TO_SAVE_NEW_SWIFTTAG_DOCUMENT"] {
            UserDefaults.standard.set(rawValue == "1", forKey: SaveSettingsKey.askToSaveNewSwiftTagDocument)
        }
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
