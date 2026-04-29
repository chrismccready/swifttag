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
    private static let appleScriptHarnessSentinelPath = "/tmp/SwiftTagRunOsascriptTests"

    private enum UIID {
        static let addMiscTagButton = "miscTags.addButton"
        static let deleteMiscTagButton = "miscTags.deleteButton"
        static let miscTagTable = "miscTags.table"
        static let miscTagKeyFieldPrefix = "miscTags.keyField."
        static let albumTextField = "albumTextField"
        static let albumArtistTextField = "albumArtistTextField"
        static let trackStatusIcon = "trackStatusIcon"
        static let trackFilenameText = "trackFilenameText"
        static let compilationCheckbox = "coreTags.compilationCheckbox"
        static let settingsTabView = "settings.tabView"
        static let defaultSavePayload = "settings.general.defaultSavePayload"
        static let defaultSaveScope = "settings.general.defaultSaveScope"
        static let saveReferencedSwiftTagDocument = "settings.general.saveReferencedSwiftTagDocument"
        static let askToSaveNewSwiftTagDocument = "settings.general.askToSaveNewSwiftTagDocument"
        static let zeroPadTrackNumber = "settings.tags.zeroPadTrackNumber"
        static let trackCountKeyStrategy = "settings.tags.trackCountKeyStrategy"
        static let zeroPadDiscNumber = "settings.tags.zeroPadDiscNumber"
        static let discCountKeyStrategy = "settings.tags.discCountKeyStrategy"
        static let navigationTitleProbe = "uiTest.navigation.title"
        static let navigationSubtitleProbe = "uiTest.navigation.subtitle"
        static let navigationDocumentURLProbe = "uiTest.navigation.documentURL"
        static let saveNewSwiftTagDocumentPromptProbe = "uiTest.saveNewSwiftTagDocumentPrompt"
        static let albumExternalStateProbe = "uiTest.diff.album.externalState"
        static let albumExternalFileValueProbe = "uiTest.diff.album.externalFileValue"
        static let frontCoverPictureExternalStateProbe = "uiTest.diff.picture.frontCover.externalState"
        static let albumArtImageWell = "albumArtImageWell"
        static let albumArtSheet = "albumArt.sheet"
        static let albumArtSheetPictureDescription = "albumArt.sheet.pictureDescription"
        static let albumArtSheetPictureDescriptionEditor = "albumArt.sheet.pictureDescription.editor"
        static let albumArtSheetPictureDescriptionDoneButton = "albumArt.sheet.pictureDescription.doneButton"
        static let albumArtSheetCurrentSlot = "albumArt.sheet.currentSlot"
        static let albumArtSheetExternalDifferenceState = "albumArt.sheet.externalDifferenceState"
        static let albumArtSheetSlotPrefix = "albumArt.sheet.slot."
    }

    private enum PlaceholderText {
        static let noSelection = "Select track(s) to..."
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        try clearUITestControlFiles()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try clearUITestControlFiles()
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

        let readOnlyMenuItem = app.menuItems["Add FLAC files (read-only)..."].firstMatch
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
        XCTAssertTrue(swiftTagMenuItem.isEnabled)
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
    func testDefaultWindowShowsSwiftTagTitleAndNoDocumentURL() throws {
        let app = try launchApp(exposeNavigationMetadata: true)
        let window = app.windows.firstMatch

        XCTAssertTrue(waitForNavigationTitle(in: window, expectedValue: "SwiftTag", timeout: 10.0))
        XCTAssertTrue(waitForNavigationDocumentURL(in: window, expectedValue: "absent", timeout: 10.0))
    }

    @MainActor
    func testNewWindowShowsSwiftTagTitleAndNoDocumentURL() throws {
        let app = try launchApp(exposeNavigationMetadata: true)
        let existingIdentifiers = Set(currentWindowIdentifiers(in: app))

        app.typeKey("n", modifierFlags: .command)

        let newWindow = waitForNewWindow(in: app, excluding: existingIdentifiers, timeout: 10.0)
        XCTAssertTrue(newWindow.waitForExistence(timeout: 10.0))
        XCTAssertTrue(waitForNavigationTitle(in: newWindow, expectedValue: "SwiftTag", timeout: 10.0))
        XCTAssertTrue(waitForNavigationDocumentURL(in: newWindow, expectedValue: "absent", timeout: 10.0))
    }

    @MainActor
    func testImportedFlacWithAlbumShowsAlbumTitleAndNoDocumentURL() throws {
        let app = try launchApp(importFixture: true, exposeNavigationMetadata: true)
        let window = app.windows.firstMatch

        XCTAssertTrue(waitForNavigationTitle(in: window, expectedValue: "Test Album", timeout: 10.0))
        XCTAssertTrue(waitForNavigationDocumentURL(in: window, expectedValue: "absent", timeout: 10.0))
    }

    @MainActor
    func testImportedFlacWithoutAlbumShowsUntitledAndNoDocumentURL() throws {
        let app = try launchApp(
            importFixture: true,
            importedAlbumMode: "empty",
            importedTitleOverride: "No Album Track",
            exposeNavigationMetadata: true
        )
        let window = app.windows.firstMatch

        XCTAssertTrue(waitForNavigationTitle(in: window, expectedValue: "Untitled", timeout: 10.0))
        XCTAssertTrue(waitForNavigationDocumentURL(in: window, expectedValue: "absent", timeout: 10.0))
    }

    @MainActor
    func testTrackTitleEditingKeepsFocusAfterFirstTextChange() throws {
        let app = try launchApp(importFixture: true)

        let originalTitleField = app.textFields.matching(NSPredicate(format: "value == %@", "Test Title")).firstMatch
        XCTAssertTrue(originalTitleField.waitForExistence(timeout: 10.0))

        clearAndType(in: app, element: originalTitleField, text: "Renamed Track")

        XCTAssertTrue(waitForTextFieldValueAnywhere(in: app, expectedValue: "Renamed Track", timeout: 5.0))
    }

    @MainActor
    func testMixedAlbumSelectionUpdatesWindowTitleBetweenAlbumAndUntitled() throws {
        let addFixturePath = fixtureFlacPath(fileName: Self.fixtureFileName)
        let app = try launchApp(
            importFixture: true,
            menuImportFixturePath: addFixturePath,
            menuImportAlbumMode: "empty",
            menuImportTitleOverride: "No Album Track",
            exposeNavigationMetadata: true
        )
        let window = app.windows.firstMatch

        app.activate()
        XCTAssertTrue(waitForWindowCount(in: app, minimumCount: 1, timeout: 10.0))
        XCTAssertTrue(waitForNavigationTitle(in: window, expectedValue: "Test Album", timeout: 10.0))
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Add FLAC files...")

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title")
        XCTAssertTrue(waitForNavigationTitle(in: window, expectedValue: "Test Album", timeout: 10.0))
        XCTAssertTrue(waitForNavigationDocumentURL(in: window, expectedValue: "absent", timeout: 10.0))

        selectImportedTrackForEditing(in: app, expectedTitle: "No Album Track")
        XCTAssertTrue(waitForNavigationTitle(in: window, expectedValue: "Untitled", timeout: 10.0))
        XCTAssertTrue(waitForNavigationDocumentURL(in: window, expectedValue: "absent", timeout: 10.0))
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
    func testAppleScriptHarnessSelectsMatchingTracksInTableOrder() throws {
        try requireAppleScriptHarnessEnabled()

        let firstFixtureURL = try prepareExternalOpenPanelFlacFixture(
            fileName: Self.fixtureFileName,
            destinationFileName: "01-swifttag-applescript-\(UUID().uuidString).flac"
        )
        let secondFixtureURL = try prepareExternalOpenPanelFlacFixture(
            fileName: Self.fixtureFileName,
            destinationFileName: "02-swifttag-applescript-\(UUID().uuidString).flac"
        )
        let app = try launchApp()

        let output = try runAppleScript(
            """
            tell application id "\(Self.appBundleIdentifier)"
                activate
                tell front editor window
                    add {POSIX file "\(secondFixtureURL.path)", POSIX file "\(firstFixtureURL.path)"}
                    delay 1
                    set selected tracks to first track
                    set firstSelectedFile to get file of item 1 of (get selected tracks)
                    set firstSelectedPath to POSIX path of firstSelectedFile
                    set selected tracks to (every track whose title is "Test Title")
                    set trackCount to count of selected tracks
                    return firstSelectedPath & linefeed & (trackCount as text)
                end tell
            end tell
            """,
            terminologyBundleIdentifier: Self.appBundleIdentifier,
            timeout: 20.0
        )

        let outputLines = normalizedAppleScriptTextOutput(output)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        XCTAssertEqual(outputLines, [firstFixtureURL.path, "2"])
        app.terminate()
    }

    @MainActor
    func testAppleScriptHarnessSetsTitleOfFirstTrack() throws {
        try requireAppleScriptHarnessEnabled()

        let app = try launchApp(importFixture: true)
        defer {
            app.terminate()
        }
        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)

        let output = try runAppleScript(
            """
            tell application id "\(Self.appBundleIdentifier)"
                activate
                tell front editor window
                    set title of first track to "New Title"
                    return title of first track
                end tell
            end tell
            """,
            terminologyBundleIdentifier: Self.appBundleIdentifier,
            timeout: 20.0
        )

        XCTAssertEqual(normalizedAppleScriptTextOutput(output), "New Title")
        XCTAssertTrue(waitForTextFieldValueAnywhere(in: app, expectedValue: "New Title", timeout: 5.0))
    }

    @MainActor
    func testAppleScriptHarnessReadsFirstTagWhoseKey() throws {
        try requireAppleScriptHarnessEnabled()

        let app = try launchApp(importFixture: true)
        defer {
            app.terminate()
        }
        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)

        let output = try runAppleScript(
            """
            tell application id "\(Self.appBundleIdentifier)"
                activate
                tell front editor window
                    repeat 50 times
                        if (count of tracks) > 0 then exit repeat
                        delay 0.1
                    end repeat
                    tell first track
                        repeat 50 times
                            if (count of tags) > 0 then exit repeat
                            delay 0.1
                        end repeat
                        set tagArtist to (first tag whose key is "ARTIST")
                        return "Track tag ARTIST: " & (key of tagArtist) & ", " & (value of tagArtist)
                    end tell
                end tell
            end tell
            """,
            terminologyBundleIdentifier: Self.appBundleIdentifier,
            timeout: 20.0
        )

        XCTAssertEqual(normalizedAppleScriptTextOutput(output), "Track tag ARTIST: ARTIST, Test Artist")
    }

    @MainActor
    func testAppleScriptHarnessDeletesTagAndAlbumProperty() throws {
        try requireAppleScriptHarnessEnabled()

        let app = try launchApp(importFixture: true)
        defer {
            app.terminate()
        }
        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)

        let output = try runAppleScript(
            """
            tell application id "\(Self.appBundleIdentifier)"
                activate
                tell front editor window
                    repeat 50 times
                        if (count of tracks) > 0 then exit repeat
                        delay 0.1
                    end repeat
                    tell first track
                        set albumBefore to album
                        set tagAlbum to (first tag whose key is "ALBUM")
                        delete tagAlbum
                        set albumMissingAfterTagDelete to (album is missing value)
                        set albumTagCountAfterTagDelete to count of (every tag whose key is "ALBUM")
                        set album to "AppleScript Property Delete Album"
                        set albumTagCountBeforePropertyDelete to count of (every tag whose key is "ALBUM")
                        delete album
                        set albumMissingAfterPropertyDelete to (album is missing value)
                        set albumTagCountAfterPropertyDelete to count of (every tag whose key is "ALBUM")
                        return albumBefore & linefeed & (albumTagCountAfterTagDelete as text) & linefeed & (albumMissingAfterTagDelete as text) & linefeed & (albumTagCountBeforePropertyDelete as text) & linefeed & (albumTagCountAfterPropertyDelete as text) & linefeed & (albumMissingAfterPropertyDelete as text)
                    end tell
                end tell
            end tell
            """,
            terminologyBundleIdentifier: Self.appBundleIdentifier,
            timeout: 20.0
        )

        XCTAssertNil(dismissImportErrorAlertIfPresent(in: app, timeout: 1.0))
        let outputLines = normalizedAppleScriptTextOutput(output)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        XCTAssertEqual(outputLines, [
            "Test Album",
            "0",
            "true",
            "1",
            "0",
            "true"
        ])
    }

    @MainActor
    func testAppleScriptHarnessSavesWithScopeAndPayloadEnumerations() throws {
        try requireAppleScriptHarnessEnabled()

        let fixtureURL = try prepareExternalOpenPanelFlacFixture(
            fileName: Self.fixtureFileName,
            destinationFileName: "swifttag-applescript-save-\(UUID().uuidString).flac"
        )
        let app = try launchApp()
        defer {
            app.terminate()
        }
        XCTAssertNil(dismissImportErrorAlertIfPresent(in: app, timeout: 1.0))

        let title = "Saved Enumeration Title \(UUID().uuidString)"
        let output = try runAppleScript(
            """
            tell application id "\(Self.appBundleIdentifier)"
                activate
                tell front editor window
                    add POSIX file "\(fixtureURL.path)"
                    repeat 50 times
                        if (count of tracks) > 0 then exit repeat
                        delay 0.1
                    end repeat
                    if (count of tracks) is 0 then error "SwiftTag add did not load track."
                    set title of first track to "\(title)"
                    set selected tracks to first track
                    save with scope selected with payload tags only
                    return title of first track
                end tell
            end tell
            """,
            terminologyBundleIdentifier: Self.appBundleIdentifier,
            timeout: 20.0
        )

        XCTAssertNil(dismissImportErrorAlertIfPresent(in: app, timeout: 1.0))
        XCTAssertEqual(normalizedAppleScriptTextOutput(output), title)
    }

    @MainActor
    func testAppleScriptHarnessReadsTrackPicturesByType() throws {
        try requireAppleScriptHarnessEnabled()

        let app = try launchApp(
            importFixture: true,
            importedPictureProfile: "single-front-cover"
        )
        defer {
            app.terminate()
        }

        let output = try runAppleScript(
            """
            tell application id "\(Self.appBundleIdentifier)"
                activate
                tell front editor window
                    repeat 50 times
                        if (count of tracks) > 0 then exit repeat
                        delay 0.1
                    end repeat
                    tell first track
                        repeat 50 times
                            if (count of pictures) > 0 then exit repeat
                            delay 0.1
                        end repeat
                        set trackFrontCovers to every picture whose picture type is front cover
                        set firstCover to item 1 of trackFrontCovers
                        set frontCoverPictureData to data of firstCover
                        return ((count of pictures) as text) & linefeed & ((count of trackFrontCovers) as text) & linefeed & (description of firstCover) & linefeed & (MIME type of firstCover) & linefeed & ((class of frontCoverPictureData) as text) & linefeed & ((frontCoverPictureData is missing value) as text)
                    end tell
                end tell
            end tell
            """,
            terminologyBundleIdentifier: Self.appBundleIdentifier,
            timeout: 20.0
        )

        XCTAssertNil(dismissImportErrorAlertIfPresent(in: app, timeout: 1.0))
        let outputLines = normalizedAppleScriptTextOutput(output)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        XCTAssertEqual(outputLines.count, 6)
        XCTAssertEqual(Array(outputLines.prefix(4)), ["1", "1", "UI Test Single Front Cover", "image/png"])
        XCTAssertTrue(outputLines[4] == "data" || outputLines[4].contains("tdta"))
        XCTAssertEqual(outputLines[5], "false")
    }

    @MainActor
    func testAppleScriptHarnessImportsTrackPictureFromExistingData() throws {
        try requireAppleScriptHarnessEnabled()

        let app = try launchApp(
            importFixture: true,
            importedPictureProfile: "single-front-cover"
        )
        defer {
            app.terminate()
        }

        let output = try runAppleScript(
            """
            tell application id "\(Self.appBundleIdentifier)"
                activate
                tell front editor window
                    repeat 50 times
                        if (count of tracks) > 0 then exit repeat
                        delay 0.1
                    end repeat
                    tell first track
                        repeat 50 times
                            if (count of pictures) > 0 then exit repeat
                            delay 0.1
                        end repeat
                        set firstCover to item 1 of (every picture whose picture type is front cover)
                        set frontCoverPictureData to data of firstCover
                        set testPicture to import picture frontCoverPictureData with picture type front cover
                        set countAfterDuplicateImport to count of pictures
                        set testPictureDescriptionBeforeEdit to description of testPicture
                        set editedPicture to import picture with data frontCoverPictureData with picture type front cover with description "AppleScript Edited Front"
                        return (countAfterDuplicateImport as text) & linefeed & ((count of pictures) as text) & linefeed & testPictureDescriptionBeforeEdit & linefeed & (description of editedPicture) & linefeed & (MIME type of editedPicture)
                    end tell
                end tell
            end tell
            """,
            terminologyBundleIdentifier: Self.appBundleIdentifier,
            timeout: 20.0
        )

        XCTAssertNil(dismissImportErrorAlertIfPresent(in: app, timeout: 1.0))
        let outputLines = normalizedAppleScriptTextOutput(output)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        XCTAssertEqual(outputLines, [
            "1",
            "1",
            "UI Test Single Front Cover",
            "AppleScript Edited Front",
            "image/png"
        ])
    }

    func testAppleScriptHarnessImportsTrackPictureFromFoundationBase64Data() throws {
        try requireAppleScriptHarnessEnabled()

        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTagUITests-AppleScript-import-picture.png")
        let imageData = try XCTUnwrap(
            Data(
                base64Encoded:
                    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO3ZbZ0AAAAASUVORK5CYII="
            )
        )
        try imageData.write(to: imageURL, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: imageURL)
        }

        let app = try launchApp(
            importFixture: true,
            importedPictureProfile: "single-front-cover"
        )
        defer {
            app.terminate()
        }

        let output = try runAppleScript(
            """
            use framework "Foundation"
            use scripting additions

            using terms from application id "\(Self.appBundleIdentifier)"
                tell application id "\(Self.appBundleIdentifier)"
                    activate
                    tell front editor window
                        repeat 50 times
                            if (count of tracks) > 0 then exit repeat
                            delay 0.1
                        end repeat
                        tell first track
                            set imagePath to "\(imageURL.path)"
                            set newPictureData to my getByteDataFrom(imagePath)
                            set newPicture to import picture newPictureData with picture type front cover with description "New Picture"
                            return ((count of pictures) as text) & linefeed & (picture type of newPicture as text) & linefeed & (description of newPicture) & linefeed & (MIME type of newPicture)
                        end tell
                    end tell
                end tell
            end using terms from

            on getByteDataFrom(thePath)
                set theURL to current application's |NSURL|'s fileURLWithPath:thePath
                set theData to current application's NSData's dataWithContentsOfURL:theURL
                if theData is missing value then
                    error "Could not read data from file. Check the path."
                end if
                return (theData's base64EncodedStringWithOptions:0) as text
            end getByteDataFrom
            """,
            timeout: 20.0
        )

        XCTAssertNil(dismissImportErrorAlertIfPresent(in: app, timeout: 1.0))
        let outputLines = normalizedAppleScriptTextOutput(output)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        XCTAssertEqual(outputLines, [
            "2",
            "front cover",
            "New Picture",
            "image/png"
        ])
    }

    @MainActor
    func testAppleScriptHarnessClosesEditorWindowSavingNo() throws {
        try requireAppleScriptHarnessEnabled()

        let app = try launchApp()
        defer {
            app.terminate()
        }
        XCTAssertNil(dismissImportErrorAlertIfPresent(in: app, timeout: 1.0))

        let output = try runAppleScript(
            """
            tell application id "\(Self.appBundleIdentifier)"
                activate
                set originalCount to count of editor windows
                make new editor window
                delay 1
                set openedCount to count of editor windows
                close front editor window saving no
                repeat 50 times
                    if (count of editor windows) is originalCount then exit repeat
                    delay 0.1
                end repeat
                set closedCount to count of editor windows
                return (originalCount as text) & linefeed & (openedCount as text) & linefeed & (closedCount as text)
            end tell
            """,
            terminologyBundleIdentifier: Self.appBundleIdentifier,
            timeout: 20.0
        )

        XCTAssertNil(dismissImportErrorAlertIfPresent(in: app, timeout: 1.0))
        let outputLines = normalizedAppleScriptTextOutput(output)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        XCTAssertEqual(outputLines, ["1", "2", "1"])
    }

    @MainActor
    func testFinderLaunchOpenShowsVisibleImportedFlacWindow() throws {
        let flacURL = try prepareReadableFlacFixture(fileName: Self.fixtureFileName)
        let app = try launchAppByOpeningFileWithSwiftTag(url: flacURL)
        let window = app.windows.firstMatch

        XCTAssertTrue(window.waitForExistence(timeout: 10.0))
        XCTAssertTrue(waitForHittableState(of: window, expectedValue: true, timeout: 10.0))

        selectImportedTrackForEditing(in: window, app: app, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForTextFieldValue(
                in: window,
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
    func testOpeningSwiftTagDocumentShowsDocumentTitleAndDocumentURL() throws {
        let savedAlbum = "Opened UI Album \(UUID().uuidString)"
        let savedTitle = "Opened Document Title \(UUID().uuidString)"
        let flacURL = try prepareReadableFlacFixture(fileName: Self.fixtureFileName)
        let swiftTagDocumentURL = try prepareSwiftTagDocumentFixture(
            sourceFlacURL: flacURL,
            savedAlbum: savedAlbum,
            savedTitle: savedTitle
        )
        let app = try launchApp(exposeNavigationMetadata: true)
        let window = app.windows.firstMatch

        app.activate()
        XCTAssertTrue(openFileWithSwiftTag(url: swiftTagDocumentURL))

        XCTAssertTrue(waitForTextFieldValueAnywhere(in: app, expectedValue: savedTitle, timeout: 10.0))
        XCTAssertTrue(waitForNavigationTitle(in: window, expectedValue: swiftTagDocumentURL.lastPathComponent, timeout: 10.0))
        XCTAssertTrue(
            waitForNavigationDocumentURL(
                in: window,
                expectedValue: swiftTagDocumentURL.standardizedFileURL.path,
                timeout: 10.0
            )
        )
    }

    func testReopeningSavedSwiftTagDocumentShowsZeroDifferenceSubtitleWhenLiveFileMatches() throws {
        let persistentFixtureName = "saved-document-match-\(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Saved Match \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        try? FileManager.default.removeItem(at: swiftTagDocumentURL)

        let app = try launchApp(
            importFixture: true,
            persistentFixtureName: persistentFixtureName,
            exposeNavigationMetadata: true
        )
        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save SwiftTag Document...")
        saveFileInSavePanel(in: app, destinationURL: swiftTagDocumentURL)
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))
        XCTAssertTrue(waitForFileExistence(at: swiftTagDocumentURL, timeout: 10.0))

        app.terminate()

        let reopenedApp = try launchApp(exposeNavigationMetadata: true, exposeDiffMetadata: true)
        reopenedApp.activate()
        let reopenedWindow = try openSavedSwiftTagDocumentWindow(
            in: reopenedApp,
            documentURL: swiftTagDocumentURL
        )

        XCTAssertTrue(waitForTextFieldValueAnywhere(in: reopenedApp, expectedValue: "Test Title", timeout: 10.0))
        XCTAssertTrue(
            waitForNavigationSubtitle(
                in: reopenedWindow,
                expectedValue: "Tracks: 1 (0) • Tag Δ: 0 (0) • Picture Δ: 0 (0)",
                timeout: 10.0
            )
        )
        XCTAssertTrue(waitForLabeledElement(in: reopenedApp, identifier: UIID.trackStatusIcon, expectedLabel: "fish.fill", timeout: 10.0))
    }

    @MainActor
    func testSavingSwiftTagDocumentUpdatesTrackFilenameAfterReferencedFlacRename() throws {
        let persistentFixtureName = "saved-document-rename-open-\(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Saved Rename Open \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        let renamedBasename = "renamed-\(UUID().uuidString).flac"
        let saveContext = try saveSwiftTagDocumentFromImportedFixture(
            persistentFixtureName: persistentFixtureName,
            swiftTagDocumentURL: swiftTagDocumentURL,
            postSaveRenameBasename: renamedBasename
        )

        let renamedURL = saveContext.flacURL.deletingLastPathComponent()
            .appendingPathComponent(renamedBasename)

        XCTAssertTrue(
            waitForStaticTextLabel(
                in: saveContext.window,
                identifier: UIID.trackFilenameText,
                expectedValue: renamedURL.lastPathComponent,
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextLabel(
                in: saveContext.window,
                identifier: UIID.trackFilenameText,
                expectedValue: "available",
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testAddingExternalFlacFileUpdatesTrackFilenameAfterRename() throws {
        let flacURL = try prepareExternalOpenPanelFlacFixture(fileName: Self.fixtureFileName)
        let renamedURL = flacURL.deletingLastPathComponent()
            .appendingPathComponent("renamed-\(UUID().uuidString).flac")
        let app = try launchApp()
        let window = app.windows.firstMatch

        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Add FLAC files...")
        chooseFileInOpenPanel(in: app, path: flacURL.path)
        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)

        XCTAssertTrue(
            waitForStaticTextLabel(
                in: window,
                identifier: UIID.trackFilenameText,
                expectedValue: flacURL.lastPathComponent,
                timeout: 10.0
            )
        )

        try? FileManager.default.removeItem(at: renamedURL)
        try FileManager.default.moveItem(at: flacURL, to: renamedURL)

        XCTAssertTrue(
            waitForStaticTextLabel(
                in: window,
                identifier: UIID.trackFilenameText,
                expectedValue: renamedURL.lastPathComponent,
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextLabel(
                in: window,
                identifier: UIID.trackFilenameText,
                expectedValue: "available",
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testAddingExternalFlacFileKeepsRenamedFilenameWhenDeleted() throws {
        let flacURL = try prepareExternalOpenPanelFlacFixture(fileName: Self.fixtureFileName)
        let renamedURL = flacURL.deletingLastPathComponent()
            .appendingPathComponent("deleted-after-rename-\(UUID().uuidString).flac")
        let app = try launchApp()
        let window = app.windows.firstMatch

        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Add FLAC files...")
        chooseFileInOpenPanel(in: app, path: flacURL.path)
        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)

        try? FileManager.default.removeItem(at: renamedURL)
        try FileManager.default.moveItem(at: flacURL, to: renamedURL)

        XCTAssertTrue(
            waitForStaticTextLabel(
                in: window,
                identifier: UIID.trackFilenameText,
                expectedValue: renamedURL.lastPathComponent,
                timeout: 10.0
            )
        )

        try FileManager.default.removeItem(at: renamedURL)

        XCTAssertTrue(
            waitForStaticTextLabel(
                in: window,
                identifier: UIID.trackFilenameText,
                expectedValue: renamedURL.lastPathComponent,
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextLabel(
                in: window,
                identifier: UIID.trackFilenameText,
                expectedValue: "deleted",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForLabeledElement(
                in: app,
                identifier: UIID.trackStatusIcon,
                expectedLabel: "exclamationmark.triangle",
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testSavingSwiftTagDocumentKeepsRenamedFilenameWhenReferencedFlacIsDeleted() throws {
        let persistentFixtureName = "saved-document-delete-open-\(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Saved Delete Open \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        let renamedBasename = "renamed-before-delete-\(UUID().uuidString).flac"
        let saveContext = try saveSwiftTagDocumentFromImportedFixture(
            persistentFixtureName: persistentFixtureName,
            swiftTagDocumentURL: swiftTagDocumentURL,
            postSaveRenameBasename: renamedBasename,
            postSaveDeleteAfterRename: true
        )

        let renamedURL = saveContext.flacURL.deletingLastPathComponent()
            .appendingPathComponent(renamedBasename)
        XCTAssertTrue(
            waitForStaticTextLabel(
                in: saveContext.window,
                identifier: UIID.trackFilenameText,
                expectedValue: renamedURL.lastPathComponent,
                timeout: 10.0
            )
        )

        XCTAssertTrue(
            waitForStaticTextLabel(
                in: saveContext.window,
                identifier: UIID.trackFilenameText,
                expectedValue: renamedURL.lastPathComponent,
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextLabel(
                in: saveContext.window,
                identifier: UIID.trackFilenameText,
                expectedValue: "deleted",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForLabeledElement(
                in: saveContext.app,
                identifier: UIID.trackStatusIcon,
                expectedLabel: "exclamationmark.triangle",
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testReopeningSavedSwiftTagDocumentShowsRenamedReferencedFilenameAndZeroDifferenceSubtitle() throws {
        let persistentFixtureName = "saved-document-rename-reopen-\(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Saved Rename Reopen \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        let renamedBasename = "renamed-before-reopen-\(UUID().uuidString).flac"
        let saveContext = try saveSwiftTagDocumentFromImportedFixture(
            persistentFixtureName: persistentFixtureName,
            swiftTagDocumentURL: swiftTagDocumentURL,
            postSaveRenameBasename: renamedBasename
        )

        let renamedURL = saveContext.flacURL.deletingLastPathComponent()
            .appendingPathComponent(renamedBasename)
        XCTAssertTrue(
            waitForStaticTextLabel(
                in: saveContext.window,
                identifier: UIID.trackFilenameText,
                expectedValue: renamedURL.lastPathComponent,
                timeout: 10.0
            )
        )
        saveContext.app.terminate()

        let reopenedApp = try launchApp(exposeNavigationMetadata: true)
        reopenedApp.activate()
        let reopenedWindow = try openSavedSwiftTagDocumentWindow(
            in: reopenedApp,
            documentURL: swiftTagDocumentURL
        )

        XCTAssertTrue(waitForTextFieldValueAnywhere(in: reopenedApp, expectedValue: "Test Title", timeout: 10.0))
        XCTAssertTrue(
            waitForStaticTextLabel(
                in: reopenedWindow,
                identifier: UIID.trackFilenameText,
                expectedValue: renamedURL.lastPathComponent,
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForNavigationSubtitle(
                in: reopenedWindow,
                expectedValue: "Tracks: 1 (0) • Tag Δ: 0 (0) • Picture Δ: 0 (0)",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForLabeledElement(
                in: reopenedApp,
                identifier: UIID.trackStatusIcon,
                expectedLabel: "fish.fill",
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testReopeningSavedSwiftTagDocumentShowsExternalTagDifferenceCounts() throws {
        let persistentFixtureName = "saved-document-tag-diff-\(UUID().uuidString)"
        let liveChangedTitle = "Live Changed Title \(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Saved Tag Diff \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        try? FileManager.default.removeItem(at: swiftTagDocumentURL)

        let app = try launchApp(
            importFixture: true,
            persistentFixtureName: persistentFixtureName,
            exposeNavigationMetadata: true
        )
        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save SwiftTag Document...")
        saveFileInSavePanel(in: app, destinationURL: swiftTagDocumentURL)
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))
        XCTAssertTrue(waitForFileExistence(at: swiftTagDocumentURL, timeout: 10.0))

        let liveTitleField = app.textFields.matching(NSPredicate(format: "value == %@", "Test Title")).firstMatch
        XCTAssertTrue(liveTitleField.waitForExistence(timeout: 10.0))
        clearAndType(in: app, element: liveTitleField, text: liveChangedTitle)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))

        app.terminate()

        let reopenedApp = try launchApp(exposeNavigationMetadata: true)
        reopenedApp.activate()
        let reopenedWindow = try openSavedSwiftTagDocumentWindow(
            in: reopenedApp,
            documentURL: swiftTagDocumentURL
        )

        XCTAssertTrue(waitForTextFieldValueAnywhere(in: reopenedApp, expectedValue: "Test Title", timeout: 10.0))
        XCTAssertTrue(
            waitForNavigationSubtitle(
                in: reopenedWindow,
                expectedValue: "Tracks: 1 (0) • Tag Δ: 1 (0) • Picture Δ: 0 (0)",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForLabeledElement(
                in: reopenedApp,
                identifier: UIID.trackStatusIcon,
                expectedLabel: "exclamationmark.triangle",
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testReopeningSavedSwiftTagDocumentIgnoresEquivalentMultiPictureOrderingAfterExternalTagSave() throws {
        let singlePictureTitle = "Single Picture Track \(UUID().uuidString)"
        let multiPictureTitle = "Multi Picture Track \(UUID().uuidString)"
        let changedAlbum = "Changed Album \(UUID().uuidString)"
        let singlePictureFixtureName = "single-picture-\(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Picture Order Regression \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        try? FileManager.default.removeItem(at: swiftTagDocumentURL)

        let saveApp = try launchApp(
            importFixture: true,
            importedTitleOverride: singlePictureTitle,
            importedPictureProfile: "single-front-cover",
            menuImportFixturePath: fixtureFlacPath(fileName: Self.fixtureFileName),
            menuImportTitleOverride: multiPictureTitle,
            menuImportPictureProfile: "double-front-cover-reversed",
            persistentFixtureName: singlePictureFixtureName,
            exposeNavigationMetadata: true
        )
        saveApp.activate()
        selectImportedTrackForEditing(in: saveApp, expectedTitle: singlePictureTitle, timeout: 20.0)
        clickMenuItem(in: saveApp, menuBarItem: "File", menuItem: "Add FLAC files...")
        selectImportedTrackForEditing(in: saveApp, expectedTitle: multiPictureTitle, timeout: 20.0)
        clickMenuItem(in: saveApp, menuBarItem: "File", menuItem: "Save SwiftTag Document...")
        saveFileInSavePanel(in: saveApp, destinationURL: swiftTagDocumentURL)
        XCTAssertNil(waitForSaveErrorPresentation(in: saveApp, timeout: 1.0))
        XCTAssertTrue(waitForFileExistence(at: swiftTagDocumentURL, timeout: 10.0))
        saveApp.terminate()

        let modifierApp = try launchApp(
            importFixture: true,
            importedTitleOverride: singlePictureTitle,
            importedPictureProfile: "single-front-cover",
            persistentFixtureName: singlePictureFixtureName,
            reuseImportedFixture: true
        )
        modifierApp.activate()
        selectImportedTrackForEditing(in: modifierApp, expectedTitle: singlePictureTitle, timeout: 20.0)

        let liveAlbumField = editableAlbumField(in: modifierApp)
        XCTAssertTrue(liveAlbumField.waitForExistence(timeout: 10.0))
        clearAndType(in: modifierApp, element: liveAlbumField, text: changedAlbum)
        clickMenuItem(in: modifierApp, menuBarItem: "File", menuItem: "Save")
        XCTAssertNil(waitForSaveErrorPresentation(in: modifierApp, timeout: 1.0))
        modifierApp.terminate()

        let reopenedApp = try launchApp(exposeNavigationMetadata: true)
        reopenedApp.activate()
        let reopenedWindow = try openSavedSwiftTagDocumentWindow(
            in: reopenedApp,
            documentURL: swiftTagDocumentURL
        )

        selectImportedTrackForEditing(in: reopenedApp, expectedTitle: singlePictureTitle, timeout: 20.0)
        let singleSelectionExpectedSubtitle = "Tracks: 2 (1) • Tag Δ: 1 (1) • Picture Δ: 0 (0)"
        XCTAssertTrue(
            waitForNavigationSubtitle(
                in: reopenedWindow,
                expectedValue: singleSelectionExpectedSubtitle,
                timeout: 10.0
            ),
            "Observed subtitles after selecting single-picture track: \(navigationSubtitleProbeValues(in: reopenedWindow))"
        )

        selectImportedTrackForEditing(in: reopenedApp, expectedTitle: multiPictureTitle, timeout: 20.0)
        let multiSelectionExpectedSubtitle = "Tracks: 2 (1) • Tag Δ: 1 (0) • Picture Δ: 0 (0)"
        XCTAssertTrue(
            waitForNavigationSubtitle(
                in: reopenedWindow,
                expectedValue: multiSelectionExpectedSubtitle,
                timeout: 10.0
            ),
            "Observed subtitles after selecting multi-picture track: \(navigationSubtitleProbeValues(in: reopenedWindow))"
        )
        XCTAssertTrue(
            waitForLabeledElement(
                in: reopenedApp,
                identifier: UIID.trackStatusIcon,
                expectedLabel: "exclamationmark.triangle",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForLabeledElement(
                in: reopenedApp,
                identifier: UIID.trackStatusIcon,
                expectedLabel: "fish.fill",
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testSavingSwiftTagDocumentKeepsTracksLoadedAndShowsDocumentTitleAndURL() throws {
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Test Album")
            .appendingPathExtension("swifttag")
        try? FileManager.default.removeItem(at: swiftTagDocumentURL)

        let app = try launchApp(
            importFixture: true,
            exposeNavigationMetadata: true,
            waitForEditorUI: false
        )
        let window = app.windows.firstMatch

        app.activate()
        XCTAssertTrue(waitForWindowCount(in: app, minimumCount: 1, timeout: 10.0))
        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save SwiftTag Document...")
        saveFileInSavePanel(in: app, destinationURL: swiftTagDocumentURL)

        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))
        XCTAssertTrue(waitForFileExistence(at: swiftTagDocumentURL, timeout: 10.0))
        XCTAssertTrue(waitForNavigationTitle(in: window, expectedValue: swiftTagDocumentURL.lastPathComponent, timeout: 10.0))
        XCTAssertTrue(
            waitForNavigationDocumentURL(
                in: window,
                expectedValue: swiftTagDocumentURL.standardizedFileURL.path,
                timeout: 10.0
            )
        )
        XCTAssertTrue(waitForTextFieldValueAnywhere(in: app, expectedValue: "Test Title", timeout: 10.0))
    }

    @MainActor
    func testFileMenuSaveAutoSavesReferencedSwiftTagDocumentWhenSettingEnabled() throws {
        let persistentFixtureName = "auto-save-referenced-\(UUID().uuidString)"
        let updatedAlbum = "Updated Album \(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Auto Saved Referenced \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        try? FileManager.default.removeItem(at: swiftTagDocumentURL)

        let app = try launchApp(
            importFixture: true,
            persistentFixtureName: persistentFixtureName,
            resetSaveSettings: true,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: false,
            exposeNavigationMetadata: true
        )
        let window = app.windows.firstMatch

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save SwiftTag Document...")
        saveFileInSavePanel(in: app, destinationURL: swiftTagDocumentURL)
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))
        XCTAssertTrue(waitForFileExistence(at: swiftTagDocumentURL, timeout: 10.0))

    clearAndType(in: app, element: editableAlbumField(in: app), text: updatedAlbum)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))
        XCTAssertTrue(waitForNavigationTitle(in: window, expectedValue: swiftTagDocumentURL.lastPathComponent, timeout: 10.0))
        XCTAssertTrue(
            waitForSwiftTagDocumentTagValue(
                in: swiftTagDocumentURL,
                key: "ALBUM",
                expectedValue: updatedAlbum,
                timeout: 10.0
            )
        )

        app.terminate()

        let reopenedApp = try launchApp(resetSaveSettings: false, exposeNavigationMetadata: true)
        reopenedApp.activate()
        let reopenedWindow = try openSavedSwiftTagDocumentWindow(
            in: reopenedApp,
            documentURL: swiftTagDocumentURL
        )

        XCTAssertEqual(swiftTagDocumentTagValue(in: swiftTagDocumentURL, key: "ALBUM"), updatedAlbum)
        XCTAssertTrue(
            waitForNavigationSubtitle(
                in: reopenedWindow,
                expectedValue: "Tracks: 1 (0) • Tag Δ: 0 (0) • Picture Δ: 0 (0)",
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testControlSSavesReferencedSwiftTagDocumentWithoutSavingFlacFiles() throws {
        let persistentFixtureName = "control-s-document-only-\(UUID().uuidString)"
        let updatedAlbum = "Control Save Album \(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Control Save Document \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        try? FileManager.default.removeItem(at: swiftTagDocumentURL)

        let saveApp = try launchApp(
            importFixture: true,
            persistentFixtureName: persistentFixtureName,
            resetSaveSettings: true,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: false,
            exposeNavigationMetadata: true
        )
        let saveWindow = saveApp.windows.firstMatch

        selectImportedTrackForEditing(in: saveApp, expectedTitle: "Test Title", timeout: 20.0)
        clickMenuItem(in: saveApp, menuBarItem: "File", menuItem: "Save SwiftTag Document...")
        saveFileInSavePanel(in: saveApp, destinationURL: swiftTagDocumentURL)
        XCTAssertNil(waitForSaveErrorPresentation(in: saveApp, timeout: 1.0))
        XCTAssertTrue(waitForFileExistence(at: swiftTagDocumentURL, timeout: 10.0))

        clearAndType(in: saveApp, element: editableAlbumField(in: saveApp), text: updatedAlbum)
        focusWindow(saveWindow)
        performSaveSwiftTagDocumentShortcut(in: saveApp)

        XCTAssertNil(waitForSaveErrorPresentation(in: saveApp, timeout: 1.0))
        XCTAssertTrue(
            waitForSwiftTagDocumentTagValue(
                in: swiftTagDocumentURL,
                key: "ALBUM",
                expectedValue: updatedAlbum,
                timeout: 10.0
            )
        )
        saveApp.terminate()

        let liveFlacApp = try launchApp(
            importFixture: true,
            persistentFixtureName: persistentFixtureName,
            reuseImportedFixture: true,
            resetSaveSettings: false
        )
        selectImportedTrackForEditing(in: liveFlacApp, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForTextFieldValue(
                in: liveFlacApp,
                identifier: UIID.albumTextField,
                expectedValue: "Test Album",
                timeout: 10.0
            )
        )
        liveFlacApp.terminate()

        let reopenedDocumentApp = try launchApp(exposeNavigationMetadata: true)
        reopenedDocumentApp.activate()
        let reopenedWindow = try openSavedSwiftTagDocumentWindow(
            in: reopenedDocumentApp,
            documentURL: swiftTagDocumentURL
        )

        selectImportedTrackForEditing(in: reopenedDocumentApp, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForNavigationSubtitle(
                in: reopenedWindow,
                expectedValue: "Tracks: 1 (1) • Tag Δ: 1 (1) • Picture Δ: 0 (0)",
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testControlSSavesMovedReferencedSwiftTagDocumentAfterExternalMove() throws {
        let persistentFixtureName = "control-s-moved-document-\(UUID().uuidString)"
        let updatedAlbum = "Moved Document Album \(UUID().uuidString)"
        let originalDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Moved Document Original \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        let movedDirectoryURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Moved SwiftTag Documents \(UUID().uuidString)", isDirectory: true)
        let movedDocumentURL = movedDirectoryURL
            .appendingPathComponent("Moved Referenced Document \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        try? FileManager.default.removeItem(at: originalDocumentURL)
        try? FileManager.default.removeItem(at: movedDocumentURL)
        try FileManager.default.createDirectory(at: movedDirectoryURL, withIntermediateDirectories: true)

        let app = try launchApp(
            importFixture: true,
            persistentFixtureName: persistentFixtureName,
            resetSaveSettings: true,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: false,
            exposeNavigationMetadata: true
        )
        let window = app.windows.firstMatch

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save SwiftTag Document...")
        saveFileInSavePanel(in: app, destinationURL: originalDocumentURL)
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))
        XCTAssertTrue(waitForFileExistence(at: originalDocumentURL, timeout: 10.0))

        try FileManager.default.moveItem(at: originalDocumentURL, to: movedDocumentURL)

        XCTAssertTrue(waitForFileExistence(at: movedDocumentURL, timeout: 10.0))
        XCTAssertTrue(waitForNavigationTitle(in: window, expectedValue: movedDocumentURL.lastPathComponent, timeout: 10.0))
        XCTAssertTrue(
            waitForNavigationDocumentURL(
                in: window,
                expectedValue: movedDocumentURL.standardizedFileURL.path,
                timeout: 10.0
            )
        )

        clearAndType(in: app, element: editableAlbumField(in: app), text: updatedAlbum)
        focusWindow(window)
        performSaveSwiftTagDocumentShortcut(in: app)

        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 2.0))
        XCTAssertTrue(
            waitForSwiftTagDocumentTagValue(
                in: movedDocumentURL,
                key: "ALBUM",
                expectedValue: updatedAlbum,
                timeout: 10.0
            )
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalDocumentURL.path))
    }

    @MainActor
    func testFileMenuSavePromptsToCreateSwiftTagDocumentWhenSettingsEnabled() throws {
        let promptedAlbum = "Prompted Album \(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Prompt Created \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        try? FileManager.default.removeItem(at: swiftTagDocumentURL)

        let app = try launchApp(
            importFixture: true,
            resetSaveSettings: true,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: true,
            exposeNavigationMetadata: true
        )
        let window = app.windows.firstMatch

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        clearAndType(in: app, element: editableAlbumField(in: app), text: promptedAlbum)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")

        XCTAssertTrue(waitForSaveNewSwiftTagDocumentPromptState(in: window, expectedValue: "presented", timeout: 5.0))
        clickSaveNewSwiftTagDocumentPromptButton(in: app, title: "Save")
        saveFileInSavePanel(in: app, destinationURL: swiftTagDocumentURL)

        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))
        XCTAssertTrue(waitForFileExistence(at: swiftTagDocumentURL, timeout: 10.0))
        XCTAssertTrue(waitForNavigationTitle(in: window, expectedValue: swiftTagDocumentURL.lastPathComponent, timeout: 10.0))
        XCTAssertTrue(
            waitForNavigationDocumentURL(
                in: window,
                expectedValue: swiftTagDocumentURL.standardizedFileURL.path,
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testFileMenuSaveDoNotSaveSuppressesPromptInSameWindow() throws {
        let firstAlbum = "Do Not Save First \(UUID().uuidString)"
        let secondAlbum = "Do Not Save Second \(UUID().uuidString)"

        let app = try launchApp(
            importFixture: true,
            resetSaveSettings: true,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: true,
            exposeNavigationMetadata: true
        )
        let window = app.windows.firstMatch

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        clearAndType(in: app, element: editableAlbumField(in: app), text: firstAlbum)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")

        XCTAssertTrue(waitForSaveNewSwiftTagDocumentPromptState(in: window, expectedValue: "presented", timeout: 5.0))
        clickSaveNewSwiftTagDocumentPromptButton(in: app, title: "Do Not Save")
        XCTAssertTrue(waitForNavigationDocumentURL(in: window, expectedValue: "absent", timeout: 10.0))
        XCTAssertTrue(waitForSaveNewSwiftTagDocumentPromptState(in: window, expectedValue: "hidden", timeout: 5.0))

        clearAndType(in: app, element: editableAlbumField(in: app), text: secondAlbum)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")

        XCTAssertTrue(waitForSaveNewSwiftTagDocumentPromptState(in: window, expectedValue: "hidden", timeout: 2.0))
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))
        XCTAssertTrue(waitForNavigationDocumentURL(in: window, expectedValue: "absent", timeout: 10.0))
    }

    @MainActor
    func testFileMenuSavePromptsAgainAfterCancelingNewSwiftTagDocumentSavePanel() throws {
        let firstAlbum = "Canceled Prompt First \(UUID().uuidString)"
        let secondAlbum = "Canceled Prompt Second \(UUID().uuidString)"

        let app = try launchApp(
            importFixture: true,
            resetSaveSettings: true,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: true,
            exposeNavigationMetadata: true
        )
        let window = app.windows.firstMatch

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        clearAndType(in: app, element: editableAlbumField(in: app), text: firstAlbum)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")

        XCTAssertTrue(waitForSaveNewSwiftTagDocumentPromptState(in: window, expectedValue: "presented", timeout: 5.0))
        clickSaveNewSwiftTagDocumentPromptButton(in: app, title: "Save")
        XCTAssertTrue(waitForSavePanel(in: app, timeout: 5.0))
        cancelSavePanel(in: app)
        XCTAssertTrue(waitForNavigationDocumentURL(in: window, expectedValue: "absent", timeout: 10.0))
        XCTAssertTrue(waitForSaveNewSwiftTagDocumentPromptState(in: window, expectedValue: "hidden", timeout: 5.0))

        clearAndType(in: app, element: editableAlbumField(in: app), text: secondAlbum)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")

        XCTAssertTrue(waitForSaveNewSwiftTagDocumentPromptState(in: window, expectedValue: "presented", timeout: 5.0))
    }

    @MainActor
    func testCloseWindowWithUnsavedChangesShowsExpandedNewDocumentChoices() throws {
        let app = try launchApp(importFixture: true)
        let window = app.windows.firstMatch

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        clearAndType(in: app, element: editableAlbumField(in: app), text: "Close Prompt Album \(UUID().uuidString)")

        app.typeKey("w", modifierFlags: .command)

        let sheet = window.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5.0))
        XCTAssertTrue(sheet.buttons["Save FLAC files"].firstMatch.waitForExistence(timeout: 5.0))
        XCTAssertTrue(sheet.buttons["Save New SwiftTag Document..."].firstMatch.waitForExistence(timeout: 5.0))
        XCTAssertTrue(sheet.buttons["Save FLAC files & New SwiftTag Document..."].firstMatch.waitForExistence(timeout: 5.0))
        XCTAssertTrue(sheet.buttons["Close Window"].firstMatch.waitForExistence(timeout: 5.0))
        XCTAssertTrue(sheet.buttons["Cancel"].firstMatch.waitForExistence(timeout: 5.0))

        typeEscape(in: app)
        XCTAssertTrue(window.waitForExistence(timeout: 5.0))
    }

    @MainActor
    func testCloseWindowSaveNewSwiftTagDocumentCancelKeepsWindowOpen() throws {
        let app = try launchApp(importFixture: true)
        let window = app.windows.firstMatch

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        clearAndType(in: app, element: editableAlbumField(in: app), text: "Close Save Panel Cancel \(UUID().uuidString)")

        app.typeKey("w", modifierFlags: .command)

    let sheet = window.sheets.firstMatch
    XCTAssertTrue(sheet.waitForExistence(timeout: 5.0))
    let saveNewButton = sheet.buttons["Save New SwiftTag Document..."].firstMatch
        XCTAssertTrue(saveNewButton.waitForExistence(timeout: 5.0))
        saveNewButton.click()
        XCTAssertTrue(waitForSavePanel(in: app, timeout: 5.0))
        cancelSavePanel(in: app)

        XCTAssertTrue(window.waitForExistence(timeout: 5.0))
        XCTAssertTrue(editableAlbumField(in: app).waitForExistence(timeout: 5.0))
    }

    @MainActor
    func testFileMenuSaveShowsSwiftTagSaveErrorWhileKeepingFlacSaveResult() throws {
        let persistentFixtureName = "follow-on-save-error-\(UUID().uuidString)"
        let updatedAlbum = "Follow On Error Album \(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Follow On Save Error \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        try? FileManager.default.removeItem(at: swiftTagDocumentURL)

        let app = try launchApp(
            importFixture: true,
            persistentFixtureName: persistentFixtureName,
            resetSaveSettings: true,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: true,
            failSwiftTagDocumentSave: true,
            exposeNavigationMetadata: true,
        )
        let window = app.windows.firstMatch

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        clearAndType(in: app, element: editableAlbumField(in: app), text: updatedAlbum)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")

        XCTAssertTrue(waitForSaveNewSwiftTagDocumentPromptState(in: window, expectedValue: "presented", timeout: 5.0))
        clickSaveNewSwiftTagDocumentPromptButton(in: app, title: "Save")
        saveFileInSavePanel(in: app, destinationURL: swiftTagDocumentURL)

            let saveErrorDialog = try XCTUnwrap(waitForSaveErrorPresentation(in: app, timeout: 10.0))
            let okButton = saveErrorDialog.buttons["OK"].firstMatch
            XCTAssertTrue(okButton.waitForExistence(timeout: 2.0))
            okButton.click()
        app.terminate()

        let relaunchedApp = try launchApp(
            importFixture: true,
            persistentFixtureName: persistentFixtureName,
            reuseImportedFixture: true,
            resetSaveSettings: false
        )
        selectImportedTrackForEditing(in: relaunchedApp, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForTextFieldValue(
                in: relaunchedApp,
                identifier: UIID.albumTextField,
                expectedValue: updatedAlbum,
                timeout: 10.0
            )
        )
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
    func testAddFlacFilesPreservesDirtyTrackStatusIcon() throws {
        let addFixturePath = fixtureFlacPath(fileName: Self.fixtureFileName)
        let app = try launchApp(
            importFixture: true,
            menuImportFixturePath: addFixturePath
        )

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title")
        clearAndType(in: app, element: editableAlbumField(in: app), text: "Dirty UI Album \(UUID().uuidString)")

        XCTAssertTrue(waitForEnabledState(of: editableAlbumField(in: app), expectedValue: true, timeout: 10.0))
        XCTAssertTrue(waitForLabeledElement(in: app, identifier: UIID.trackStatusIcon, expectedLabel: "fish", timeout: 10.0))

        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Add FLAC files...")

        XCTAssertTrue(waitForEnabledState(of: editableAlbumField(in: app), expectedValue: true, timeout: 10.0))
        XCTAssertTrue(waitForLabeledElement(in: app, identifier: UIID.trackStatusIcon, expectedLabel: "fish", timeout: 10.0))
    }

    @MainActor
    func testCompilationCheckboxRetainsOnStateWhenSelectedTrackIsLocked() throws {
        let app = try launchApp(importFixture: true)

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(waitForEnabledState(of: compilationCheckbox(in: app), expectedValue: true, timeout: 5.0))

        setToggle(in: app, identifier: UIID.compilationCheckbox, isOn: true)
        XCTAssertTrue(isToggleOn(in: app, identifier: UIID.compilationCheckbox))

        openTrackContextMenu(in: app, expectedTitle: "Test Title")
        let lockMenuItem = app.menuItems["Lock Selected Track"].firstMatch
        XCTAssertTrue(lockMenuItem.waitForExistence(timeout: 2.0))
        lockMenuItem.click()

        XCTAssertTrue(waitForEnabledState(of: editableAlbumField(in: app), expectedValue: false, timeout: 5.0))
        XCTAssertTrue(waitForEnabledState(of: compilationCheckbox(in: app), expectedValue: false, timeout: 5.0))
        XCTAssertTrue(
            isToggleOn(in: app, identifier: UIID.compilationCheckbox),
            "Compilation checkbox lost its on-state after locking the selected track."
        )
    }

    @MainActor
    func testNewWindowsCanBeSelectedAndEditedDeterministicallyWithOpenPanel() throws {
        let firstFixtureURL = try prepareExternalOpenPanelFlacFixture(fileName: Self.fixtureFileName)
        let secondFixtureURL = try prepareExternalOpenPanelFlacFixture(fileName: Self.fixtureFileName)
        let firstAlbum = "Window A Album \(UUID().uuidString)"
        let firstAlbumArtist = "Window A Artist \(UUID().uuidString)"
        let secondAlbum = "Window B Album \(UUID().uuidString)"
        let secondAlbumArtist = "Window B Artist \(UUID().uuidString)"

        let app = try launchApp()
        XCTAssertTrue(waitForWindowCount(in: app, minimumCount: 1, timeout: 10.0))

        let existingWindowIdentifiers = Set(currentWindowIdentifiers(in: app))
        app.typeKey("n", modifierFlags: .command)
        let firstNewWindowIdentifier = waitForNewWindowIdentifier(
            in: app,
            excluding: existingWindowIdentifiers,
            timeout: 10.0
        )
        let firstNewWindow = window(in: app, identifier: firstNewWindowIdentifier)
        XCTAssertTrue(firstNewWindow.waitForExistence(timeout: 10.0))

        let firstNewWindowIdentifiers = Set(currentWindowIdentifiers(in: app))
        app.typeKey("n", modifierFlags: .command)
        let secondNewWindowIdentifier = waitForNewWindowIdentifier(
            in: app,
            excluding: firstNewWindowIdentifiers,
            timeout: 10.0
        )
        let secondNewWindow = window(in: app, identifier: secondNewWindowIdentifier)
        XCTAssertTrue(secondNewWindow.waitForExistence(timeout: 10.0))
        XCTAssertNotEqual(firstNewWindowIdentifier, secondNewWindowIdentifier)

        focusWindow(firstNewWindow)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Add FLAC files...")
        chooseFileInOpenPanel(in: app, path: firstFixtureURL.path)
        selectImportedTrackForEditing(in: firstNewWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)

        clearAndType(in: app, element: editableAlbumField(in: firstNewWindow), text: firstAlbum)
        clearAndType(in: app, element: editableAlbumArtistField(in: firstNewWindow), text: firstAlbumArtist)
        XCTAssertTrue(
            waitForTextFieldValue(
                in: firstNewWindow,
                identifier: UIID.albumTextField,
                expectedValue: firstAlbum,
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForTextFieldValue(
                in: firstNewWindow,
                identifier: UIID.albumArtistTextField,
                expectedValue: firstAlbumArtist,
                timeout: 10.0
            )
        )

        focusWindow(secondNewWindow)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Add FLAC files...")
        chooseFileInOpenPanel(in: app, path: secondFixtureURL.path)
        selectImportedTrackForEditing(in: secondNewWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)

        clearAndType(in: app, element: editableAlbumField(in: secondNewWindow), text: secondAlbum)
        clearAndType(in: app, element: editableAlbumArtistField(in: secondNewWindow), text: secondAlbumArtist)
        XCTAssertTrue(
            waitForTextFieldValue(
                in: secondNewWindow,
                identifier: UIID.albumTextField,
                expectedValue: secondAlbum,
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForTextFieldValue(
                in: secondNewWindow,
                identifier: UIID.albumArtistTextField,
                expectedValue: secondAlbumArtist,
                timeout: 10.0
            )
        )

        focusWindow(firstNewWindow)
        selectImportedTrackForEditing(in: firstNewWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForTextFieldValue(
                in: firstNewWindow,
                identifier: UIID.albumTextField,
                expectedValue: firstAlbum,
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForTextFieldValue(
                in: firstNewWindow,
                identifier: UIID.albumArtistTextField,
                expectedValue: firstAlbumArtist,
                timeout: 10.0
            )
        )

        focusWindow(secondNewWindow)
        selectImportedTrackForEditing(in: secondNewWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForTextFieldValue(
                in: secondNewWindow,
                identifier: UIID.albumTextField,
                expectedValue: secondAlbum,
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForTextFieldValue(
                in: secondNewWindow,
                identifier: UIID.albumArtistTextField,
                expectedValue: secondAlbumArtist,
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testRepeatedExternalSavesAcrossWindowsContinueUpdatingObservedAlbumDifference() throws {
        let sharedFixtureURL = try prepareExternalOpenPanelFlacFixture(fileName: Self.fixtureFileName)
        let firstSavedAlbum = "Shared Window Album A \(UUID().uuidString)"
        let secondSavedAlbum = "Shared Window Album B \(UUID().uuidString)"

        let app = try launchApp(exposeDiffMetadata: true)
        let (editingWindow, observingWindow) = try openSharedFixtureInTwoNewWindows(app: app, fixtureURL: sharedFixtureURL)

        focusWindow(editingWindow)
        selectImportedTrackForEditing(in: editingWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        clearAndType(in: app, element: editableAlbumField(in: editingWindow), text: firstSavedAlbum)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))

        focusWindow(observingWindow)
        selectImportedTrackForEditing(in: observingWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForStaticTextValue(
                in: observingWindow,
                identifier: UIID.albumExternalStateProbe,
                expectedValue: "external",
                timeout: 20.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextValue(
                in: observingWindow,
                identifier: UIID.albumExternalFileValueProbe,
                expectedValue: firstSavedAlbum,
                timeout: 20.0
            )
        )

        focusWindow(editingWindow)
        selectImportedTrackForEditing(in: editingWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        clearAndType(in: app, element: editableAlbumField(in: editingWindow), text: secondSavedAlbum)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))

        focusWindow(observingWindow)
        selectImportedTrackForEditing(in: observingWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForStaticTextValue(
                in: observingWindow,
                identifier: UIID.albumExternalFileValueProbe,
                expectedValue: secondSavedAlbum,
                timeout: 20.0
            )
        )
    }

    @MainActor
    func testConflictingSaveInSecondWindowUpdatesFirstWindowObservedAlbumDifference() throws {
        let sharedFixtureURL = try prepareExternalOpenPanelFlacFixture(fileName: Self.fixtureFileName)
        let firstSavedAlbum = "Shared First Album \(UUID().uuidString)"
        let conflictingAlbum = "Shared Conflict Album \(UUID().uuidString)"

        let app = try launchApp(exposeDiffMetadata: true)
        let (firstWindow, secondWindow) = try openSharedFixtureInTwoNewWindows(app: app, fixtureURL: sharedFixtureURL)

        focusWindow(firstWindow)
        selectImportedTrackForEditing(in: firstWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        clearAndType(in: app, element: editableAlbumField(in: firstWindow), text: firstSavedAlbum)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))

        focusWindow(secondWindow)
        selectImportedTrackForEditing(in: secondWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForStaticTextValue(
                in: secondWindow,
                identifier: UIID.albumExternalFileValueProbe,
                expectedValue: firstSavedAlbum,
                timeout: 20.0
            )
        )

        clearAndType(in: app, element: editableAlbumField(in: secondWindow), text: conflictingAlbum)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save")
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))

        focusWindow(firstWindow)
        selectImportedTrackForEditing(in: firstWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForStaticTextValue(
                in: firstWindow,
                identifier: UIID.albumExternalFileValueProbe,
                expectedValue: conflictingAlbum,
                timeout: 20.0
            )
        )
    }

    @MainActor
    func testPictureDescriptionEditKeepsInternalTrackStatusIcon() throws {
        let updatedDescription = "Internal Description \(UUID().uuidString)"
        let app = try launchApp(importFixture: true, exposeDiffMetadata: true)
        let window = app.windows.firstMatch

        XCTAssertTrue(window.waitForExistence(timeout: 10.0))
        selectImportedTrackForEditing(in: window, app: app, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForLabeledElement(
                in: window,
                identifier: UIID.trackStatusIcon,
                expectedLabel: "fish.fill",
                timeout: 10.0
            )
        )

        let albumArtSheet = openAlbumArtSheet(in: window, app: app)
        editCurrentAlbumArtDescription(
            in: albumArtSheet,
            app: app,
            description: updatedDescription
        )
        closeAlbumArtSheet(in: app)

        XCTAssertTrue(
            waitForLabeledElement(
                in: window,
                identifier: UIID.trackStatusIcon,
                expectedLabel: "fish",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextValue(
                in: window,
                identifier: UIID.frontCoverPictureExternalStateProbe,
                expectedValue: "none",
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testPictureDescriptionSaveInSecondWindowShowsExternalPictureDifferenceInFirstWindow() throws {
        let sharedFixtureURL = try prepareExternalOpenPanelFlacFixture(fileName: Self.fixtureFileName)
        let updatedDescription = "Observed External Description \(UUID().uuidString)"

        let app = try launchApp(exposeDiffMetadata: true)
        let (firstWindow, secondWindow) = try openSharedFixtureInTwoNewWindows(app: app, fixtureURL: sharedFixtureURL)

        focusWindow(secondWindow)
        selectImportedTrackForEditing(in: secondWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        let secondWindowAlbumArtSheet = openAlbumArtSheet(in: secondWindow, app: app)
        XCTAssertTrue(
            waitForStaticTextValue(
                in: secondWindowAlbumArtSheet,
                identifier: UIID.albumArtSheetCurrentSlot,
                expectedValue: "Front Cover",
                timeout: 10.0
            )
        )
        editCurrentAlbumArtDescription(
            in: secondWindowAlbumArtSheet,
            app: app,
            description: updatedDescription
        )
        performSavePictures(in: app)
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))
        closeAlbumArtSheet(in: app)

        focusWindow(firstWindow)
        selectImportedTrackForEditing(in: firstWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForLabeledElement(
                in: firstWindow,
                identifier: UIID.trackStatusIcon,
                expectedLabel: "exclamationmark.triangle",
                timeout: 20.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextValue(
                in: firstWindow,
                identifier: UIID.frontCoverPictureExternalStateProbe,
                expectedValue: "external",
                timeout: 20.0
            )
        )
    }

    @MainActor
    func testPictureBrowserShowsExternalOverlayOnlyForDifferingSlot() throws {
        let sharedFixtureURL = try prepareExternalOpenPanelFlacFixture(fileName: Self.fixtureFileName)
        let updatedDescription = "Slot Scoped External Description \(UUID().uuidString)"

        let app = try launchApp()
        let (firstWindow, secondWindow) = try openSharedFixtureInTwoNewWindows(app: app, fixtureURL: sharedFixtureURL)

        focusWindow(secondWindow)
        selectImportedTrackForEditing(in: secondWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        let secondWindowAlbumArtSheet = openAlbumArtSheet(in: secondWindow, app: app)
        editCurrentAlbumArtDescription(
            in: secondWindowAlbumArtSheet,
            app: app,
            description: updatedDescription
        )
        performSavePictures(in: app)
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))
        closeAlbumArtSheet(in: app)

        focusWindow(firstWindow)
        selectImportedTrackForEditing(in: firstWindow, app: app, expectedTitle: "Test Title", timeout: 20.0)
        let firstWindowAlbumArtSheet = openAlbumArtSheet(in: firstWindow, app: app)
        XCTAssertTrue(
            waitForStaticTextValue(
                in: firstWindowAlbumArtSheet,
                identifier: UIID.albumArtSheetCurrentSlot,
                expectedValue: "Front Cover",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextValue(
                in: firstWindowAlbumArtSheet,
                identifier: UIID.albumArtSheetExternalDifferenceState,
                expectedValue: "external",
                timeout: 20.0
            )
        )

        selectAlbumArtSlot(in: firstWindowAlbumArtSheet, app: app, component: "backCover")

        XCTAssertTrue(
            waitForStaticTextValue(
                in: firstWindowAlbumArtSheet,
                identifier: UIID.albumArtSheetCurrentSlot,
                expectedValue: "Back Cover",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextValue(
                in: firstWindowAlbumArtSheet,
                identifier: UIID.albumArtSheetExternalDifferenceState,
                expectedValue: "none",
                timeout: 20.0
            )
        )
    }

    @MainActor
    func testReopeningSavedSwiftTagDocumentShowsExternalPictureDescriptionDifferenceInPictureBrowser() throws {
        let persistentFixtureName = "saved-document-picture-description-\(UUID().uuidString)"
        let updatedDescription = "Saved Document External Description \(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Saved Document Picture Description \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        try? FileManager.default.removeItem(at: swiftTagDocumentURL)

        let saveApp = try launchApp(
            importFixture: true,
            persistentFixtureName: persistentFixtureName,
            exposeNavigationMetadata: true
        )
        saveApp.activate()
        selectImportedTrackForEditing(in: saveApp, expectedTitle: "Test Title", timeout: 20.0)
        clickMenuItem(in: saveApp, menuBarItem: "File", menuItem: "Save SwiftTag Document...")
        saveFileInSavePanel(in: saveApp, destinationURL: swiftTagDocumentURL)
        XCTAssertNil(waitForSaveErrorPresentation(in: saveApp, timeout: 1.0))
        XCTAssertTrue(waitForFileExistence(at: swiftTagDocumentURL, timeout: 10.0))
        saveApp.terminate()

        let modifierApp = try launchApp(
            importFixture: true,
            persistentFixtureName: persistentFixtureName,
            reuseImportedFixture: true
        )
        let modifierWindow = modifierApp.windows.firstMatch
        modifierApp.activate()
        selectImportedTrackForEditing(in: modifierApp, expectedTitle: "Test Title", timeout: 20.0)
        let modifierAlbumArtSheet = openAlbumArtSheet(in: modifierWindow, app: modifierApp)
        editCurrentAlbumArtDescription(
            in: modifierAlbumArtSheet,
            app: modifierApp,
            description: updatedDescription
        )
        performSavePictures(in: modifierApp)
        XCTAssertNil(waitForSaveErrorPresentation(in: modifierApp, timeout: 1.0))
        modifierApp.terminate()

        let reopenedApp = try launchApp(exposeNavigationMetadata: true)
        reopenedApp.activate()
        let reopenedWindow = try openSavedSwiftTagDocumentWindow(
            in: reopenedApp,
            documentURL: swiftTagDocumentURL
        )

        selectImportedTrackForEditing(in: reopenedWindow, app: reopenedApp, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForLabeledElement(
                in: reopenedApp,
                identifier: UIID.trackStatusIcon,
                expectedLabel: "exclamationmark.triangle",
                timeout: 10.0
            )
        )
        let reopenedAlbumArtSheet = openAlbumArtSheet(in: reopenedWindow, app: reopenedApp)
        XCTAssertTrue(
            waitForStaticTextValue(
                in: reopenedAlbumArtSheet,
                identifier: UIID.albumArtSheetCurrentSlot,
                expectedValue: "Front Cover",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextValue(
                in: reopenedAlbumArtSheet,
                identifier: UIID.albumArtSheetExternalDifferenceState,
                expectedValue: "external",
                timeout: 10.0
            )
        )
        selectAlbumArtSlot(in: reopenedAlbumArtSheet, app: reopenedApp, component: "backCover")
        XCTAssertTrue(
            waitForStaticTextValue(
                in: reopenedAlbumArtSheet,
                identifier: UIID.albumArtSheetCurrentSlot,
                expectedValue: "Back Cover",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextValue(
                in: reopenedAlbumArtSheet,
                identifier: UIID.albumArtSheetExternalDifferenceState,
                expectedValue: "none",
                timeout: 10.0
            )
        )
    }

    @MainActor
    func testReopeningSavedSwiftTagDocumentShowsExternalAddedPictureSlotInPictureBrowser() throws {
        let persistentFixtureName = "saved-document-picture-slot-\(UUID().uuidString)"
        let swiftTagDocumentURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("Saved Document Picture Slot \(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        let importedPictureURL = try temporaryPNGFixtureURL(
            name: "added-back-cover-\(UUID().uuidString)",
            color: .systemBlue
        )
        try? FileManager.default.removeItem(at: swiftTagDocumentURL)

        let saveApp = try launchApp(
            importFixture: true,
            importedPictureProfile: "single-front-cover",
            persistentFixtureName: persistentFixtureName,
            exposeNavigationMetadata: true
        )
        saveApp.activate()
        selectImportedTrackForEditing(in: saveApp, expectedTitle: "Test Title", timeout: 20.0)
        clickMenuItem(in: saveApp, menuBarItem: "File", menuItem: "Save SwiftTag Document...")
        saveFileInSavePanel(in: saveApp, destinationURL: swiftTagDocumentURL)
        XCTAssertNil(waitForSaveErrorPresentation(in: saveApp, timeout: 1.0))
        XCTAssertTrue(waitForFileExistence(at: swiftTagDocumentURL, timeout: 10.0))
        saveApp.terminate()

        let modifierApp = try launchApp(
            importFixture: true,
            importedPictureProfile: "single-front-cover",
            persistentFixtureName: persistentFixtureName,
            reuseImportedFixture: true
        )
        let modifierWindow = modifierApp.windows.firstMatch
        modifierApp.activate()
        selectImportedTrackForEditing(in: modifierApp, expectedTitle: "Test Title", timeout: 20.0)
        let modifierAlbumArtSheet = openAlbumArtSheet(in: modifierWindow, app: modifierApp)
        selectAlbumArtSlot(in: modifierAlbumArtSheet, app: modifierApp, component: "backCover")
        XCTAssertTrue(
            waitForStaticTextValue(
                in: modifierAlbumArtSheet,
                identifier: UIID.albumArtSheetCurrentSlot,
                expectedValue: "Back Cover",
                timeout: 10.0
            )
        )
        importPictureIntoCurrentAlbumArtSlot(
            in: modifierAlbumArtSheet,
            app: modifierApp,
            menuItemTitle: "Import Back Cover...",
            imageURL: importedPictureURL
        )
        performSavePictures(in: modifierApp)
        XCTAssertNil(waitForSaveErrorPresentation(in: modifierApp, timeout: 1.0))
        modifierApp.terminate()

        let reopenedApp = try launchApp(exposeNavigationMetadata: true, exposeDiffMetadata: true)
        reopenedApp.activate()
        let reopenedWindow = try openSavedSwiftTagDocumentWindow(
            in: reopenedApp,
            documentURL: swiftTagDocumentURL
        )

        selectImportedTrackForEditing(in: reopenedWindow, app: reopenedApp, expectedTitle: "Test Title", timeout: 20.0)
        XCTAssertTrue(
            waitForLabeledElement(
                in: reopenedApp,
                identifier: UIID.trackStatusIcon,
                expectedLabel: "exclamationmark.triangle",
                timeout: 10.0
            )
        )
        let reopenedAlbumArtSheet = openAlbumArtSheet(in: reopenedWindow, app: reopenedApp)
        XCTAssertTrue(
            waitForStaticTextValue(
                in: reopenedAlbumArtSheet,
                identifier: UIID.albumArtSheetCurrentSlot,
                expectedValue: "Front Cover",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextValue(
                in: reopenedAlbumArtSheet,
                identifier: UIID.albumArtSheetExternalDifferenceState,
                expectedValue: "none",
                timeout: 10.0
            )
        )
        selectAlbumArtSlot(in: reopenedAlbumArtSheet, app: reopenedApp, component: "backCover")
        XCTAssertTrue(
            waitForStaticTextValue(
                in: reopenedAlbumArtSheet,
                identifier: UIID.albumArtSheetCurrentSlot,
                expectedValue: "Back Cover",
                timeout: 10.0
            )
        )
        XCTAssertTrue(
            waitForStaticTextValue(
                in: reopenedAlbumArtSheet,
                identifier: UIID.albumArtSheetExternalDifferenceState,
                expectedValue: "external",
                timeout: 10.0
            )
        )
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
        performSavePictures(in: app)
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))

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
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))

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
        importedAlbumMode: String? = nil,
        importedTitleOverride: String? = nil,
        importedPictureProfile: String? = nil,
        openDocumentFixture: Bool = false,
        openDocumentWhileActive: Bool = false,
        menuImportFixturePath: String? = nil,
        menuImportAlbumMode: String? = nil,
        menuImportTitleOverride: String? = nil,
        menuImportPictureProfile: String? = nil,
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
        saveReferencedSwiftTagDocument: Bool? = nil,
        askToSaveNewSwiftTagDocument: Bool? = nil,
        failSwiftTagDocumentSave: Bool = false,
        openSaveNotificationRecordID: String? = nil,
        exposeNavigationMetadata: Bool = false,
        exposeDiffMetadata: Bool = false,
        enableFileActions: Bool = false,
        postSaveRenameBasename: String? = nil,
        postSaveDeleteAfterRename: Bool = false,
        waitForEditorUI: Bool = true
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ApplePersistenceIgnoreState"] = "YES"
        app.launchArguments.append(contentsOf: ["-ApplePersistenceIgnoreState", "YES"])
        if resetSaveSettings {
            app.launchEnvironment["UITEST_RESET_SAVE_SETTINGS"] = "1"
            app.launchArguments.append("-UITEST_RESET_SAVE_SETTINGS")
        }
        if let saveReferencedSwiftTagDocument {
            app.launchEnvironment["UITEST_SAVE_REFERENCED_SWIFTTAG_DOCUMENT"] = saveReferencedSwiftTagDocument ? "1" : "0"
        }
        if let askToSaveNewSwiftTagDocument {
            app.launchEnvironment["UITEST_ASK_TO_SAVE_NEW_SWIFTTAG_DOCUMENT"] = askToSaveNewSwiftTagDocument ? "1" : "0"
        }
        if failSwiftTagDocumentSave {
            app.launchEnvironment["UITEST_FAIL_SWIFTTAG_SAVE"] = "1"
            app.launchArguments.append("-UITEST_FAIL_SWIFTTAG_SAVE")
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
            if let importedAlbumMode {
                app.launchEnvironment["UITEST_FLAC_ALBUM_MODE"] = importedAlbumMode
            }
            if let importedTitleOverride {
                app.launchEnvironment["UITEST_FLAC_TITLE_OVERRIDE"] = importedTitleOverride
            }
            if let importedPictureProfile {
                app.launchEnvironment["UITEST_FLAC_PICTURE_PROFILE"] = importedPictureProfile
            }
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
            let menuImportFileName = URL(fileURLWithPath: menuImportFixturePath).lastPathComponent
            app.launchEnvironment["UITEST_MENU_FLAC_PATH"] = menuImportFileName
            let menuImportDataBase64 = try Data(contentsOf: URL(fileURLWithPath: menuImportFixturePath)).base64EncodedString()
            app.launchEnvironment["UITEST_MENU_FLAC_DATA_BASE64"] = menuImportDataBase64
            if let menuImportAlbumMode {
                app.launchEnvironment["UITEST_MENU_FLAC_ALBUM_MODE"] = menuImportAlbumMode
            }
            if let menuImportTitleOverride {
                app.launchEnvironment["UITEST_MENU_FLAC_TITLE_OVERRIDE"] = menuImportTitleOverride
            }
            if let menuImportPictureProfile {
                app.launchEnvironment["UITEST_MENU_FLAC_PICTURE_PROFILE"] = menuImportPictureProfile
            }
        }
        if openAlbumArtSheet {
            app.launchEnvironment["UITEST_OPEN_ALBUM_ART_SHEET"] = "1"
            app.launchArguments.append("-UITEST_OPEN_ALBUM_ART_SHEET")
        }
        if let saveSwiftTagDocumentPath {
            app.launchEnvironment["UITEST_SAVE_SWIFTTAG_PATH"] = saveSwiftTagDocumentPath
            app.launchArguments.append("-UITEST_SAVE_SWIFTTAG_PATH")
        }
        if let openSwiftTagDocumentPath {
            app.launchEnvironment["UITEST_OPEN_SWIFTTAG_PATH"] = openSwiftTagDocumentPath
            app.launchArguments.append("-UITEST_OPEN_SWIFTTAG_PATH")
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
        if exposeNavigationMetadata {
            app.launchEnvironment["UITEST_EXPOSE_NAVIGATION_METADATA"] = "1"
            app.launchArguments.append("-UITEST_EXPOSE_NAVIGATION_METADATA")
        }
        if exposeDiffMetadata {
            app.launchEnvironment["UITEST_EXPOSE_DIFF_METADATA"] = "1"
            app.launchArguments.append("-UITEST_EXPOSE_DIFF_METADATA")
        }
        if enableFileActions {
            app.launchEnvironment["UITEST_ENABLE_FILE_ACTIONS"] = "1"
            app.launchArguments.append("-UITEST_ENABLE_FILE_ACTIONS")
        }
        if let postSaveRenameBasename {
            app.launchEnvironment["UITEST_POST_SAVE_RENAME_BASENAME"] = postSaveRenameBasename
        }
        if postSaveDeleteAfterRename {
            app.launchEnvironment["UITEST_POST_SAVE_DELETE_AFTER_RENAME"] = "1"
            app.launchArguments.append("-UITEST_POST_SAVE_DELETE_AFTER_RENAME")
        }
        try setUITestControlValue(saveSwiftTagDocumentPath, fileName: "save-swifttag-path.txt")
        try setUITestControlValue(openSwiftTagDocumentPath, fileName: "open-swifttag-path.txt")
        app.launch()
        if waitForEditorUI {
            app.activate()
            XCTAssertTrue(
                app.windows.firstMatch.waitForExistence(timeout: 10.0)
                    || waitForWindowCount(in: app, minimumCount: 1, timeout: 10.0)
                    || app.textFields[UIID.albumTextField].waitForExistence(timeout: 5.0)
            )
        }
        return app
    }

    private func runAppleScript(
        _ source: String,
        arguments: [String] = [],
        terminologyBundleIdentifier: String? = nil,
        timeout: TimeInterval = 15.0
    ) throws -> String {
        XCTAssertTrue(arguments.isEmpty, "NSAppleScript harness does not support argv-style arguments.")
        _ = timeout

        let compiledSource: String
        if let terminologyBundleIdentifier {
            compiledSource = """
                using terms from application id "\(terminologyBundleIdentifier)"
                \(source)
                end using terms from
                """
        } else {
            compiledSource = source
        }

        guard let script = NSAppleScript(source: compiledSource) else {
            XCTFail(
                """
                AppleScript failed to compile.
                Script:
                \(compiledSource)
                """
            )
            return ""
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            XCTFail(
                """
                AppleScript failed.
                Script:
                \(compiledSource)

                Error:
                \(errorInfo)
                """
            )
        }

        return descriptor.stringValue ?? descriptor.description
    }

    private func requireAppleScriptHarnessEnabled() throws {
        guard ProcessInfo.processInfo.environment["SWIFTTAG_RUN_OSASCRIPT_TESTS"] == "1"
            || FileManager.default.fileExists(atPath: Self.appleScriptHarnessSentinelPath) else {
            throw XCTSkip(
                "Set SWIFTTAG_RUN_OSASCRIPT_TESTS=1 or create \(Self.appleScriptHarnessSentinelPath) to run external osascript automation."
            )
        }
    }

    private func dismissImportErrorAlertIfPresent(
        in app: XCUIApplication,
        timeout: TimeInterval = 0.5
    ) -> String? {
        let alert = app.alerts["FLAC Import Error"].firstMatch
        guard alert.waitForExistence(timeout: timeout) else {
            return nil
        }

        let message = alert.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.isEmpty && $0 != "FLAC Import Error" }
            .joined(separator: "\n")
        let okButton = alert.buttons["OK"].firstMatch
        if okButton.exists {
            okButton.tap()
        }
        return message.isEmpty ? "FLAC Import Error" : message
    }

    private func normalizedAppleScriptTextOutput(_ output: String) -> String {
        output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private func prepareSwiftTagDocumentFixture(
        sourceFlacURL: URL,
        savedAlbum: String,
        savedTitle: String
    ) throws -> URL {
        let destinationURL = appContainerUITestFixturesDirectoryURL()
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
            "SwiftTags": [
                "Author": "SwiftTag"
            ],
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
        let destinationDirectoryURL = appContainerUITestFixturesDirectoryURL()
            .appendingPathComponent("ReadableFLAC", isDirectory: true)
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

    private func prepareExternalOpenPanelFlacFixture(
        fileName: String,
        destinationFileName: String? = nil
    ) throws -> URL {
        let sourceURL = URL(fileURLWithPath: fixtureFlacPath(fileName: fileName))
        let destinationDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTagUITestExternal", isDirectory: true)
        try FileManager.default.createDirectory(
            at: destinationDirectoryURL,
            withIntermediateDirectories: true
        )

        let destinationURL = destinationDirectoryURL
            .appendingPathComponent(destinationFileName ?? "\(UUID().uuidString)-\(fileName)")
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    @MainActor
    private func saveSwiftTagDocumentFromImportedFixture(
        persistentFixtureName: String,
        swiftTagDocumentURL: URL,
        postSaveRenameBasename: String? = nil,
        postSaveDeleteAfterRename: Bool = false
    ) throws -> (app: XCUIApplication, window: XCUIElement, flacURL: URL) {
        try? FileManager.default.removeItem(at: swiftTagDocumentURL)

        let app = try launchApp(
            importFixture: true,
            persistentFixtureName: persistentFixtureName,
            exposeNavigationMetadata: true,
            postSaveRenameBasename: postSaveRenameBasename,
            postSaveDeleteAfterRename: postSaveDeleteAfterRename
        )
        let window = app.windows.firstMatch

        selectImportedTrackForEditing(in: app, expectedTitle: "Test Title", timeout: 20.0)

        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Save SwiftTag Document...")
        saveFileInSavePanel(in: app, destinationURL: swiftTagDocumentURL)
        XCTAssertNil(waitForSaveErrorPresentation(in: app, timeout: 1.0))
        XCTAssertTrue(waitForFileExistence(at: swiftTagDocumentURL, timeout: 10.0))

        let flacURL = try referencedFlacURL(in: swiftTagDocumentURL)
        if postSaveRenameBasename == nil {
            XCTAssertTrue(
                waitForStaticTextLabel(
                    in: window,
                    identifier: UIID.trackFilenameText,
                    expectedValue: flacURL.lastPathComponent,
                    timeout: 10.0
                )
            )
        }

        return (app: app, window: window, flacURL: flacURL)
    }

    private func referencedFlacURL(in swiftTagDocumentURL: URL) throws -> URL {
        let infoPlistURL = swiftTagDocumentURL.appendingPathComponent("Info.plist")
        let plistData = try Data(contentsOf: infoPlistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        )
        let tracks = try XCTUnwrap(plist["Tracks"] as? [[String: Any]])
        let firstTrack = try XCTUnwrap(tracks.first)
        let fileURLString = try XCTUnwrap(firstTrack["FLAC File URL"] as? String)
        return URL(fileURLWithPath: URL(string: fileURLString)?.path ?? fileURLString)
    }

    private func performUITestFileAction(
        operation: String,
        sourceURL: URL,
        destinationURL: URL? = nil,
        timeout: TimeInterval = 10.0
    ) throws {
        var actionLines = [operation, sourceURL.path]
        if let destinationURL {
            actionLines.append(destinationURL.path)
        }
        let actionValue = actionLines.joined(separator: "\n")
        let targetDirectoryURL = try XCTUnwrap(
            uiTestControlDirectoryURLWithReadyMarker() ?? uiTestControlDirectoryURLs().first
        )
        let targetActionURL = targetDirectoryURL.appendingPathComponent("file-action.txt")
        try actionValue.write(to: targetActionURL, atomically: true, encoding: .utf8)

        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if !FileManager.default.fileExists(atPath: targetActionURL.path) {
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        XCTFail("Timed out waiting for UI test file action to be consumed.")
    }

    private func waitForUITestFileActionReady(timeout: TimeInterval = 10.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if uiTestControlValueIfPresent(fileName: "file-action-ready.txt") == "ready" {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func uiTestControlDirectoryURLWithReadyMarker() -> URL? {
        uiTestControlDirectoryURLs().first { directoryURL in
            let readyURL = directoryURL.appendingPathComponent("file-action-ready.txt")
            let isReady = (try? String(contentsOf: readyURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)) == "ready"
            return isReady && isUITestControlDirectoryWritable(directoryURL)
        }
    }

    private func isUITestControlDirectoryWritable(_ directoryURL: URL) -> Bool {
        let probeURL = directoryURL.appendingPathComponent("write-probe-\(UUID().uuidString).txt")
        do {
            try "probe".write(to: probeURL, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(at: probeURL)
            return true
        } catch {
            return false
        }
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

    private func enableSwiftTagDocumentFollowOnSaveSettings(
        in app: XCUIApplication,
        askToSaveNewDocument: Bool
    ) {
        openSettings(in: app)
        clickSettingsTab(in: app, named: "General")
        XCTAssertTrue(settingsControl(in: app, identifier: UIID.saveReferencedSwiftTagDocument).waitForExistence(timeout: 2.0))
        setToggle(in: app, identifier: UIID.saveReferencedSwiftTagDocument, isOn: true)
        XCTAssertTrue(settingsControl(in: app, identifier: UIID.askToSaveNewSwiftTagDocument).waitForExistence(timeout: 2.0))
        setToggle(in: app, identifier: UIID.askToSaveNewSwiftTagDocument, isOn: askToSaveNewDocument)
        typeEscape(in: app)
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

    private func performSavePictures(in app: XCUIApplication) {
        app.activate()
        app.typeKey("s", modifierFlags: [.command, .option])
    }

    private func openAlbumArtSheet(in window: XCUIElement, app: XCUIApplication) -> XCUIElement {
        let albumArtWell = window.descendants(matching: .any)
            .matching(identifier: UIID.albumArtImageWell)
            .firstMatch
        XCTAssertTrue(albumArtWell.waitForExistence(timeout: 10.0))
        albumArtWell.rightClick()

        let menuItem = app.menuItems["Show Picture Browser"].firstMatch
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5.0))
        menuItem.click()

        let imageWell = app.descendants(matching: .any)
            .matching(identifier: "albumArt.sheet.imageWell")
            .firstMatch
        XCTAssertTrue(imageWell.waitForExistence(timeout: 10.0))

        XCTAssertTrue(
            waitForStaticTextValue(
                in: app,
                identifier: UIID.albumArtSheetCurrentSlot,
                expectedValue: "Front Cover",
                timeout: 10.0
            )
        )

        return app
    }

    private func editCurrentAlbumArtDescription(
        in albumArtSheet: XCUIElement,
        app: XCUIApplication,
        description: String
    ) {
        let imageWell = albumArtSheet.descendants(matching: .any)
            .matching(identifier: "albumArt.sheet.imageWell")
            .firstMatch
        XCTAssertTrue(imageWell.waitForExistence(timeout: 10.0))
        imageWell.rightClick()

        let editDescriptionItem = app.menuItems["Edit Description..."].firstMatch
        XCTAssertTrue(editDescriptionItem.waitForExistence(timeout: 5.0))
        editDescriptionItem.click()

        let descriptionSheet = app.descendants(matching: .any)
            .matching(identifier: UIID.albumArtSheetPictureDescription)
            .firstMatch
        XCTAssertTrue(descriptionSheet.waitForExistence(timeout: 10.0))

        let descriptionEditorCandidates = [
            descriptionSheet.descendants(matching: .any)
                .matching(identifier: UIID.albumArtSheetPictureDescriptionEditor)
                .firstMatch,
            descriptionSheet.descendants(matching: .textView).firstMatch,
            descriptionSheet.descendants(matching: .scrollView).firstMatch
        ]
        if let descriptionEditor = descriptionEditorCandidates.first(where: { candidate in
            candidate.waitForExistence(timeout: 1.0)
        }) {
            clearAndTypeInTextView(in: app, element: descriptionEditor, text: description)
        } else {
            descriptionSheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).click()
            app.typeKey("a", modifierFlags: .command)
            app.typeText(description)
        }

        clickPictureDescriptionSave(in: app, descriptionSheet: descriptionSheet)
        XCTAssertTrue(waitForExistence(of: descriptionSheet, expectedValue: false, timeout: 5.0))
    }

    private func importPictureIntoCurrentAlbumArtSlot(
        in albumArtSheet: XCUIElement,
        app: XCUIApplication,
        menuItemTitle: String,
        imageURL: URL
    ) {
        let imageWell = albumArtSheet.descendants(matching: .any)
            .matching(identifier: "albumArt.sheet.imageWell")
            .firstMatch
        XCTAssertTrue(imageWell.waitForExistence(timeout: 10.0))
        imageWell.rightClick()

        let importItem = app.menuItems[menuItemTitle].firstMatch
        XCTAssertTrue(importItem.waitForExistence(timeout: 5.0))
        importItem.click()
        chooseFileInOpenPanel(in: app, path: imageURL.path)
    }

    private func closeAlbumArtSheet(in app: XCUIApplication) {
        let imageWell = app.descendants(matching: .any)
            .matching(identifier: "albumArt.sheet.imageWell")
            .firstMatch
        guard imageWell.waitForExistence(timeout: 2.0) else {
            return
        }

        typeEscape(in: app)
        XCTAssertTrue(waitForExistence(of: imageWell, expectedValue: false, timeout: 5.0))
    }

    private func performSaveSwiftTagDocumentShortcut(in app: XCUIApplication) {
        app.activate()
        app.typeKey("s", modifierFlags: [.control])
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

    private func clearAndTypeInTextView(in app: XCUIApplication, element: XCUIElement, text: String) {
        element.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText(text)
    }

    private func clickPictureDescriptionSave(in app: XCUIApplication, descriptionSheet: XCUIElement) {
        let saveButtonCandidates = [
            app.descendants(matching: .button)
                .matching(identifier: UIID.albumArtSheetPictureDescriptionDoneButton)
                .firstMatch,
            app.descendants(matching: .any)
                .matching(identifier: UIID.albumArtSheetPictureDescriptionDoneButton)
                .firstMatch,
            app.sheets.buttons["Save"].firstMatch,
            app.dialogs.buttons["Save"].firstMatch
        ]

        if let saveButton = saveButtonCandidates.first(where: { candidate in
            candidate.waitForExistence(timeout: 1.0)
        }) {
            if saveButton.isHittable {
                saveButton.click()
                return
            }
        }

        // Move focus off the text editor so the sheet's default action can receive Return.
        descriptionSheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).click()
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
    }

    private func selectAlbumArtSlot(
        in albumArtSheet: XCUIElement,
        app: XCUIApplication,
        component: String
    ) {
        showAlbumArtSlotList(in: albumArtSheet, app: app)

        let slotRow = albumArtSheet.descendants(matching: .any)
            .matching(identifier: UIID.albumArtSheetSlotPrefix + component)
            .firstMatch
        if !slotRow.waitForExistence(timeout: 5.0) {
            XCTFail("Missing album art slot row \(component).")
            return
        }

        slotRow.click()
    }

    private func showAlbumArtSlotList(in albumArtSheet: XCUIElement, app: XCUIApplication) {
        let frontCoverRow = albumArtSheet.descendants(matching: .any)
            .matching(identifier: UIID.albumArtSheetSlotPrefix + "frontCover")
            .firstMatch
        if frontCoverRow.waitForExistence(timeout: 1.0) {
            return
        }

        let backButtonCandidates = [
            albumArtSheet.buttons["Back"].firstMatch,
            albumArtSheet.descendants(matching: .button)
                .matching(identifier: "chevron.backward")
                .firstMatch,
            app.buttons["Back"].firstMatch,
            app.descendants(matching: .button)
                .matching(identifier: "chevron.backward")
                .firstMatch
        ]

        if let backButton = backButtonCandidates.first(where: { candidate in
            candidate.waitForExistence(timeout: 1.0)
        }) {
            backButton.click()
        }
    }

    private func temporaryPNGFixtureURL(name: String, color: NSColor) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTagUITestImages", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let imageURL = directoryURL.appendingPathComponent(name).appendingPathExtension("png")
        try? FileManager.default.removeItem(at: imageURL)

        let imageSize = NSSize(width: 24, height: 24)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()
        image.unlockFocus()

        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmapRepresentation = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        let pngData = try XCTUnwrap(bitmapRepresentation.representation(using: .png, properties: [:]))
        try pngData.write(to: imageURL)
        return imageURL
    }

    private func selectImportedTrackForEditing(
        in app: XCUIApplication,
        expectedTitle: String,
        timeout: TimeInterval = 10.0
    ) {
        let titleField = app.textFields.matching(NSPredicate(format: "value == %@", expectedTitle)).firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: timeout), "Expected imported track title field '\(expectedTitle)' to exist.")
        titleField.click()
        XCTAssertTrue(
            waitForEnabledState(of: editableAlbumField(in: app), expectedValue: true, timeout: timeout),
            "Album field did not become editable after selecting imported track '\(expectedTitle)'."
        )
    }

    private func selectImportedTrackForEditing(
        in window: XCUIElement,
        app: XCUIApplication,
        expectedTitle: String,
        timeout: TimeInterval = 10.0
    ) {
        let titleField = window.descendants(matching: .textField)
            .matching(NSPredicate(format: "value == %@", expectedTitle))
            .firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: timeout), "Expected imported track title field '\(expectedTitle)' to exist in the target window.")
        titleField.click()
        XCTAssertTrue(
            waitForEnabledState(of: editableAlbumField(in: window), expectedValue: true, timeout: timeout),
            "Album field did not become editable after selecting imported track '\(expectedTitle)' in the target window."
        )
    }

    private func editableAlbumField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(
            NSPredicate(
                format: "identifier == %@ AND value != %@",
                UIID.albumTextField,
                PlaceholderText.noSelection
            )
        ).firstMatch
    }

    private func editableAlbumField(in scope: XCUIElement) -> XCUIElement {
        scope.descendants(matching: .textField).matching(
            NSPredicate(
                format: "identifier == %@ AND value != %@",
                UIID.albumTextField,
                PlaceholderText.noSelection
            )
        ).firstMatch
    }

    private func editableAlbumArtistField(in scope: XCUIElement) -> XCUIElement {
        scope.descendants(matching: .textField).matching(identifier: UIID.albumArtistTextField).firstMatch
    }

    private func compilationCheckbox(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: UIID.compilationCheckbox).firstMatch
    }

    private func openTrackContextMenu(in app: XCUIApplication, expectedTitle: String) {
        let titleField = app.textFields.matching(NSPredicate(format: "value == %@", expectedTitle)).firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 10.0))
        titleField.rightClick()
    }

    private func focusWindow(_ window: XCUIElement) {
        XCTAssertTrue(window.waitForExistence(timeout: 5.0))
        if window.isHittable {
            window.click()
        }
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

    private func waitForTextFieldValue(
        in scope: XCUIElement,
        identifier: String,
        expectedValue: String,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        let textField = scope.descendants(matching: .textField).matching(identifier: identifier).firstMatch
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

    private func waitForStaticTextValue(
        in scope: XCUIElement,
        identifier: String,
        expectedValue: String,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        let text = scope.descendants(matching: .staticText).matching(identifier: identifier).firstMatch
        guard text.waitForExistence(timeout: timeout) else {
            return false
        }

        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let value = text.value as? String, value == expectedValue {
                return true
            }
            if text.label == expectedValue {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func waitForStaticTextLabel(
        in scope: XCUIElement,
        identifier: String,
        expectedValue: String,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        let staticTexts = scope.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", identifier))
        let normalizedExpectedValue = expectedValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for staticText in staticTexts.allElementsBoundByIndex where staticText.exists {
                let normalizedLabel = staticText.label
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let normalizedValue = (staticText.value as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                if normalizedLabel == normalizedExpectedValue || normalizedValue == normalizedExpectedValue {
                    return true
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }


    private func waitForNavigationTitle(
        in window: XCUIElement,
        expectedValue: String,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        waitForStaticTextLabel(
            in: window,
            identifier: UIID.navigationTitleProbe,
            expectedValue: expectedValue,
            timeout: timeout
        )
    }

    private func waitForNavigationSubtitle(
        in window: XCUIElement,
        expectedValue: String,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        waitForStaticTextLabel(
            in: window,
            identifier: UIID.navigationSubtitleProbe,
            expectedValue: expectedValue,
            timeout: timeout
        )
    }

    private func navigationSubtitleProbeValues(in window: XCUIElement) -> [String] {
        let staticTexts = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", UIID.navigationSubtitleProbe))

        return staticTexts.allElementsBoundByIndex
            .filter(\.exists)
            .flatMap { element in
                [element.label, element.value as? String]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
    }

    private func waitForNavigationDocumentURL(
        in window: XCUIElement,
        expectedValue: String,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        waitForStaticTextLabel(
            in: window,
            identifier: UIID.navigationDocumentURLProbe,
            expectedValue: expectedValue,
            timeout: timeout
        )
    }

    private func waitForSaveNewSwiftTagDocumentPromptState(
        in window: XCUIElement,
        expectedValue: String,
        timeout: TimeInterval = 5.0
    ) -> Bool {
        waitForStaticTextLabel(
            in: window,
            identifier: UIID.saveNewSwiftTagDocumentPromptProbe,
            expectedValue: expectedValue,
            timeout: timeout
        )
    }

    private func clickSaveNewSwiftTagDocumentPromptButton(in app: XCUIApplication, title: String) {
        let dialogButton = app.dialogs.buttons[title].firstMatch
        if dialogButton.waitForExistence(timeout: 1.0) {
            if dialogButton.isHittable {
                dialogButton.click()
            } else if title == "Save" {
                app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
            } else {
                XCTFail("Prompt button '\(title)' exists but is not hittable.")
            }
            return
        }

        let sheetButton = app.sheets.buttons[title].firstMatch
        if sheetButton.waitForExistence(timeout: 1.0) {
            if sheetButton.isHittable {
                sheetButton.click()
            } else if title == "Save" {
                app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
            } else {
                XCTFail("Prompt button '\(title)' exists but is not hittable.")
            }
            return
        }

        if title == "Save" {
            app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
            return
        }

        XCTFail("Prompt button '\(title)' was not found in dialog or sheet containers.")
    }

    private func waitForSaveErrorPresentation(
        in app: XCUIApplication,
        timeout: TimeInterval = 5.0
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            let dialog = app.dialogs.containing(.staticText, identifier: "Save Error").firstMatch
            if dialog.exists {
                return dialog
            }

            let sheet = app.sheets.containing(.staticText, identifier: "Save Error").firstMatch
            if sheet.exists {
                return sheet
            }

            let alert = app.alerts["Save Error"].firstMatch
            if alert.exists {
                return alert
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return nil
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

    private func window(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.windows[identifier]
    }

    private func waitForNewWindowIdentifier(
        in app: XCUIApplication,
        excluding existingIdentifiers: Set<String>,
        timeout: TimeInterval
    ) -> String {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            for window in app.windows.allElementsBoundByIndex {
                let identifier = windowIdentifier(window)
                if !existingIdentifiers.contains(identifier) {
                    return identifier
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return windowIdentifier(app.windows.firstMatch)
    }

    private func waitForNewWindow(
        in app: XCUIApplication,
        excluding existingIdentifiers: Set<String>,
        timeout: TimeInterval
    ) -> XCUIElement {
        app.windows[waitForNewWindowIdentifier(in: app, excluding: existingIdentifiers, timeout: timeout)]
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

    private func launchAppByOpeningFileWithSwiftTag(
        url: URL,
        timeout: TimeInterval = 10.0
    ) throws -> XCUIApplication {
        let applicationURL = resolvedSwiftTagApplicationURL()
        terminateRunningSwiftTagIfNeeded()

        guard let applicationURL else {
            XCTFail("SwiftTag application URL could not be resolved.")
            throw NSError(domain: "SwiftTagUITests", code: 1)
        }

        let app = XCUIApplication()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        let completionExpectation = XCTestExpectation(
            description: "launch \(url.lastPathComponent) in SwiftTag via Finder-style open"
        )
        var openError: Error?

        NSWorkspace.shared.open(
            [url],
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { _, error in
            openError = error
            completionExpectation.fulfill()
        }

        let waitResult = XCTWaiter.wait(for: [completionExpectation], timeout: timeout)
        XCTAssertEqual(waitResult, .completed)
        XCTAssertNil(openError)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: timeout))
        return app
    }

    private func resolvedSwiftTagApplicationURL() -> URL? {
        if let runningApplicationURL = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.appBundleIdentifier)
            .first?
            .bundleURL {
            return runningApplicationURL
        }

        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.appBundleIdentifier)
    }

    private func runningSwiftTagApplicationURL(timeout: TimeInterval = 10.0) -> URL? {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            if let runningApplicationURL = NSRunningApplication
                .runningApplications(withBundleIdentifier: Self.appBundleIdentifier)
                .first(where: { $0.isFinishedLaunching })?
                .bundleURL {
                return runningApplicationURL
            }

            if let namedApplicationURL = NSWorkspace.shared.runningApplications
                .filter({
                    $0.localizedName == "SwiftTag"
                        && $0.isFinishedLaunching
                        && $0.bundleURL?.lastPathComponent == "SwiftTag.app"
                })
                .sorted(by: { ($0.launchDate ?? .distantPast) > ($1.launchDate ?? .distantPast) })
                .first?
                .bundleURL {
                return namedApplicationURL
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return resolvedSwiftTagApplicationURL()
    }

    private func terminateRunningSwiftTagIfNeeded(timeout: TimeInterval = 5.0) {
        let runningApplications = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.appBundleIdentifier)

        for runningApplication in runningApplications {
            _ = runningApplication.forceTerminate()
        }

        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if NSRunningApplication.runningApplications(
                withBundleIdentifier: Self.appBundleIdentifier
            ).isEmpty {
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
    }

    private func openSharedFixtureInTwoNewWindows(
        app: XCUIApplication,
        fixtureURL: URL,
        expectedTitle: String = "Test Title"
    ) throws -> (XCUIElement, XCUIElement) {
        XCTAssertTrue(waitForWindowCount(in: app, minimumCount: 1, timeout: 10.0))

        let existingWindowIdentifiers = Set(currentWindowIdentifiers(in: app))
        app.typeKey("n", modifierFlags: .command)
        let firstWindowIdentifier = waitForNewWindowIdentifier(
            in: app,
            excluding: existingWindowIdentifiers,
            timeout: 10.0
        )
        let firstWindow = window(in: app, identifier: firstWindowIdentifier)
        XCTAssertTrue(firstWindow.waitForExistence(timeout: 10.0))

        let firstWindowIdentifiers = Set(currentWindowIdentifiers(in: app))
        app.typeKey("n", modifierFlags: .command)
        let secondWindowIdentifier = waitForNewWindowIdentifier(
            in: app,
            excluding: firstWindowIdentifiers,
            timeout: 10.0
        )
        let secondWindow = window(in: app, identifier: secondWindowIdentifier)
        XCTAssertTrue(secondWindow.waitForExistence(timeout: 10.0))
        XCTAssertNotEqual(firstWindowIdentifier, secondWindowIdentifier)

        focusWindow(firstWindow)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Add FLAC files...")
        chooseFileInOpenPanel(in: app, path: fixtureURL.path)
        selectImportedTrackForEditing(in: firstWindow, app: app, expectedTitle: expectedTitle, timeout: 20.0)

        focusWindow(secondWindow)
        clickMenuItem(in: app, menuBarItem: "File", menuItem: "Add FLAC files...")
        chooseFileInOpenPanel(in: app, path: fixtureURL.path)
        selectImportedTrackForEditing(in: secondWindow, app: app, expectedTitle: expectedTitle, timeout: 20.0)

        return (firstWindow, secondWindow)
    }

    private func openSavedSwiftTagDocumentWindow(
        in app: XCUIApplication,
        documentURL: URL,
        timeout: TimeInterval = 10.0
    ) throws -> XCUIElement {
        let existingIdentifiers = Set(currentWindowIdentifiers(in: app))
        XCTAssertTrue(openFileWithSwiftTag(url: documentURL, timeout: timeout))

        let openedWindow = waitForNewWindow(
            in: app,
            excluding: existingIdentifiers,
            timeout: 2.0
        )
        XCTAssertTrue(
            waitForNavigationDocumentURL(
                in: openedWindow,
                expectedValue: documentURL.standardizedFileURL.path,
                timeout: timeout
            )
        )
        focusWindow(openedWindow)
        return openedWindow
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

    private func appContainerUITestFixturesDirectoryURL() -> URL {
        let directoryURL = appContainerCachesDirectoryURL()
            .appendingPathComponent("SwiftTagUITestFixtures", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func uiTestControlDirectoryURL() -> URL {
        uiTestControlDirectoryURLs().first ?? appContainerCachesDirectoryURL()
            .appendingPathComponent("SwiftTagUITestControls", isDirectory: true)
    }

    private func uiTestControlDirectoryURLs() -> [URL] {
        let runnerNestedDirectoryURL = appContainerCachesDirectoryURL()
            .appendingPathComponent("SwiftTagUITestControls", isDirectory: true)
        let appControlDirectoryURL = URL(fileURLWithPath: "/Users", isDirectory: true)
            .appendingPathComponent(NSUserName(), isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent("com.toowalks.swifttag", isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("SwiftTagUITestControls", isDirectory: true)

        let directories = [runnerNestedDirectoryURL, appControlDirectoryURL]
        for directoryURL in directories {
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directories.enumerated().compactMap { index, directoryURL in
            directories.firstIndex(of: directoryURL) == index ? directoryURL : nil
        }
    }

    private func uiTestControlValueIfPresent(fileName: String) -> String? {
        for directoryURL in uiTestControlDirectoryURLs() {
            let controlURL = directoryURL.appendingPathComponent(fileName)
            guard let rawValue = try? String(contentsOf: controlURL, encoding: .utf8) else {
                continue
            }

            let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedValue.isEmpty {
                return trimmedValue
            }
        }
        return nil
    }

    private func setUITestControlValue(_ value: String?, fileName: String) throws {
        var didSucceed = false
        var lastError: Error?

        for directoryURL in uiTestControlDirectoryURLs() {
            let controlURL = directoryURL.appendingPathComponent(fileName)
            do {
                if let value {
                    try value.write(to: controlURL, atomically: true, encoding: .utf8)
                } else {
                    try? FileManager.default.removeItem(at: controlURL)
                }
                didSucceed = true
            } catch {
                lastError = error
            }
        }

        if !didSucceed, let lastError {
            throw lastError
        }
    }

    private func clearUITestControlFiles() throws {
        try setUITestControlValue(nil, fileName: "save-swifttag-path.txt")
        try setUITestControlValue(nil, fileName: "open-swifttag-path.txt")
        try setUITestControlValue(nil, fileName: "file-action.txt")
        try setUITestControlValue(nil, fileName: "file-action-result.txt")
        try setUITestControlValue(nil, fileName: "file-action-ready.txt")
    }

    private func chooseFileInOpenPanel(in app: XCUIApplication, path: String) {
        XCTAssertTrue(waitForOpenPanel(in: app, timeout: 5.0))

        app.typeKey("g", modifierFlags: [.command, .shift])

        let goToFolderSheet = app.sheets.firstMatch
        XCTAssertTrue(goToFolderSheet.waitForExistence(timeout: 5.0))

        let pathField = goToFolderSheet.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 5.0))
        pathField.click()
        replaceText(in: app, element: pathField, text: path)
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])

        let openPanel = currentOpenPanel(in: app)
        XCTAssertTrue(openPanel.waitForExistence(timeout: 5.0))

        let openButton = openPanel.buttons["Open"].firstMatch
        XCTAssertTrue(openButton.waitForExistence(timeout: 5.0))
        if openButton.isHittable {
            openButton.click()
        } else {
            app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
        }
    }

    private func saveFileInSavePanel(in app: XCUIApplication, destinationURL: URL) {
        XCTAssertTrue(waitForSavePanel(in: app, timeout: 5.0))

        app.typeKey("g", modifierFlags: [.command, .shift])

        let goToFolderSheet = app.sheets.firstMatch
        XCTAssertTrue(goToFolderSheet.waitForExistence(timeout: 5.0))

        let pathField = goToFolderSheet.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 5.0))
        replaceText(in: app, element: pathField, text: destinationURL.deletingLastPathComponent().path)
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])

        let savePanel = currentSavePanel(in: app)
        XCTAssertTrue(savePanel.waitForExistence(timeout: 5.0))

        let nameField = savePanel.comboBoxes.firstMatch.exists
            ? savePanel.comboBoxes.firstMatch
            : savePanel.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5.0))
        replaceText(
            in: app,
            element: nameField,
            text: destinationURL.deletingPathExtension().lastPathComponent
        )

        let saveButton = savePanel.buttons["Save"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5.0))
        saveButton.click()
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

    private func currentOpenPanel(in app: XCUIApplication) -> XCUIElement {
        let dialogOpenButton = app.dialogs.buttons["Open"].firstMatch
        if dialogOpenButton.exists {
            return app.dialogs.firstMatch
        }

        return app.sheets.firstMatch
    }

    private func waitForSavePanel(in app: XCUIApplication, timeout: TimeInterval = 5.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            let sheetSaveButton = app.sheets.buttons["Save"].firstMatch
            let dialogSaveButton = app.dialogs.buttons["Save"].firstMatch
            if sheetSaveButton.exists || dialogSaveButton.exists {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func currentSavePanel(in app: XCUIApplication) -> XCUIElement {
        let sheetSaveButton = app.sheets.buttons["Save"].firstMatch
        if sheetSaveButton.exists {
            return app.sheets.firstMatch
        }

        return app.dialogs.firstMatch
    }

    private func cancelSavePanel(in app: XCUIApplication) {
        let savePanel = currentSavePanel(in: app)
        XCTAssertTrue(savePanel.waitForExistence(timeout: 5.0))

        let cancelButton = savePanel.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5.0))
        cancelButton.click()
    }

    private func swiftTagDocumentTagValue(in documentURL: URL, key: String) -> String? {
        let infoPlistURL = documentURL.appendingPathComponent("Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let tracks = plist["Tracks"] as? [[String: Any]],
              let firstTrack = tracks.first,
              let tags = firstTrack["Tags"] as? [String: String] else {
            return nil
        }

        return tags[key]
    }

    private func waitForSwiftTagDocumentTagValue(
        in documentURL: URL,
        key: String,
        expectedValue: String,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            if swiftTagDocumentTagValue(in: documentURL, key: key) == expectedValue {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return swiftTagDocumentTagValue(in: documentURL, key: key) == expectedValue
    }

    private func replaceText(in app: XCUIApplication, element: XCUIElement, text: String) {
        element.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText(text)
    }

    private func waitForLabeledElement(
        in app: XCUIApplication,
        identifier: String,
        expectedLabel: String,
        timeout: TimeInterval = 2.0
    ) -> Bool {
        let query = app.descendants(matching: .any).matching(identifier: identifier)
        let normalizedExpectedLabel = expectedLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for element in query.allElementsBoundByIndex where element.exists {
                let normalizedLabel = element.label
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                if normalizedLabel == normalizedExpectedLabel {
                    return true
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func waitForLabeledElement(
        in scope: XCUIElement,
        identifier: String,
        expectedLabel: String,
        timeout: TimeInterval = 2.0
    ) -> Bool {
        let query = scope.descendants(matching: .any).matching(identifier: identifier)
        let normalizedExpectedLabel = expectedLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for element in query.allElementsBoundByIndex where element.exists {
                let normalizedLabel = element.label
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                if normalizedLabel == normalizedExpectedLabel {
                    return true
                }
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

    private func waitForExistence(
        of element: XCUIElement,
        expectedValue: Bool,
        timeout: TimeInterval = 2.0
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists == expectedValue {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

    private func waitForHittableState(
        of element: XCUIElement,
        expectedValue: Bool,
        timeout: TimeInterval = 2.0
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists && element.isHittable == expectedValue {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return false
    }

}
