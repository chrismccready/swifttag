//
//  SwiftTagUITests.swift
//  SwiftTagUITests
//
//  Created by Christopher McCready on 2/24/26.
//

import XCTest

final class SwiftTagUITests: XCTestCase {
    private static let fixtureDirectoryName = "SwiftTagTestFiles"
    private static let fixtureFileName = "test.flac"

    private enum UIID {
        static let addMiscTagButton = "miscTags.addButton"
        static let deleteMiscTagButton = "miscTags.deleteButton"
        static let miscTagTable = "miscTags.table"
        static let miscTagKeyFieldPrefix = "miscTags.keyField."
        static let albumTextField = "albumTextField"
        static let albumArtistTextField = "albumArtistTextField"
        static let albumArtImageWell = "albumArtImageWell"
        static let albumArtSheetImageWell = "albumArt.sheet.imageWell"
        static let albumArtSheetImageWellState = "albumArt.sheet.imageWell.state"
        static let albumArtSheetSaveStatusView = "albumArt.sheet.saveStatusView"
        static let albumArtSheetSaveStatusVisible = "albumArt.sheet.saveStatusVisible"
        static let saveStatusView = "saveStatusView"
        static let settingsTabView = "settings.tabView"
        static let defaultSavePayload = "settings.general.defaultSavePayload"
        static let defaultSaveScope = "settings.general.defaultSaveScope"
        static let zeroPadTrackNumber = "settings.tags.zeroPadTrackNumber"
        static let trackCountKeyStrategy = "settings.tags.trackCountKeyStrategy"
        static let zeroPadDiscNumber = "settings.tags.zeroPadDiscNumber"
        static let discCountKeyStrategy = "settings.tags.discCountKeyStrategy"
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
    func testMiscTagsAddAndDeleteRow() throws {
        let app = try launchApp()

        let initialCount = miscTagKeyFields(in: app).count
        addMiscTagRow(in: app, key: "CUSTOM_ROW_A")
        XCTAssertTrue(waitForMiscTagKeyFieldCount(in: app, toBe: initialCount + 1))
        XCTAssertTrue(miscTagKeyField(in: app, key: "CUSTOM_ROW_A").exists)

        miscTagKeyField(in: app, key: "CUSTOM_ROW_A").tap()
        app.buttons[UIID.deleteMiscTagButton].tap()

        XCTAssertTrue(waitForMiscTagKeyFieldCount(in: app, toBe: initialCount))
        XCTAssertFalse(miscTagKeyField(in: app, key: "CUSTOM_ROW_A").exists)
    }

    @MainActor
    func testMiscTagsNewRowWithExplicitKeyIsRemovedOnBlur() throws {
        let app = try launchApp()

        let initialCount = miscTagKeyFields(in: app).count
        addMiscTagRow(in: app, key: "TITLE")
        XCTAssertTrue(waitForMiscTagKeyFieldCount(in: app, toBe: initialCount))
        XCTAssertFalse(miscTagKeyField(in: app, key: "TITLE").exists)
    }

    @MainActor
    func testMiscTagsNewRowWithDuplicateKeyIsRemovedOnBlur() throws {
        let app = try launchApp()

        addMiscTagRow(in: app, key: "DUPLICATE_BASE")
        let committedCount = miscTagKeyFields(in: app).count

        addMiscTagRow(in: app, key: "DUPLICATE_BASE")
        XCTAssertTrue(waitForMiscTagKeyFieldCount(in: app, toBe: committedCount))
    }

    @MainActor
    func testMiscTagsExistingRowDuplicateEditRevertsToOriginalKey() throws {
        let app = try launchApp()

        addMiscTagRow(in: app, key: "ORIGINAL_KEY")
        XCTAssertTrue(miscTagKeyField(in: app, key: "ORIGINAL_KEY").waitForExistence(timeout: 2.0))
        addMiscTagRow(in: app, key: "OTHER_KEY")
        XCTAssertTrue(miscTagKeyField(in: app, key: "OTHER_KEY").waitForExistence(timeout: 2.0))

        let editedField = miscTagKeyField(in: app, key: "OTHER_KEY")
        XCTAssertTrue(editedField.waitForExistence(timeout: 2.0))
        clearAndType(in: app, element: editedField, text: "ORIGINAL_KEY")
        app.textFields[UIID.albumTextField].tap()

        XCTAssertTrue(miscTagKeyField(in: app, key: "OTHER_KEY").waitForExistence(timeout: 2.0))
        XCTAssertEqual(
            miscTagKeyFields(in: app).matching(NSPredicate(format: "value == %@", "ORIGINAL_KEY")).count,
            1
        )
    }

    @MainActor
    func testAlbumArtWellOpensAlbumArtSheet() throws {
        let app = try launchApp()
        let albumArtWell = app.descendants(matching: .any)
            .matching(identifier: UIID.albumArtImageWell)
            .firstMatch
        XCTAssertTrue(albumArtWell.waitForExistence(timeout: 2.0))
    }

    @MainActor
    func testFlacFixtureImportBindsExpectedValues() throws {
        let app = try launchApp(importFixture: true)

        XCTAssertTrue(
            waitForTextFieldValue(in: app, identifier: UIID.albumTextField, expectedValue: "Test Album"),
            """
            Album field value was \(String(describing: app.textFields[UIID.albumTextField].value)).
            Import alert exists: \(app.alerts["FLAC Import Error"].exists).
            """
        )
        XCTAssertTrue(
            waitForTextFieldValue(in: app, identifier: UIID.albumArtistTextField, expectedValue: "Test AlbumArtist"),
            "Album Artist field value was \(String(describing: app.textFields[UIID.albumArtistTextField].value))"
        )
        XCTAssertTrue(
            miscTagKeyField(in: app, key: "ENCODED_BY").waitForExistence(timeout: 2.0),
            "ENCODED_BY field was not found"
        )
    }

    @MainActor
    func testSimulatedSaveDisablesEditorControlsAndShowsOverlay() throws {
        let app = try launchApp(
            simulateSaveStatus: true,
            simulatedSaveScope: "allTracks"
        )

        let saveStatusView = app.descendants(matching: .any)
            .matching(identifier: UIID.saveStatusView)
            .firstMatch
        XCTAssertTrue(saveStatusView.waitForExistence(timeout: 2.0))
        XCTAssertFalse(app.textFields[UIID.albumTextField].isEnabled)
        XCTAssertFalse(app.textFields[UIID.albumArtistTextField].isEnabled)
    }

    @MainActor
    func testSimulatedSaveShowsOverlayInsideAlbumArtSheet() throws {
        let app = try launchApp(
            openAlbumArtSheet: true,
            simulateSaveStatus: true,
            simulatedSaveScope: "selectedTracks",
            simulatedSaveDelay: 0.5
        )

        let sheet = app.descendants(matching: .any)
            .matching(identifier: "albumArt.sheet")
            .firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 4.0))

        let saveStatusView = app.descendants(matching: .any)
            .matching(identifier: UIID.saveStatusView)
            .firstMatch
        XCTAssertTrue(saveStatusView.waitForExistence(timeout: 2.0))
        XCTAssertTrue(waitForElementValue(of: sheet, expectedValue: "imageWellDisabled"))
    }

    @MainActor
    func testSimulatedSaveReEnablesEditorAfterCompletion() throws {
        let app = try launchApp(
            simulateSaveStatus: true,
            simulatedSaveScope: "allTracks",
            simulatedSaveDelay: 0.2,
            simulatedSaveDuration: 1.0
        )

        XCTAssertTrue(waitForEnabledState(of: app.textFields[UIID.albumTextField], expectedValue: false, timeout: 2.0))
        XCTAssertTrue(waitForEnabledState(of: app.textFields[UIID.albumTextField], expectedValue: true, timeout: 4.0))
    }

    @MainActor
    func testSettingsWindowPersistsSavePreferencesAcrossRelaunch() throws {
        let app = try launchApp(resetSaveSettings: true)

        openSettings(in: app)
        XCTAssertTrue(settingsControl(in: app, identifier: UIID.settingsTabView).waitForExistence(timeout: 2.0))

        selectRadioButton(in: app, titled: "Write Pictures")
        selectRadioButton(in: app, titled: "Write to Selected Tracks")
        clickSettingsTab(in: app, named: "Tags")
        XCTAssertTrue(settingsControl(in: app, identifier: UIID.zeroPadTrackNumber).waitForExistence(timeout: 2.0))
        selectRadioButton(in: app, titled: "TRACKTOTAL")
        XCTAssertTrue(settingsControl(in: app, identifier: UIID.zeroPadDiscNumber).waitForExistence(timeout: 2.0))
        selectRadioButton(in: app, titled: "DISCTOTAL")

        app.terminate()

        let relaunchedApp = try launchApp(resetSaveSettings: false)
        openSettings(in: relaunchedApp)
        clickSettingsTab(in: relaunchedApp, named: "General")

        XCTAssertTrue(radioButton(in: relaunchedApp, titled: "Write Pictures").isSelected)
        XCTAssertTrue(radioButton(in: relaunchedApp, titled: "Write to Selected Tracks").isSelected)
        clickSettingsTab(in: relaunchedApp, named: "Tags")
        XCTAssertTrue(settingsControl(in: relaunchedApp, identifier: UIID.zeroPadTrackNumber).waitForExistence(timeout: 2.0))
        XCTAssertTrue(radioButton(in: relaunchedApp, titled: "TRACKTOTAL").isSelected)
        XCTAssertTrue(settingsControl(in: relaunchedApp, identifier: UIID.zeroPadDiscNumber).waitForExistence(timeout: 2.0))
        XCTAssertTrue(radioButton(in: relaunchedApp, titled: "DISCTOTAL").isSelected)
    }

    @MainActor
    func testFileMenuSaveTagsPersistsTagEditsAcrossRelaunch() throws {
        let destinationName = "save-tags-\(UUID().uuidString)"
        let app = try launchApp(
            importFixture: true,
            persistentFixtureName: destinationName,
            resetSaveSettings: true
        )

        clearAndType(in: app, element: app.textFields[UIID.albumTextField], text: "Saved By Menu Tags")
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save Tags...")
        XCTAssertFalse(app.alerts["Save Error"].waitForExistence(timeout: 1.0))

        app.terminate()

        let relaunchedApp = try launchApp(
            importFixture: true,
            persistentFixtureName: destinationName,
            reuseImportedFixture: true,
            resetSaveSettings: false
        )
        XCTAssertTrue(
            waitForTextFieldValue(
                in: relaunchedApp,
                identifier: UIID.albumTextField,
                expectedValue: "Saved By Menu Tags"
            )
        )
    }

    @MainActor
    func testFileMenuSavePicturesDoesNotPersistTagOnlyEditsAcrossRelaunch() throws {
        let destinationName = "save-pictures-\(UUID().uuidString)"
        let app = try launchApp(
            importFixture: true,
            persistentFixtureName: destinationName,
            resetSaveSettings: true
        )

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

        openSettings(in: app)
        selectRadioButton(in: app, titled: "Write Pictures")
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
        fixtureFileName: String = "test.flac",
        persistentFixtureName: String? = nil,
        reuseImportedFixture: Bool = false,
        openAlbumArtSheet: Bool = false,
        simulateSaveStatus: Bool = false,
        simulatedSaveScope: String = "allTracks",
        simulatedSaveDelay: TimeInterval = 0,
        simulatedSaveDuration: TimeInterval = 0,
        resetSaveSettings: Bool = true,
        openSaveNotificationRecordID: String? = nil,
        waitForEditorUI: Bool = true
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
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
            if let persistentFixtureName {
                app.launchEnvironment["UITEST_FLAC_DESTINATION_NAME"] = persistentFixtureName
            }
            if reuseImportedFixture {
                app.launchEnvironment["UITEST_REUSE_IMPORTED_FLAC"] = "1"
            }
        }
        if openAlbumArtSheet {
            app.launchEnvironment["UITEST_OPEN_ALBUM_ART_SHEET"] = "1"
            app.launchArguments.append("-UITEST_OPEN_ALBUM_ART_SHEET")
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
            XCTAssertTrue(app.textFields[UIID.albumTextField].waitForExistence(timeout: 10.0))
        }
        return app
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

    private func addMiscTagRow(in app: XCUIApplication, key: String) {
        let countBefore = miscTagKeyFields(in: app).count

        app.buttons[UIID.addMiscTagButton].tap()
        XCTAssertTrue(waitForMiscTagKeyFieldCount(in: app, toBe: countBefore + 1))

        let newField = miscTagKeyFields(in: app).element(boundBy: countBefore)
        XCTAssertTrue(newField.waitForExistence(timeout: 2.0))
        typeIntoNewField(newField, text: key)
        app.textFields[UIID.albumTextField].tap()
    }

    private func typeIntoNewField(_ element: XCUIElement, text: String) {
        element.tap()
        element.typeText(text)
    }

    private func clearAndType(in app: XCUIApplication, element: XCUIElement, text: String) {
        element.tap()
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
        app.typeKey("a", modifierFlags: .command)
        app.typeText(text)
    }

    private func miscTagKeyFields(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", UIID.miscTagKeyFieldPrefix))
    }

    private func miscTagKeyField(in app: XCUIApplication, key: String) -> XCUIElement {
        miscTagKeyFields(in: app)
            .matching(NSPredicate(format: "value == %@", key))
            .firstMatch
    }

    private func waitForMiscTagKeyFieldCount(
        in app: XCUIApplication,
        toBe expectedCount: Int,
        timeout: TimeInterval = 2.0
    ) -> Bool {
        let query = miscTagKeyFields(in: app)
        let predicate = NSPredicate(format: "count == %d", expectedCount)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: query)

        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
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
            if element.label == expectedLabel {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func waitForElementValue(
        of element: XCUIElement,
        expectedValue: String,
        timeout: TimeInterval = 2.0
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.label == expectedValue {
                return true
            }

            if let value = element.value as? String, value == expectedValue {
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
