//
//  SwiftTagUITests.swift
//  SwiftTagUITests
//
//  Created by Christopher McCready on 2/24/26.
//

import XCTest
import AppKit

final class SwiftTagUITests: XCTestCase {
    private static let appBundleIdentifier = "com.toowalks.swifttag"
    private static let fixtureDirectoryName = "SwiftTagTestFiles"
    private static let fixtureFileName = "test.flac"

    private enum UIID {
        static let addMiscTagButton = "miscTags.addButton"
        static let deleteMiscTagButton = "miscTags.deleteButton"
        static let miscTagTable = "miscTags.table"
        static let miscTagKeyFieldPrefix = "miscTags.keyField."
        static let albumTextField = "albumTextField"
        static let albumArtistTextField = "albumArtistTextField"
        static let settingsTabView = "settings.tabView"
        static let defaultSavePayload = "settings.general.defaultSavePayload"
        static let defaultSaveScope = "settings.general.defaultSaveScope"
        static let zeroPadTrackNumber = "settings.tags.zeroPadTrackNumber"
        static let trackCountKeyStrategy = "settings.tags.trackCountKeyStrategy"
        static let zeroPadDiscNumber = "settings.tags.zeroPadDiscNumber"
        static let discCountKeyStrategy = "settings.tags.discCountKeyStrategy"
    }

    private enum PlaceholderText {
        static let noSelection = "Select track(s) to..."
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testFileMenuContainsReadOnlyLoadCommand() throws {
        let app = try launchApp()
        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 2.0))
        fileMenu.click()

        let readOnlyMenuItem = app.menuItems["Load FLAC files (read-only)..."].firstMatch
        XCTAssertTrue(readOnlyMenuItem.waitForExistence(timeout: 2.0))
    }

    @MainActor
    func testFileMenuContainsSwiftTagDocumentCommandAndStartsDisabled() throws {
        let app = try launchApp()
        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 2.0))
        fileMenu.click()

        let swiftTagMenuItem = app.menuItems["Save SwiftTag Document..."].firstMatch
        XCTAssertTrue(swiftTagMenuItem.waitForExistence(timeout: 2.0))
        XCTAssertFalse(swiftTagMenuItem.isEnabled)
    }

    @MainActor
    func testFileMenuContainsOpenSwiftTagDocumentCommand() throws {
        let app = try launchApp()
        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 2.0))
        fileMenu.click()

        let openSwiftTagMenuItem = app.menuItems["Open SwiftTag Document..."].firstMatch
        XCTAssertTrue(openSwiftTagMenuItem.waitForExistence(timeout: 2.0))
    }

    @MainActor
    func testFileMenuEnablesSwiftTagDocumentCommandWhenTracksAreLoaded() throws {
        let app = try launchApp(importFixture: true)
        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title")

        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 2.0))
        fileMenu.click()

        let swiftTagMenuItem = app.menuItems["Save SwiftTag Document..."].firstMatch
        XCTAssertTrue(swiftTagMenuItem.waitForExistence(timeout: 2.0))
        XCTAssertTrue(swiftTagMenuItem.isEnabled)
    }

    @MainActor
    func testLaunchDocumentOpenImportsFlacFixture() throws {
        let app = try launchApp(
            openDocumentFixture: true,
            waitForEditorUI: false
        )

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 10.0)
        XCTAssertTrue(
            waitForTextFieldValue(
                in: app,
                identifier: UIID.albumTextField,
                expectedValue: "Test Album",
                timeout: 5.0
            )
        )
    }

    @MainActor
    func testReopeningClosedSwiftTagDocumentReloadsDocumentContents() throws {
        let savedAlbum = "Saved UI Album \(UUID().uuidString)"
        let savedTitle = "Saved Document Title \(UUID().uuidString)"
        let flacURL = try prepareReadableFlacFixture(fileName: Self.fixtureFileName)
        let swiftTagDocumentURL = try prepareSwiftTagDocumentFixture(
            sourceFlacURL: flacURL,
            savedAlbum: savedAlbum,
            savedTitle: savedTitle
        )

        let app = try launchApp()

        XCTAssertTrue(waitForWindowCount(in: app, minimumCount: 1, timeout: 5.0))
        let initialWindowCount = currentWindowCount(in: app)
        XCTAssertGreaterThanOrEqual(initialWindowCount, 1)

        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(waitForWindowCount(in: app, minimumCount: initialWindowCount + 1, timeout: 5.0))

        app.activate()
        XCTAssertTrue(openFileWithSwiftTag(url: flacURL))
        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title")

        app.activate()
        XCTAssertTrue(openFileWithSwiftTag(url: swiftTagDocumentURL))
        XCTAssertTrue(waitForTextFieldValueAnywhere(in: app, expectedValue: savedTitle, timeout: 10.0))

        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(waitForTextFieldValueAnywhere(in: app, expectedValue: savedTitle, timeout: 2.0) == false)

        app.activate()
        XCTAssertTrue(openFileWithSwiftTag(url: swiftTagDocumentURL))
        XCTAssertTrue(waitForTextFieldValueAnywhere(in: app, expectedValue: savedTitle, timeout: 10.0))
    }

    @MainActor
    func testSimulatedSaveReEnablesEditorAfterCompletion() throws {
        let app = try launchApp(
            importFixture: true,
            simulateSaveStatus: true,
            simulatedSaveScope: "allTracks",
            simulatedSaveDelay: 0.2,
            simulatedSaveDuration: 1.0
        )

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title")
        XCTAssertTrue(waitForEnabledState(of: app.textFields[UIID.albumTextField], expectedValue: true, timeout: 5.0))
    }

    @MainActor
    func testSettingsWindowPersistsSavePreferencesAcrossRelaunch() throws {
        let app = try launchApp(resetSaveSettings: true)

        openSettings(in: app)
        XCTAssertTrue(settingsControl(in: app, identifier: UIID.settingsTabView).waitForExistence(timeout: 2.0))

        selectOption(in: app, titled: "Pictures")
        selectOption(in: app, titled: "Selected Tracks")
        clickSettingsTab(in: app, named: "Tags")
        XCTAssertTrue(settingsControl(in: app, identifier: UIID.zeroPadTrackNumber).waitForExistence(timeout: 2.0))
        setToggle(in: app, identifier: UIID.zeroPadTrackNumber, isOn: false)
        XCTAssertTrue(settingsControl(in: app, identifier: UIID.zeroPadDiscNumber).waitForExistence(timeout: 2.0))
        setToggle(in: app, identifier: UIID.zeroPadDiscNumber, isOn: false)

        app.terminate()

        let relaunchedApp = try launchApp(resetSaveSettings: false)
        openSettings(in: relaunchedApp)
        clickSettingsTab(in: relaunchedApp, named: "General")

        XCTAssertTrue(settingsControl(in: relaunchedApp, identifier: UIID.defaultSavePayload).waitForExistence(timeout: 2.0))
        XCTAssertTrue(settingsControl(in: relaunchedApp, identifier: UIID.defaultSaveScope).waitForExistence(timeout: 2.0))
        clickSettingsTab(in: relaunchedApp, named: "Tags")
        XCTAssertTrue(settingsControl(in: relaunchedApp, identifier: UIID.zeroPadTrackNumber).waitForExistence(timeout: 2.0))
        XCTAssertFalse(isToggleOn(in: relaunchedApp, identifier: UIID.zeroPadTrackNumber))
        XCTAssertTrue(settingsControl(in: relaunchedApp, identifier: UIID.zeroPadDiscNumber).waitForExistence(timeout: 2.0))
        XCTAssertFalse(isToggleOn(in: relaunchedApp, identifier: UIID.zeroPadDiscNumber))
    }

    @MainActor
    func testFileMenuSavePicturesDoesNotPersistTagOnlyEditsAcrossRelaunch() throws {
        let destinationName = "save-pictures-\(UUID().uuidString)"
        let app = try launchApp(
            importFixture: true,
            persistentFixtureName: destinationName,
            resetSaveSettings: true
        )

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title")
        clearAndType(in: app, element: app.textFields[UIID.albumTextField], text: "Should Not Persist")
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save Pictures...")
        XCTAssertFalse(app.alerts["Save Error"].waitForExistence(timeout: 1.0))

        app.terminate()

        let relaunchedApp = try launchApp(
            importFixture: true,
            persistentFixtureName: destinationName,
            reuseImportedFixture: true,
            resetSaveSettings: false
        )
        selectImportedTrackForEditing(in: relaunchedApp, expectedTitle: "Test Title")
        XCTAssertTrue(
            waitForTextFieldValue(
                in: relaunchedApp,
                identifier: UIID.albumTextField,
                expectedValue: "Test Album"
            )
        )
    }

    @MainActor
    func testFileMenuSaveUsesPersistedDefaultPayloadAcrossRelaunch() throws {
        let destinationName = "save-default-\(UUID().uuidString)"
        let app = try launchApp(
            importFixture: true,
            persistentFixtureName: destinationName,
            resetSaveSettings: true
        )

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title")
        openSettings(in: app)
        selectOption(in: app, titled: "Pictures")
        typeEscape(in: app)

        clearAndType(in: app, element: app.textFields[UIID.albumTextField], text: "Default Save Should Not Persist")
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")
        XCTAssertFalse(app.alerts["Save Error"].waitForExistence(timeout: 1.0))

        app.terminate()

        let relaunchedApp = try launchApp(
            importFixture: true,
            persistentFixtureName: destinationName,
            reuseImportedFixture: true,
            resetSaveSettings: false
        )
        selectImportedTrackForEditing(in: relaunchedApp, expectedTitle: "Test Title")
        XCTAssertTrue(
            waitForTextFieldValue(
                in: relaunchedApp,
                identifier: UIID.albumTextField,
                expectedValue: "Test Album"
            )
        )
    }

    private func launchApp(
        importFixture: Bool = false,
        importFixtureReadOnly: Bool = false,
        fixtureFileName: String = "test.flac",
        openDocumentFixture: Bool = false,
        openDocumentWhileActive: Bool = false,
        menuImportFixturePath: String? = nil,
        persistentFixtureName: String? = nil,
        reuseImportedFixture: Bool = false,
        openAlbumArtSheet: Bool = false,
        simulateSaveStatus: Bool = false,
        simulatedSaveScope: String = "allTracks",
        simulatedSaveDelay: TimeInterval = 0,
        simulatedSaveDuration: TimeInterval = 0,
        saveSwiftTagDocumentPath: String? = nil,
        openSwiftTagDocumentPath: String? = nil,
        resetSaveSettings: Bool = true,
        openSaveNotificationRecordID: String? = nil,
        waitForEditorUI: Bool = true
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ApplePersistenceIgnoreState"] = "YES"
        app.launchArguments.append(contentsOf: ["-ApplePersistenceIgnoreState", "YES"])
        if resetSaveSettings {
            app.launchEnvironment["UITEST_RESET_SAVE_SETTINGS"] = "1"
            app.launchArguments.append("-UITEST_RESET_SAVE_SETTINGS")
        }
        if importFixture {
            let fixturePath = fixtureFlacPath(fileName: fixtureFileName)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: fixturePath),
                "UI test fixture was not found at \(fixturePath)"
            )
            let fixtureDataBase64 = try Data(contentsOf: URL(fileURLWithPath: fixturePath)).base64EncodedString()
            app.launchEnvironment["UITEST_FLAC_PATH"] = fixturePath
            app.launchEnvironment["UITEST_FLAC_DATA_BASE64"] = fixtureDataBase64
            if importFixtureReadOnly {
                app.launchEnvironment["UITEST_FLAC_READ_ONLY"] = "1"
                app.launchArguments.append("-UITEST_FLAC_READ_ONLY")
            }
            if let persistentFixtureName {
                app.launchEnvironment["UITEST_FLAC_DESTINATION_NAME"] = persistentFixtureName
            }
            if reuseImportedFixture {
                app.launchEnvironment["UITEST_REUSE_IMPORTED_FLAC"] = "1"
            }
        }
        if openDocumentFixture {
            let fixturePath = fixtureFlacPath(fileName: fixtureFileName)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: fixturePath),
                "UI test fixture was not found at \(fixturePath)"
            )
            let fixtureDataBase64 = try Data(contentsOf: URL(fileURLWithPath: fixturePath)).base64EncodedString()
            app.launchEnvironment["UITEST_OPEN_DOCUMENT_FLAC_PATH"] = fixturePath
            app.launchEnvironment["UITEST_OPEN_DOCUMENT_FLAC_DATA_BASE64"] = fixtureDataBase64
            if openDocumentWhileActive {
                app.launchEnvironment["UITEST_OPEN_DOCUMENT_WHILE_ACTIVE"] = "1"
                app.launchArguments.append("-UITEST_OPEN_DOCUMENT_WHILE_ACTIVE")
            }
        }
        if let menuImportFixturePath {
            app.launchEnvironment["UITEST_MENU_FLAC_PATH"] = menuImportFixturePath
            app.launchArguments.append("-UITEST_MENU_FLAC_PATH")
            app.launchArguments.append(menuImportFixturePath)
        }
        if openAlbumArtSheet {
            app.launchEnvironment["UITEST_OPEN_ALBUM_ART_SHEET"] = "1"
            app.launchArguments.append("-UITEST_OPEN_ALBUM_ART_SHEET")
        }
        if let saveSwiftTagDocumentPath {
            app.launchEnvironment["UITEST_SAVE_SWIFTTAG_PATH"] = saveSwiftTagDocumentPath
            app.launchArguments.append("-UITEST_SAVE_SWIFTTAG_PATH")
            app.launchArguments.append(saveSwiftTagDocumentPath)
        }
        if let openSwiftTagDocumentPath {
            app.launchEnvironment["UITEST_OPEN_SWIFTTAG_PATH"] = openSwiftTagDocumentPath
            app.launchArguments.append("-UITEST_OPEN_SWIFTTAG_PATH")
            app.launchArguments.append(openSwiftTagDocumentPath)
        }
        if simulateSaveStatus {
            app.launchEnvironment["UITEST_SIMULATE_SAVE_STATUS"] = "1"
            app.launchEnvironment["UITEST_SIMULATED_SAVE_SCOPE"] = simulatedSaveScope
            if simulatedSaveDelay > 0 {
                app.launchEnvironment["UITEST_SIMULATED_SAVE_DELAY"] = String(simulatedSaveDelay)
            }
            if simulatedSaveDuration > 0 {
                app.launchEnvironment["UITEST_SIMULATED_SAVE_DURATION"] = String(simulatedSaveDuration)
            }
        }
        if let openSaveNotificationRecordID {
            app.launchEnvironment["UITEST_OPEN_SAVE_NOTIFICATION_RECORD_ID"] = openSaveNotificationRecordID
            app.launchArguments.append("-UITEST_OPEN_SAVE_NOTIFICATION_RECORD_ID")
            app.launchArguments.append(openSaveNotificationRecordID)
        }
        app.launch()
        if waitForEditorUI {
            XCTAssertTrue(
                waitForWindowCount(in: app, minimumCount: 1, timeout: 10.0)
                    || app.textFields[UIID.albumTextField].waitForExistence(timeout: 2.0)
            )
        }
        return app
    }

    private func prepareSwiftTagDocumentFixture(
        sourceFlacURL: URL,
        savedAlbum: String,
        savedTitle: String
    ) throws -> URL {
        let destinationURL = appContainerCachesDirectoryURL()
            .appendingPathComponent("SwiftTagUITest-\(UUID().uuidString)")
            .appendingPathExtension("swifttag")

        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let infoPlistURL = destinationURL.appendingPathComponent("Info.plist")
        let trackFingerprint = sourceFlacURL.path
        let manifest: [String: Any] = [
            "Id": UUID().uuidString,
            "Version": "1.0.0",
            "Fingerprint": trackFingerprint,
            "Tracks": [
                [
                    "Fingerprint": trackFingerprint,
                    "FLAC File URL": sourceFlacURL.absoluteString,
                    "FLAC Fingerprint": trackFingerprint,
                    "Tags": [
                        "TITLE": savedTitle,
                        "ALBUM": savedAlbum,
                        "TRACKNUMBER": "01",
                        "TOTALTRACKS": "01"
                    ],
                    "Pictures": []
                ]
            ]
        ]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: manifest,
            format: .xml,
            options: 0
        )
        try plistData.write(to: infoPlistURL, options: .atomic)

        return destinationURL
    }

    private func prepareReadableFlacFixture(fileName: String) throws -> URL {
        let sourceURL = URL(fileURLWithPath: fixtureFlacPath(fileName: fileName))
        let destinationDirectoryURL = appContainerCachesDirectoryURL()
            .appendingPathComponent("UITestReadableFixtures", isDirectory: true)
        try FileManager.default.createDirectory(
            at: destinationDirectoryURL,
            withIntermediateDirectories: true
        )

        let destinationURL = destinationDirectoryURL
            .appendingPathComponent("\(UUID().uuidString)-\(fileName)")
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func fixtureFlacPath(fileName: String) -> String {
        let fileManager = FileManager.default
        var searchURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        while true {
            let candidateURL = searchURL
                .appendingPathComponent(Self.fixtureDirectoryName, isDirectory: true)
                .appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL.path
            }

            let parentURL = searchURL.deletingLastPathComponent()
            if parentURL.path == searchURL.path {
                XCTFail("Unable to locate \(Self.fixtureDirectoryName)/\(fileName) from \(#filePath)")
                return candidateURL.path
            }
            searchURL = parentURL
        }
    }

    private func openSettings(in app: XCUIApplication) {
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settingsControl(in: app, identifier: UIID.settingsTabView).waitForExistence(timeout: 2.0))
    }

    private func clickSettingsTab(in app: XCUIApplication, named tabName: String) {
        let tabButton = app.buttons[tabName].firstMatch
        let radioButton = app.radioButtons[tabName].firstMatch
        let didFindTab = tabButton.waitForExistence(timeout: 1.0) || radioButton.waitForExistence(timeout: 1.0)
        XCTAssertTrue(didFindTab)
        let control = tabButton.exists ? tabButton : radioButton
        XCTAssertTrue(control.exists)
        control.tap()
    }

    private func radioButton(in app: XCUIApplication, titled title: String) -> XCUIElement {
        app.radioButtons[title].firstMatch
    }

    private func selectRadioButton(in app: XCUIApplication, titled title: String) {
        let button = radioButton(in: app, titled: title)
        XCTAssertTrue(button.waitForExistence(timeout: 2.0))
        button.tap()
    }

    private func optionControl(in app: XCUIApplication, titled title: String) -> XCUIElement {
        let radioButton = app.radioButtons[title].firstMatch
        if radioButton.waitForExistence(timeout: 0.5) {
            return radioButton
        }

        return app.buttons[title].firstMatch
    }

    private func selectOption(in app: XCUIApplication, titled title: String) {
        let control = optionControl(in: app, titled: title)
        XCTAssertTrue(control.waitForExistence(timeout: 2.0))
        control.tap()
    }

    private func isOptionSelected(in app: XCUIApplication, titled title: String) -> Bool {
        let control = optionControl(in: app, titled: title)
        guard control.waitForExistence(timeout: 2.0) else {
            return false
        }

        if control.elementType == .radioButton {
            return control.isSelected
        }

        if control.isSelected {
            return true
        }

        if let rawValue = control.value as? String {
            return rawValue == "1" || rawValue.lowercased() == "selected"
        }

        if let rawValue = control.value as? NSNumber {
            return rawValue.intValue == 1
        }

        return false
    }

    private func toggle(in app: XCUIApplication, titled title: String) -> XCUIElement {
        app.switches[title].firstMatch
    }

    private func setToggle(in app: XCUIApplication, titled title: String, isOn: Bool) {
        let toggle = toggle(in: app, titled: title)
        XCTAssertTrue(toggle.waitForExistence(timeout: 2.0))
        let currentValue = (toggle.value as? String) == "1"
        if currentValue != isOn {
            toggle.tap()
        }
    }

    private func isToggleOn(in app: XCUIApplication, titled title: String) -> Bool {
        let control = toggle(in: app, titled: title)
        guard control.waitForExistence(timeout: 2.0) else {
            return false
        }

        if let rawValue = control.value as? String {
            let normalizedValue = rawValue.lowercased()
            return normalizedValue == "1" || normalizedValue == "on" || normalizedValue == "selected"
        }

        if let rawValue = control.value as? NSNumber {
            return rawValue.intValue == 1
        }

        return control.isSelected
    }

    private func setToggle(in app: XCUIApplication, identifier: String, isOn: Bool) {
        let toggle = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 2.0))
        let currentValue = isToggleOn(in: app, identifier: identifier)
        if currentValue != isOn {
            toggle.tap()
        }
    }

    private func isToggleOn(in app: XCUIApplication, identifier: String) -> Bool {
        let control = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        guard control.waitForExistence(timeout: 2.0) else {
            return false
        }

        if let rawValue = control.value as? String {
            let normalizedValue = rawValue.lowercased()
            return normalizedValue == "1" || normalizedValue == "on" || normalizedValue == "selected"
        }

        if let rawValue = control.value as? NSNumber {
            return rawValue.intValue == 1
        }

        return control.isSelected
    }

    private func settingsControl(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func clickMenuItem(in app: XCUIApplication, menuBarItem: String, menuItem: String) {
        let menuBarButton = app.menuBars.menuBarItems[menuBarItem]
        XCTAssertTrue(menuBarButton.waitForExistence(timeout: 2.0))
        menuBarButton.click()

        let item = app.menuItems[menuItem].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 2.0))
        item.click()
    }

    private func typeEscape(in app: XCUIApplication) {
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
    }

    private func clearAndType(in app: XCUIApplication, element: XCUIElement, text: String) {
        element.tap()
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
        app.typeKey("a", modifierFlags: .command)
        app.typeText(text)
    }

    private func selectImportedTrackForEditing(
        in app: XCUIApplication,
        expectedTitle: String,
        timeout: TimeInterval = 10.0
    ) {
        let titleField = app.textFields.matching(NSPredicate(format: "value == %@", expectedTitle)).firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: timeout), "Expected imported track title field '\(expectedTitle)' to exist.")
        titleField.click()
        let editableAlbumField = app.textFields.matching(
            NSPredicate(
                format: "identifier == %@ AND value != %@",
                UIID.albumTextField,
                PlaceholderText.noSelection
            )
        ).firstMatch
        XCTAssertTrue(
            waitForEnabledState(of: editableAlbumField, expectedValue: true, timeout: timeout),
            "Album field did not become editable after selecting imported track '\(expectedTitle)'."
        )
    }

    private func waitForTextFieldValue(
        in app: XCUIApplication,
        identifier: String,
        expectedValue: String,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        let textField = app.textFields[identifier]
        guard textField.waitForExistence(timeout: timeout) else {
            return false
        }

        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let value = textField.value as? String, value == expectedValue {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func waitForTextFieldValueAnywhere(
        in app: XCUIApplication,
        expectedValue: String,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expectedValue)
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            if app.textFields.matching(predicate).count > 0 {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func waitForWindowCount(
        in app: XCUIApplication,
        expectedCount: Int,
        timeout: TimeInterval = 5.0
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            if app.windows.allElementsBoundByIndex.count == expectedCount {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func currentWindowCount(in app: XCUIApplication) -> Int {
        app.windows.allElementsBoundByIndex.count
    }

    private func currentWindowIdentifiers(in app: XCUIApplication) -> [String] {
        app.windows.allElementsBoundByIndex.map(windowIdentifier)
    }

    private func waitForNewWindow(
        in app: XCUIApplication,
        excluding existingIdentifiers: Set<String>,
        timeout: TimeInterval
    ) -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            for window in app.windows.allElementsBoundByIndex {
                if !existingIdentifiers.contains(windowIdentifier(window)) {
                    return window
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return app.windows.firstMatch
    }

    private func windowIdentifier(_ window: XCUIElement) -> String {
        let identifier = window.identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if !identifier.isEmpty {
            return identifier
        }

        return window.debugDescription
    }

    private func openFileWithSwiftTag(url: URL, timeout: TimeInterval = 10.0) -> Bool {
        guard let applicationURL = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.appBundleIdentifier)
            .first?
            .bundleURL else {
            XCTFail("SwiftTag app is not running.")
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        let completionExpectation = XCTestExpectation(description: "open \(url.lastPathComponent) in SwiftTag")
        var didOpen = false

        NSWorkspace.shared.open(
            [url],
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { _, error in
            didOpen = (error == nil)
            completionExpectation.fulfill()
        }

        let waitResult = XCTWaiter.wait(for: [completionExpectation], timeout: timeout)
        if waitResult != .completed {
            XCTFail("Timed out opening \(url.lastPathComponent) in SwiftTag.")
            return false
        }

        if let frontmostApp = NSRunningApplication.runningApplications(withBundleIdentifier: Self.appBundleIdentifier).first {
            frontmostApp.activate()
        }

        return didOpen
    }

    private func waitForWindowCount(
        in app: XCUIApplication,
        minimumCount: Int,
        timeout: TimeInterval = 5.0
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            if app.windows.allElementsBoundByIndex.count >= minimumCount {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func waitForFileExistence(at url: URL, timeout: TimeInterval = 5.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            if FileManager.default.fileExists(atPath: url.path) {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func appContainerCachesDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent("com.toowalks.swifttag", isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
    }

    private func chooseFileInOpenPanel(in app: XCUIApplication, path: String) {
        XCTAssertTrue(waitForOpenPanel(in: app, timeout: 5.0))

        app.typeKey("g", modifierFlags: [.command, .shift])

        let goToFolderSheet = app.sheets.firstMatch
        XCTAssertTrue(goToFolderSheet.waitForExistence(timeout: 5.0))

        let pathField = goToFolderSheet.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 5.0))
        pathField.click()
        pathField.typeText(path)
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])

        let openButton = app.buttons["Open"].firstMatch
        XCTAssertTrue(openButton.waitForExistence(timeout: 5.0))
        openButton.click()
    }

    private func waitForOpenPanel(in app: XCUIApplication, timeout: TimeInterval = 5.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            if app.dialogs.firstMatch.exists || app.sheets.firstMatch.exists || app.buttons["Open"].firstMatch.exists {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func waitForLabeledElement(
        in app: XCUIApplication,
        identifier: String,
        expectedLabel: String,
        timeout: TimeInterval = 2.0
    ) -> Bool {
        let element = app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
        guard element.waitForExistence(timeout: timeout) else {
            return false
        }

        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.label.localizedCaseInsensitiveContains(expectedLabel) {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func waitForEnabledState(
        of element: XCUIElement,
        expectedValue: Bool,
        timeout: TimeInterval = 2.0
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists && element.isEnabled == expectedValue {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

}
