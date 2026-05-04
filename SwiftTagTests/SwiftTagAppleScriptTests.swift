import AppKit
import Foundation
import SwiftUI
import Testing
@testable import SwiftTag

@Suite(.serialized)
struct SwiftTagAppleScriptTests {
    @MainActor
    @Test
    func insertingScriptEditorWindowOpensMatchingEditorSession() throws {
        let application = NSApplication.shared

        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        var openedSessions: [EditorSessionValue] = []
        EditorWindowCoordinator.shared.setOpenEditorWindowAction { sessionValue in
            openedSessions.append(sessionValue)
        }
        var activationRequests = 0
        EditorWindowCoordinator.shared.setAppActivationHandlerForTesting {
            activationRequests += 1
        }

        let scriptWindow = SwiftTagScriptEditorWindow()
        application.insertInScriptEditorWindows(scriptWindow)

        let openedSession = try #require(openedSessions.first)
        #expect(openedSessions.count == 1)
        #expect(openedSession.sessionID.uuidString == scriptWindow.windowID)
        #expect(activationRequests == 0)

        let resolvedWindow = try #require(
            application.valueInScriptEditorWindows(withUniqueID: scriptWindow.windowID as NSString)
                as? SwiftTagScriptEditorWindow
        )
        #expect(resolvedWindow.windowID == scriptWindow.windowID)
        #expect(application.scriptEditorWindows.contains(where: { $0.windowID == scriptWindow.windowID }))
    }

    @MainActor
    @Test
    func openSwiftTagDocumentReturnsPendingDocumentWrapper() throws {
        let application = NSApplication.shared

        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let documentURL = try Self.tempPackageURL(name: "applescript-open")
        _ = try SwiftTagDocumentPackageWriter.save(
            tracks: [],
            state: .init(),
            to: documentURL
        )

        let openedDocuments = try application.openSwiftTagDocuments([documentURL])

        #expect(openedDocuments.count == 1)
        let openedDocument = try #require(openedDocuments.first)
        #expect(openedDocument.fileURL == documentURL.standardizedFileURL)
        #expect(openedDocument.name == documentURL.lastPathComponent)
        #expect(application.scriptDocuments.contains(where: { $0.fileURL == documentURL.standardizedFileURL }))
        #expect(!application.scriptEditorWindows.isEmpty)
        #expect(openedDocument.objectSpecifier != nil)
    }

    @MainActor
    @Test
    func savingScriptEditorWindowWritesEmptySwiftTagDocument() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let scriptWindow = SwiftTagScriptEditorWindow(sessionID: sessionID)
        var saveState = SwiftTagDocumentSaveState()
        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: saveState.documentDisplayName ?? "Untitled",
                        modified: false,
                        saveState: saveState
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(tracks: [], selectedTrackIDs: [])
                },
                addTracks: { _ in
                    []
                },
                selectTracks: { _ in
                },
                saveDocument: { destinationURL in
                    guard let destinationURL else {
                        throw SwiftTagAppleScriptCommandError.saveLocationRequired
                    }

                    let result = try SwiftTagDocumentPackageWriter.save(
                        tracks: [],
                        state: saveState,
                        to: destinationURL
                    )
                    saveState = SwiftTagDocumentSaveState(
                        destinationURL: result.destinationURL,
                        documentID: result.documentID,
                        securityScopedBookmarkData: result.securityScopedBookmarkData,
                        lastKnownDisplayName: result.destinationURL.lastPathComponent,
                        availability: .available
                    )
                    return saveState
                }
            )
        )

        let destinationURL = try Self.tempPackageURL(name: "applescript-empty-save")
        let savedDocument = try scriptWindow.saveSwiftTagDocument(to: destinationURL)
        let loadedDocument = try SwiftTagDocumentPackageReader.read(from: destinationURL)

        #expect(savedDocument.fileURL == destinationURL.standardizedFileURL)
        #expect(savedDocument.name == destinationURL.lastPathComponent)
        #expect(!savedDocument.modified)
        #expect(loadedDocument.tracks.isEmpty)
    }

    @MainActor
    @Test
    func applicationTracksExposeRegisteredSessionTracks() throws {
        let application = NSApplication.shared

        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let firstSessionID = UUID()
        let secondSessionID = UUID()
        let firstTrackURL = URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-first.flac")
        let secondTrackURL = URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-second.flac")
        let firstTrack = Track(
            tags: [TagKey.title: "First Track"],
            sourceFileURL: firstTrackURL
        )
        let secondTrack = Track(
            tags: [TagKey.title: "Second Track"],
            sourceFileURL: secondTrackURL
        )

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: firstSessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "First",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: [firstTrack],
                        selectedTrackIDs: []
                    )
                },
                addTracks: { _ in [] },
                selectTracks: { _ in },
                saveDocument: { _ in .init() }
            )
        )

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: secondSessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Second",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: [secondTrack],
                        selectedTrackIDs: []
                    )
                },
                addTracks: { _ in [] },
                selectTracks: { _ in },
                saveDocument: { _ in .init() }
            )
        )

        let trackURLs = Set(application.scriptTracks.compactMap(\.fileURL))
        #expect(trackURLs == [firstTrackURL.standardizedFileURL, secondTrackURL.standardizedFileURL])
    }

    @MainActor
    @Test
    func applicationClassDescriptionExposesWindowsAndEditorWindows() throws {
        let classDescription = try #require(NSScriptClassDescription(for: NSApplication.self))

        #expect(classDescription.type(forKey: "orderedWindows") == "window")
        #expect(classDescription.type(forKey: "scriptSettingsWindows") == "settings window")
        #expect(classDescription.type(forKey: "scriptEditorWindows") == "editor window")
    }

    @MainActor
    @Test
    func addCommandDescriptionExposesOptionalWithLockParameter() throws {
        let commandDescription = try #require(
            NSScriptSuiteRegistry.shared().commandDescription(
                withAppleEventClass: Self.fourCharCode("SwTG").uint32Value,
                andAppleEventCode: Self.fourCharCode("addt").uint32Value
            )
        )

        #expect(commandDescription.argumentNames.contains("WithLock"))
        #expect(commandDescription.typeForArgument(withName: "WithLock") == "boolean")
        #expect(commandDescription.isOptionalArgument(withName: "WithLock"))
        #expect(commandDescription.appleEventCodeForArgument(withName: "WithLock") == Self.fourCharCode("wlok").uint32Value)
    }

    @MainActor
    @Test
    func trackClassDescriptionExposesWritableLockedProperty() throws {
        let classDescription = try #require(NSScriptClassDescription(for: SwiftTagScriptTrack.self))

        #expect(classDescription.key(withAppleEventCode: Self.fourCharCode("tlok").uint32Value) == "trackLocked")
        #expect(classDescription.type(forKey: "trackLocked") == "boolean")
        #expect(classDescription.hasReadableProperty(forKey: "trackLocked"))
        #expect(classDescription.hasWritableProperty(forKey: "trackLocked"))
    }

    @MainActor
    @Test
    func settingsWindowIsSingletonApplicationElementAndInheritsWindowProperties() throws {
        let application = NSApplication.shared
        let classDescription = try #require(NSScriptClassDescription(for: SwiftTagScriptSettingsWindow.self))
        let applicationClassDescription = try #require(NSScriptClassDescription(for: NSApplication.self))
        let openSettingsWindowSelector = NSSelectorFromString("handleOpenSettingsWindowScriptCommand:")
        let openSettingsWindowCommand = try #require(
            NSScriptSuiteRegistry.shared().commandDescription(
                withAppleEventClass: Self.fourCharCode("SwTG").uint32Value,
                andAppleEventCode: Self.fourCharCode("oswn").uint32Value
            )
        )

        #expect(application.scriptSettingsWindows.count == 1)
        #expect(application.scriptSettingsWindows.first?.objectSpecifier != nil)
        #expect(classDescription.superclass?.className == "window")
        #expect(classDescription.hasReadableProperty(forKey: "title"))
        #expect(classDescription.hasReadableProperty(forKey: "uniqueID"))
        #expect(classDescription.hasWritableProperty(forKey: "orderedIndex"))
        #expect(classDescription.hasWritableProperty(forKey: "bounds"))
        #expect(classDescription.hasWritableProperty(forKey: "isVisible"))
        #expect(application.responds(to: openSettingsWindowSelector))
        #expect(applicationClassDescription.supportsCommand(openSettingsWindowCommand))
        #expect(applicationClassDescription.selector(forCommand: openSettingsWindowCommand) == openSettingsWindowSelector)
    }

    @MainActor
    @Test
    func editorWindowInheritsWindowClassDescriptionProperties() throws {
        let classDescription = try #require(NSScriptClassDescription(for: SwiftTagScriptEditorWindow.self))

        #expect(classDescription.superclass?.className == "window")
        #expect(classDescription.hasReadableProperty(forKey: "title"))
        #expect(classDescription.hasReadableProperty(forKey: "uniqueID"))
        #expect(classDescription.hasWritableProperty(forKey: "orderedIndex"))
        #expect(classDescription.hasWritableProperty(forKey: "bounds"))
        #expect(classDescription.type(forKey: "bounds") == "rectangle")
        #expect(classDescription.hasReadableProperty(forKey: "hasCloseBox"))
        #expect(classDescription.hasReadableProperty(forKey: "isCollapseable"))
        #expect(classDescription.hasWritableProperty(forKey: "isCollapsed"))
        #expect(classDescription.hasWritableProperty(forKey: "isFullScreen"))
        #expect(classDescription.hasWritableProperty(forKey: "position"))
        #expect(classDescription.type(forKey: "position") == "point")
        #expect(classDescription.hasReadableProperty(forKey: "isResizable"))
        #expect(classDescription.hasWritableProperty(forKey: "isVisible"))
        #expect(classDescription.hasReadableProperty(forKey: "isZoomable"))
        #expect(classDescription.hasWritableProperty(forKey: "isZoomed"))
    }

    @MainActor
    @Test
    func editorWindowWindowPropertiesForwardToLiveNSWindow() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 80, y: 90, width: 320, height: 240),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        defer {
            window.close()
        }

        window.title = "Script Window"
        let scriptWindow = SwiftTagScriptEditorWindow(sessionID: UUID(), liveWindow: window)

        #expect(scriptWindow.title == "Script Window")
        #expect(scriptWindow.name == "Script Window")
        #expect(scriptWindow.uniqueID == window.windowNumber)
        #expect(scriptWindow.hasCloseBox)
        #expect(scriptWindow.isCollapseable)
        #expect(scriptWindow.isResizable)
        #expect(scriptWindow.isZoomable)
        #expect(!scriptWindow.isCollapsed)
        #expect(!scriptWindow.isFullScreen)

        let top = window.frame.maxY + 25
        let positionRecord = NSAppleEventDescriptor.record()
        positionRecord.setDescriptor(
            NSAppleEventDescriptor(int32: 120),
            forKeyword: Self.fourCharCode("xpos").uint32Value
        )
        positionRecord.setDescriptor(
            NSAppleEventDescriptor(int32: Int32(top)),
            forKeyword: Self.fourCharCode("ypos").uint32Value
        )
        scriptWindow.setValue(positionRecord, forKey: "position")
        #expect(window.frame.minX == 120)
        #expect(window.frame.maxY == top)

        let position = try #require(scriptWindow.position as? [String: NSNumber])
        #expect(position["x"]?.doubleValue == 120)
        #expect(position["y"]?.doubleValue == Double(top))

        let boundsRecord = NSAppleEventDescriptor.record()
        boundsRecord.setDescriptor(
            NSAppleEventDescriptor(int32: 130),
            forKeyword: Self.fourCharCode("xpos").uint32Value
        )
        boundsRecord.setDescriptor(
            NSAppleEventDescriptor(int32: Int32(top)),
            forKeyword: Self.fourCharCode("ypos").uint32Value
        )
        boundsRecord.setDescriptor(
            NSAppleEventDescriptor(int32: 300),
            forKeyword: Self.fourCharCode("widt").uint32Value
        )
        boundsRecord.setDescriptor(
            NSAppleEventDescriptor(int32: 210),
            forKeyword: Self.fourCharCode("heig").uint32Value
        )
        scriptWindow.setValue(boundsRecord, forKey: "bounds")
        #expect(window.frame.minX == 130)
        #expect(window.frame.maxX == 430)
        #expect(window.frame.minY == top - 210)
        #expect(window.frame.maxY == top)

        let bounds = try #require(scriptWindow.bounds as? [String: NSNumber])
        #expect(bounds["x"]?.doubleValue == 130)
        #expect(bounds["y"]?.doubleValue == Double(top))
        #expect(bounds["width"]?.doubleValue == 300)
        #expect(bounds["height"]?.doubleValue == 210)

        scriptWindow.setValue(NSNumber(value: true), forKey: "isVisible")
        #expect(window.isVisible)
        scriptWindow.setValue(NSNumber(value: false), forKey: "isVisible")
        #expect(!window.isVisible)
    }

    @MainActor
    @Test
    func appleScriptFlacSaveRequestUsesDefaultsWhenOptionsOmitted() throws {
        let request = try SwiftTagAppleScriptFlacSaveRequest.from(arguments: nil)

        #expect(request == .defaults)
    }

    @Test
    func appleScriptAddTracksRequestUsesUnlockedDefaultWhenOptionOmitted() throws {
        let request = try SwiftTagAppleScriptAddTracksRequest.from(arguments: nil)

        #expect(request == .defaults)
        #expect(!request.locked)
    }

    @Test
    func appleScriptAddTracksRequestMapsWithLockBooleanOption() throws {
        let lockedRequest = try SwiftTagAppleScriptAddTracksRequest.from(
            arguments: [
                "WithLock": true
            ]
        )
        let unlockedRequest = try SwiftTagAppleScriptAddTracksRequest.from(
            arguments: [
                "WithLock": NSNumber(value: false)
            ]
        )

        #expect(lockedRequest.locked)
        #expect(!unlockedRequest.locked)
    }

    @Test
    func appleScriptFlacSaveRequestMapsExplicitScopeAndPayloadOptions() throws {
        let request = try SwiftTagAppleScriptFlacSaveRequest.from(
            arguments: [
                "SaveScopeOptions": Self.fourCharCode("sltr"),
                "SavePayloadOptions": Self.fourCharCode("pcos")
            ]
        )

        #expect(request.scope == .selectedTracks)
        #expect(request.payload == .writePictures)
    }

    @Test
    func appleScriptFlacSaveRequestMapsFourCharacterEnumerationCodes() throws {
        let request = try SwiftTagAppleScriptFlacSaveRequest.from(
            arguments: [
                "SaveScopeOptions": Self.fourCharCode("altr"),
                "SavePayloadOptions": Self.fourCharCode("tgos")
            ]
        )

        #expect(request.scope == .allTracks)
        #expect(request.payload == .writeTags)
    }

    @Test
    func appleScriptFlacSaveRequestRejectsInvalidEnumerationOptions() {
        #expect(throws: SwiftTagAppleScriptCommandError.invalidSaveScopeOptionValue("scope")) {
            _ = try SwiftTagAppleScriptFlacSaveRequest.from(
                arguments: [
                    "SaveScopeOptions": Self.fourCharCode("frnt")
                ]
            )
        }

        #expect(throws: SwiftTagAppleScriptCommandError.invalidSavePayloadOptionValue("payload")) {
            _ = try SwiftTagAppleScriptFlacSaveRequest.from(
                arguments: [
                    "SavePayloadOptions": Self.fourCharCode("lyrc")
                ]
            )
        }
    }

    @MainActor
    @Test
    func applicationSettingsExposeUserDefaultsThroughAppleScriptKeys() throws {
        let application = NSApplication.shared
        let defaults = UserDefaults.standard
        let settingKeys = [
            SaveSettingsKey.defaultSaveScope,
            SaveSettingsKey.defaultSavePayload,
            SaveSettingsKey.saveReferencedSwiftTagDocument,
            SaveSettingsKey.askToSaveNewSwiftTagDocument,
            SaveSettingsKey.zeroPadTrackNumber,
            SaveSettingsKey.zeroPadDiscNumber,
            SaveSettingsKey.trackCountKeyStrategy,
            SaveSettingsKey.discCountKeyStrategy,
            SaveSettingsKey.autoUpdateTrackTotal,
            SaveSettingsKey.applyCompilationToAllTracks,
            SaveSettingsKey.saveFrontCoverToAllTracks,
            SaveSettingsKey.saveAllPicturesToAllTracks,
            FeedbackSettingsKey.saveNotificationMode,
            FeedbackSettingsKey.themePreference,
            FeedbackSettingsKey.trackToTrackDiffColor,
            FeedbackSettingsKey.formatOnTrackToFileDiff,
            FeedbackSettingsKey.formatOnTrackToTrackDiff,
            FeedbackSettingsKey.formatOnExternallyModifiedDiff,
            FeedbackSettingsKey.formatOnTrackTotalMismatch,
            FeedbackSettingsKey.formatOnDiscTotalMismatch,
            FeedbackSettingsKey.formatOnDuplicatePicture
        ]
        let previousValues = settingKeys.map { key in
            (key: key, value: defaults.object(forKey: key))
        }
        defer {
            for previousValue in previousValues {
                if let value = previousValue.value {
                    defaults.set(value, forKey: previousValue.key)
                } else {
                    defaults.removeObject(forKey: previousValue.key)
                }
            }
        }

        for key in settingKeys {
            defaults.removeObject(forKey: key)
        }

        application.setValue(Self.fourCharCode("sltr"), forKey: "SaveScopeOptionsSetting")
        application.setValue(Self.fourCharCode("pcos"), forKey: "SavePayloadOptionsSetting")
        application.setValue(Self.fourCharCode("ttot"), forKey: "TrackTotalKeySetting")
        application.setValue(Self.fourCharCode("dtot"), forKey: "DiscTotalKeySetting")
        application.setValue(Self.fourCharCode("sndv"), forKey: "SendSaveNotificationsSetting")
        application.setValue(Self.fourCharCode("dark"), forKey: "ThemeSetting")

        let boolSettings: [(cocoaKey: String, defaultsKey: String, value: Bool)] = [
            ("SaveReferencedDocumentSetting", SaveSettingsKey.saveReferencedSwiftTagDocument, true),
            ("AskToSaveNewDocumentSetting", SaveSettingsKey.askToSaveNewSwiftTagDocument, true),
            ("ZeroPadTrackNumbersSetting", SaveSettingsKey.zeroPadTrackNumber, false),
            ("ZeroPadDiscNumbersSetting", SaveSettingsKey.zeroPadDiscNumber, false),
            ("AutoUpdateTrackTotalSetting", SaveSettingsKey.autoUpdateTrackTotal, true),
            ("ApplyCompilationToAllTracksSetting", SaveSettingsKey.applyCompilationToAllTracks, true),
            ("SaveFrontCoverToAllTracksSetting", SaveSettingsKey.saveFrontCoverToAllTracks, true),
            ("SaveAllPicturesToAllTracksSetting", SaveSettingsKey.saveAllPicturesToAllTracks, true),
            ("FormatOnTrackToFileDiffSetting", FeedbackSettingsKey.formatOnTrackToFileDiff, false),
            ("FormatOnTrackToTrackDiffSetting", FeedbackSettingsKey.formatOnTrackToTrackDiff, false),
            ("FormatOnExternallyModifiedDiffSetting", FeedbackSettingsKey.formatOnExternallyModifiedDiff, false),
            ("FormatOnTrackTotalMismatchSetting", FeedbackSettingsKey.formatOnTrackTotalMismatch, false),
            ("FormatOnDiscTotalMismatchSetting", FeedbackSettingsKey.formatOnDiscTotalMismatch, false),
            ("FormatOnDuplicatePictureSetting", FeedbackSettingsKey.formatOnDuplicatePicture, false)
        ]
        for setting in boolSettings {
            application.setValue(NSNumber(value: setting.value), forKey: setting.cocoaKey)
        }

        let colorRecord = NSAppleEventDescriptor.record()
        colorRecord.setDescriptor(
            NSAppleEventDescriptor(double: 0.25),
            forKeyword: Self.fourCharCode("redc").uint32Value
        )
        colorRecord.setDescriptor(
            NSAppleEventDescriptor(double: 0.5),
            forKeyword: Self.fourCharCode("grec").uint32Value
        )
        colorRecord.setDescriptor(
            NSAppleEventDescriptor(double: 0.75),
            forKeyword: Self.fourCharCode("bluc").uint32Value
        )
        colorRecord.setDescriptor(
            NSAppleEventDescriptor(double: 0.8),
            forKeyword: Self.fourCharCode("alph").uint32Value
        )
        application.setValue(colorRecord, forKey: "TrackToTrackDiffColorSetting")

        #expect(defaults.string(forKey: SaveSettingsKey.defaultSaveScope) == SaveScopeOption.selectedTracks.rawValue)
        #expect(defaults.string(forKey: SaveSettingsKey.defaultSavePayload) == SavePayloadOption.writePictures.rawValue)
        #expect(defaults.string(forKey: SaveSettingsKey.trackCountKeyStrategy) == TrackCountKeyStrategy.trackTotal.rawValue)
        #expect(defaults.string(forKey: SaveSettingsKey.discCountKeyStrategy) == DiscCountKeyStrategy.discTotal.rawValue)
        #expect(defaults.string(forKey: FeedbackSettingsKey.saveNotificationMode) == SaveNotificationMode.never.rawValue)
        #expect(defaults.string(forKey: FeedbackSettingsKey.themePreference) == AppThemePreference.dark.rawValue)

        for setting in boolSettings {
            #expect(defaults.bool(forKey: setting.defaultsKey) == setting.value)
            let value = try #require(application.value(forKey: setting.cocoaKey) as? NSNumber)
            #expect(value.boolValue == setting.value)
        }

        try Self.expectAppleScriptCode(application, key: "SaveScopeOptionsSetting", code: "sltr")
        try Self.expectAppleScriptCode(application, key: "SavePayloadOptionsSetting", code: "pcos")
        try Self.expectAppleScriptCode(application, key: "TrackTotalKeySetting", code: "ttot")
        try Self.expectAppleScriptCode(application, key: "DiscTotalKeySetting", code: "dtot")
        try Self.expectAppleScriptCode(application, key: "SendSaveNotificationsSetting", code: "sndv")
        try Self.expectAppleScriptCode(application, key: "ThemeSetting", code: "dark")

        let savedColor = try #require(
            application.value(forKey: "TrackToTrackDiffColorSetting") as? NSDictionary
        )
        try Self.expectColorRecord(savedColor, red: 0.25, green: 0.5, blue: 0.75, alpha: 0.8)
    }

    @MainActor
    @Test
    func appleScriptCloseRequestMapsSavingDestinationScopeAndPayloadOptions() throws {
        let destinationURL = URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-close.swifttag")
        let request = try SwiftTagAppleScriptCloseRequest.from(
            arguments: [
                "SaveOptions": Self.fourCharCode("yes "),
                "File": destinationURL,
                "SaveScopeOptions": Self.fourCharCode("sltr"),
                "SavePayloadOptions": Self.fourCharCode("tgos")
            ]
        )

        #expect(request.saveOption == .yes)
        #expect(request.destinationURL == destinationURL.standardizedFileURL)
        #expect(request.flacSaveRequest.scope == .selectedTracks)
        #expect(request.flacSaveRequest.payload == .writeTags)
    }

    @MainActor
    @Test
    func savingScriptEditorWindowRoutesFlacSaveRequestThroughBridge() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let savedReference = ImportedTrackReference(
            filePath: "/tmp/SwiftTagAppleScriptTests-save.flac",
            securityScopedBookmarkData: nil
        )
        let expectedResult = SaveOperationResult(
            sourceSessionID: sessionID,
            payload: .writePictures,
            trackReferences: [savedReference],
            fingerprint: TrackSetFingerprint.make(from: [savedReference])
        )
        let expectedRequest = SwiftTagAppleScriptFlacSaveRequest(
            payload: .writePictures,
            scope: .selectedTracks
        )
        var capturedRequest: SwiftTagAppleScriptFlacSaveRequest?

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(tracks: [], selectedTrackIDs: [])
                },
                addTracks: { _ in
                    []
                },
                selectTracks: { _ in
                },
                saveDocument: { _ in
                    .init()
                },
                saveTracks: { request in
                    capturedRequest = request
                    return expectedResult
                }
            )
        )

        let scriptWindow = SwiftTagScriptEditorWindow(sessionID: sessionID)
        let saveResult = try scriptWindow.saveFlacFiles(using: expectedRequest)

        #expect(capturedRequest == expectedRequest)
        #expect(saveResult == expectedResult)
    }

    @MainActor
    @Test
    func closingScriptEditorWindowSavingYesRoutesFlacSaveAndCloses() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let expectedRequest = SwiftTagAppleScriptFlacSaveRequest(
            payload: .writeTags,
            scope: .selectedTracks
        )
        var capturedRequest: SwiftTagAppleScriptFlacSaveRequest?
        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Unsaved",
                        modified: true,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(tracks: [], selectedTrackIDs: [])
                },
                addTracks: { _ in [] },
                selectTracks: { _ in },
                saveDocument: { _ in .init() },
                saveTracks: { request in
                    capturedRequest = request
                    return SaveOperationResult(
                        sourceSessionID: sessionID,
                        payload: request.payload ?? .writeTagsAndPictures,
                        trackReferences: [],
                        fingerprint: ""
                    )
                }
            )
        )

        let scriptWindow = try #require(
            SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionID)
        )

        try scriptWindow.close(
            using: SwiftTagAppleScriptCloseRequest(
                saveOption: .yes,
                destinationURL: nil,
                flacSaveRequest: expectedRequest
            )
        )

        #expect(capturedRequest == expectedRequest)
        #expect(SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionID) == nil)
    }

    @MainActor
    @Test
    func closingScriptDocumentSavingYesRoutesDocumentSaveAndCloses() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let destinationURL = try Self.tempPackageURL(name: "applescript-close-save")
        var capturedDestinationURL: URL?
        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Unsaved",
                        modified: true,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(tracks: [], selectedTrackIDs: [])
                },
                addTracks: { _ in [] },
                selectTracks: { _ in },
                saveDocument: { destinationURL in
                    capturedDestinationURL = destinationURL
                    return SwiftTagDocumentSaveState(
                        destinationURL: destinationURL,
                        lastKnownDisplayName: destinationURL?.lastPathComponent
                    )
                }
            )
        )

        let scriptDocument = SwiftTagAppleScriptController.shared.document(forSessionID: sessionID)

        try scriptDocument.close(
            using: SwiftTagAppleScriptCloseRequest(
                saveOption: .yes,
                destinationURL: destinationURL,
                flacSaveRequest: .defaults
            )
        )

        #expect(capturedDestinationURL == destinationURL.standardizedFileURL)
        #expect(SwiftTagAppleScriptController.shared.document(withUniqueID: sessionID.uuidString) == nil)
    }

    @MainActor
    @Test
    func editorWindowTracksSupportSelectionAndTypedTrackProperties() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let trackURL = URL(fileURLWithPath: "/tmp/01-SwiftTagAppleScriptTests-track.flac")
        let secondTrackURL = URL(fileURLWithPath: "/tmp/02-SwiftTagAppleScriptTests-track.flac")
        let pictureData = try #require(Self.singlePixelPNGData())
        let picture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Cover (front)",
            data: pictureData
        ).withComputedPictureMetadata()
        let totalSamples: UInt64 = 14_175_315
        let track = Track(
            album: "The Planets",
            albumArtist: "London Symphony Orchestra",
            totalTracks: "7",
            tags: [
                TagKey.album: "The Planets",
                TagKey.albumArtist: "London Symphony Orchestra",
                TagKey.artist: "Gustav Holst",
                "COMMENT": "Live broadcast",
                TagKey.compilation: "1",
                TagKey.date: "2024-03-14",
                "DISCTOTAL": "2",
                "DISC": "1",
                "RATING": "5",
                TagKey.title: "Mars, the Bringer of War",
                "TRACK": "3"
            ],
            flacPictureRecords: [picture],
            sourceFileURL: trackURL,
            fingerprint: "3b2f1b8459d0f6c1860c07f03b6f0db4",
            duration: 321.5,
            sampleRate: 44_100,
            totalSamples: totalSamples,
            bitsPerSample: 24,
            channels: 2
        )
        let secondTrack = Track(
            tags: [TagKey.title: "Venus, the Bringer of Peace"],
            sourceFileURL: secondTrackURL
        )
        let expectedFingerprint = try SwiftTagDocumentPackageWriter.trackTagsAndPicturesFingerprint(
            tags: track.tags,
            pictures: track.flacPictureRecords
        )

        var sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
            tracks: [track, secondTrack],
            selectedTrackIDs: []
        )
        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    sessionSnapshot
                },
                addTracks: { _ in
                    []
                },
                selectTracks: { trackIDs in
                    sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
                        tracks: sessionSnapshot.tracks,
                        selectedTrackIDs: trackIDs
                    )
                },
                saveDocument: { _ in
                    .init()
                }
            )
        )

        let scriptWindow = SwiftTagScriptEditorWindow(sessionID: sessionID)
        #expect(scriptWindow.countOfTracks == 2)
        let scriptTrack = try #require(scriptWindow.tracks.first)

        #expect(scriptTrack.album == "The Planets")
        #expect(scriptTrack.albumArtist == "London Symphony Orchestra")
        #expect(scriptTrack.artist == "Gustav Holst")
        #expect(scriptTrack.bitsPerSample?.intValue == 24)
        #expect(scriptTrack.channels?.intValue == 2)
        #expect(scriptTrack.comment == "Live broadcast")
        #expect(scriptTrack.compilation?.boolValue == true)
        #expect(scriptTrack.discCount?.intValue == 2)
        #expect(scriptTrack.discNumber?.intValue == 1)
        #expect(scriptTrack.duration?.doubleValue == 321.5)
        #expect(scriptTrack.fileURL == trackURL.standardizedFileURL)
        #expect(scriptTrack.fingerprint == expectedFingerprint)
        #expect(scriptTrack.flacFingerprint == "3b2f1b8459d0f6c1860c07f03b6f0db4")
        #expect(scriptTrack.rating?.intValue == 5)
        #expect(scriptTrack.sampleRate == "44.1 kHz")
        #expect(scriptTrack.title == "Mars, the Bringer of War")
        #expect(scriptTrack.totalSamples?.doubleValue == Double(totalSamples))
        #expect(scriptTrack.trackCount?.intValue == 7)
        #expect(scriptTrack.trackNumber?.intValue == 3)
        #expect(scriptTrack.countOfPictures == 1)

        let scriptPicture = try #require(scriptTrack.pictures.first)
        #expect(scriptPicture.pictureType?.uint32Value == Self.fourCharCode("frcv").uint32Value)
        #expect(scriptPicture.mimeType == "image/png")
        #expect(scriptPicture.pictureDescription == "Cover (front)")
        #expect(scriptPicture.width?.intValue == picture.width)
        #expect(scriptPicture.height?.intValue == picture.height)
        #expect(scriptPicture.colorDepth?.intValue == picture.depth)
        #expect(scriptPicture.colors?.intValue == picture.colors)
        let scriptPictureData = try #require(scriptPicture.data)
        #expect(scriptPictureData as Data == pictureData)

        let frontCoverSpecifier = try Self.whosePictureSpecifier(
            in: scriptTrack,
            propertyKey: "pictureType",
            value: Self.fourCharCode("frcv")
        )
        let frontCovers = Self.evaluatedPictureWrappers(from: frontCoverSpecifier)
        #expect(frontCovers.count == 1)
        #expect(frontCovers.first?.pictureDescription == "Cover (front)")

        let calendar = Calendar(identifier: .gregorian)
        let releaseDate = try #require(scriptTrack.releaseDate)
        #expect(calendar.component(.year, from: releaseDate) == 2024)
        #expect(calendar.component(.month, from: releaseDate) == 3)
        #expect(calendar.component(.day, from: releaseDate) == 14)

        scriptWindow.setValue(scriptTrack, forKey: "selectedTracks")
        #expect(sessionSnapshot.selectedTrackIDs == Set([track.id]))
        #expect(scriptWindow.selectedTracks.map(\.fileURL) == [trackURL.standardizedFileURL])

        let matchingTracks = NSApplication.shared.scriptTracks.filter { $0.title == "Mars, the Bringer of War" }
        scriptWindow.setValue(matchingTracks, forKey: "selectedTracks")
        #expect(sessionSnapshot.selectedTrackIDs == Set([track.id]))

        scriptWindow.setValue(scriptWindow.tracks, forKey: "selectedTracks")
        #expect(sessionSnapshot.selectedTrackIDs == Set([track.id, secondTrack.id]))
        #expect(scriptWindow.selectedTracks.map(\.fileURL) == [
            trackURL.standardizedFileURL,
            secondTrackURL.standardizedFileURL
        ])
        #expect(scriptWindow.selectedTracks.compactMap(\.title) == [
            "Mars, the Bringer of War",
            "Venus, the Bringer of Peace"
        ])
    }

    @MainActor
    @Test
    func trackPropertySettersRouteThroughTagBridge() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let track = Track(
            tags: [TagKey.title: "Original Title"],
            sourceFileURL: URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-title.flac")
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: viewModel.trackItems,
                        selectedTrackIDs: viewModel.selectedTrackIDs
                    )
                },
                addTracks: { _ in [] },
                selectTracks: { trackIDs in
                    viewModel.selectedTrackIDs = trackIDs
                },
                saveDocument: { _ in .init() },
                upsertTag: { trackID, key, value in
                    try viewModel.appleScriptUpsertTag(key: key, value: value, forTrackID: trackID)
                },
                deleteTag: { trackID, key in
                    try viewModel.appleScriptDeleteTag(key: key, forTrackID: trackID)
                }
            )
        )

        let scriptWindow = try #require(
            SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionID)
        )
        let scriptTrack = try #require(scriptWindow.tracks.first)

        scriptTrack.setValue("New Title", forKey: "title")

        #expect(viewModel.trackItems.first?.tags[TagKey.title] == "New Title")
        #expect(scriptTrack.title == "New Title")
    }

    @MainActor
    @Test
    func tagWhoseKeyReturnsMissingValueForExistingEmptyTag() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let track = Track(
            album: "",
            tags: [
                TagKey.album: "",
                TagKey.title: "Empty Album"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-empty-album.flac")
        )

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: [track],
                        selectedTrackIDs: []
                    )
                },
                addTracks: { _ in [] },
                selectTracks: { _ in },
                saveDocument: { _ in .init() }
            )
        )

        let scriptWindow = try #require(
            SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionID)
        )
        let scriptTrack = try #require(scriptWindow.tracks.first)
        let albumTagSpecifier = try Self.whoseTagSpecifier(
            in: scriptTrack,
            propertyKey: "key",
            value: TagKey.album
        )
        let albumTags = Self.evaluatedTagWrappers(from: albumTagSpecifier)

        #expect(scriptTrack.album == nil)
        #expect(albumTags.count == 1)
        let albumTag = try #require(albumTags.first)
        #expect(albumTag.key == TagKey.album)
        #expect(albumTag.value == nil)
        let uniqueAlbumTag = try #require(
            scriptTrack.valueInTags(withUniqueID: TagKey.album) as? SwiftTagScriptTag
        )
        #expect(uniqueAlbumTag.value == nil)
    }

    @MainActor
    @Test
    func albumInitializerBacksConvenienceValueWithTag() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let track = Track(
            album: "Convenience Album",
            tags: [TagKey.title: "No Album Tag"],
            sourceFileURL: URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-no-album-tag.flac")
        )

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: [track],
                        selectedTrackIDs: []
                    )
                },
                addTracks: { _ in [] },
                selectTracks: { _ in },
                saveDocument: { _ in .init() }
            )
        )

        let scriptWindow = try #require(
            SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionID)
        )
        let scriptTrack = try #require(scriptWindow.tracks.first)
        let albumTagSpecifier = try Self.whoseTagSpecifier(
            in: scriptTrack,
            propertyKey: "key",
            value: TagKey.album
        )

        #expect(scriptTrack.album == "Convenience Album")
        let albumTag = try #require(scriptTrack.valueInTags(withUniqueID: TagKey.album) as? SwiftTagScriptTag)
        #expect(albumTag.value == "Convenience Album")
        #expect(Self.evaluatedTagWrappers(from: albumTagSpecifier).count == 1)
    }

    @MainActor
    @Test
    func clearingAlbumThroughSelectedBindingClearsAppleScriptAlbum() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let viewModel = TagEditorViewModel()
        let track = Track(
            album: "Original Album",
            tags: [
                TagKey.album: "Original Album",
                TagKey.title: "Album Clear"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-clear-album.flac"),
            latestFileSnapshot: TrackFileSnapshot(
                tags: [
                    TagKey.album: "Original Album",
                    TagKey.title: "Album Clear"
                ],
                picturesByType: [:]
            )
        )
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: viewModel.trackItems,
                        selectedTrackIDs: viewModel.selectedTrackIDs
                    )
                },
                addTracks: { _ in [] },
                selectTracks: { trackIDs in
                    viewModel.selectedTrackIDs = trackIDs
                },
                saveDocument: { _ in .init() },
                upsertTag: { trackID, key, value in
                    try viewModel.appleScriptUpsertTag(key: key, value: value, forTrackID: trackID)
                },
                deleteTag: { trackID, key in
                    try viewModel.appleScriptDeleteTag(key: key, forTrackID: trackID)
                }
            )
        )

        let albumBinding = try #require(viewModel.selectedAlbumBinding())
        albumBinding.wrappedValue = ""
        let scriptWindow = try #require(
            SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionID)
        )
        let scriptTrack = try #require(scriptWindow.tracks.first)

        #expect(viewModel.trackItems.first?.album == "")
        #expect(viewModel.trackItems.first?.tags[TagKey.album] == "")
        #expect(scriptTrack.album == nil)
    }

    @MainActor
    @Test
    func pictureDescriptionSetterRoutesThroughBridge() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let pictureData = try #require(Self.singlePixelPNGData())
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: [TagKey.title: "Picture Track"],
                flacPictureRecords: [
                    FlacWritablePictureRecord(
                        type: 3,
                        mimeType: "image/png",
                        description: "Original",
                        data: pictureData
                    ).withComputedPictureMetadata()
                ],
                sourceFileURL: URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-picture.flac")
            )
        ]

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: viewModel.trackItems,
                        selectedTrackIDs: viewModel.selectedTrackIDs
                    )
                },
                addTracks: { _ in [] },
                selectTracks: { trackIDs in
                    viewModel.selectedTrackIDs = trackIDs
                },
                saveDocument: { _ in .init() },
                updatePictureDescription: { trackID, pictureIndex, description in
                    try viewModel.appleScriptUpdatePictureDescription(
                        description,
                        forTrackID: trackID,
                        pictureIndex: pictureIndex
                    )
                }
            )
        )

        let scriptWindow = try #require(
            SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionID)
        )
        let scriptPicture = try #require(scriptWindow.tracks.first?.pictures.first)

        scriptPicture.pictureDescription = "Edited"

        #expect(viewModel.trackItems.first?.flacPictureRecords.first?.description == "Edited")
        #expect(scriptPicture.pictureDescription == "Edited")
    }

    @MainActor
    @Test
    func pictureDeletionRoutesThroughBridgeForSingleAndWhoseMatches() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let originalFrontData = try #require(Self.singlePixelPNGData())
        let deleteData = try Self.pngData(color: .systemGreen)
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: [TagKey.title: "Picture Delete Track"],
                flacPictureRecords: [
                    FlacWritablePictureRecord(
                        type: 3,
                        mimeType: "image/png",
                        description: "Original Front",
                        data: originalFrontData
                    ).withComputedPictureMetadata(),
                    FlacWritablePictureRecord(
                        type: 3,
                        mimeType: "image/png",
                        description: "delete me",
                        data: deleteData
                    ).withComputedPictureMetadata(),
                    FlacWritablePictureRecord(
                        type: 4,
                        mimeType: "image/png",
                        description: "delete me",
                        data: deleteData
                    ).withComputedPictureMetadata()
                ],
                sourceFileURL: URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-delete-picture.flac")
            )
        ]

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: viewModel.trackItems,
                        selectedTrackIDs: viewModel.selectedTrackIDs
                    )
                },
                addTracks: { _ in [] },
                selectTracks: { trackIDs in
                    viewModel.selectedTrackIDs = trackIDs
                },
                saveDocument: { _ in .init() },
                deletePicture: { trackID, pictureIndex in
                    try viewModel.appleScriptDeletePicture(
                        forTrackID: trackID,
                        pictureIndex: pictureIndex
                    )
                }
            )
        )

        let scriptWindow = try #require(
            SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionID)
        )
        let scriptTrack = try #require(scriptWindow.tracks.first)
        let frontCoverSpecifier = try Self.whosePictureSpecifier(
            in: scriptTrack,
            propertyKey: "pictureType",
            value: Self.fourCharCode("frcv")
        )
        let frontCovers = Self.evaluatedPictureWrappers(from: frontCoverSpecifier)
        #expect(frontCovers.count == 2)

        try frontCovers[0].delete()

        #expect(viewModel.trackItems.first?.flacPictureRecords.map(\.description) == [
            "delete me",
            "delete me"
        ])

        let deleteMeSpecifier = try Self.whosePictureSpecifier(
            in: scriptTrack,
            propertyKey: "pictureDescription",
            value: "delete me"
        )
        let deleteMePictures = Self.evaluatedPictureWrappers(from: deleteMeSpecifier)
        #expect(deleteMePictures.count == 2)

        try SwiftTagScriptPicture.delete(deleteMePictures)

        #expect(viewModel.trackItems.first?.flacPictureRecords.isEmpty == true)
        #expect(scriptTrack.countOfPictures == 0)
    }

    @MainActor
    @Test
    func pictureImportPayloadAcceptsBase64TextData() throws {
        let pictureData = try #require(Self.singlePixelPNGData())
        let payload = try SwiftTagAppleScriptPicturePayload.fromImportPictureCommand(
            data: pictureData.base64EncodedString(),
            arguments: ["Description": "Base64 Picture"]
        )

        #expect(payload.data == pictureData)
        #expect(payload.type == 3)
        #expect(payload.description == "Base64 Picture")
        #expect(payload.mimeType == "image/png")
    }

    @MainActor
    @Test
    func pictureImportPayloadDefaultsToFrontCoverDedupesAndAppends() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let firstPictureData = try #require(Self.singlePixelPNGData())
        let secondPictureData = try Self.pngData(color: .systemGreen)
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: [TagKey.title: "Picture Track"],
                flacPictureRecords: [
                    FlacWritablePictureRecord(
                        type: 3,
                        mimeType: "image/png",
                        description: "Original",
                        data: firstPictureData
                    ).withComputedPictureMetadata()
                ],
                sourceFileURL: URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-import-picture.flac")
            )
        ]

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: viewModel.trackItems,
                        selectedTrackIDs: viewModel.selectedTrackIDs
                    )
                },
                addTracks: { _ in [] },
                selectTracks: { trackIDs in
                    viewModel.selectedTrackIDs = trackIDs
                },
                saveDocument: { _ in .init() },
                upsertPicture: { trackID, payload in
                    try viewModel.appleScriptUpsertPicture(payload, forTrackID: trackID)
                },
                replacePicture: { trackID, pictureIndex, payload in
                    try viewModel.appleScriptReplacePicture(
                        payload,
                        replacingPictureAt: pictureIndex,
                        forTrackID: trackID
                    )
                },
                updatePictureDescription: { trackID, pictureIndex, description in
                    try viewModel.appleScriptUpdatePictureDescription(
                        description,
                        forTrackID: trackID,
                        pictureIndex: pictureIndex
                    )
                }
            )
        )

        let scriptWindow = try #require(
            SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionID)
        )
        let scriptTrack = try #require(scriptWindow.tracks.first)
        let trackID = try #require(viewModel.trackItems.first?.id)
        let firstPicture = try #require(scriptTrack.pictures.first)
        let firstPictureDataFromScript = try #require(firstPicture.data)

        let duplicateWithoutDescriptionPayload = try SwiftTagAppleScriptPicturePayload.fromImportPictureCommand(
            data: firstPictureDataFromScript,
            arguments: [:]
        )
        let duplicateWithoutDescriptionIndex = try SwiftTagAppleScriptController.shared.upsertPicture(
            duplicateWithoutDescriptionPayload,
            forSessionID: sessionID,
            trackID: trackID
        )
        let duplicatePictures = scriptTrack.pictures
        let duplicateWithoutDescription = try #require(
            duplicatePictures.indices.contains(duplicateWithoutDescriptionIndex)
                ? duplicatePictures[duplicateWithoutDescriptionIndex]
                : nil
        )

        #expect(scriptTrack.countOfPictures == 1)
        #expect(viewModel.trackItems.first?.flacPictureRecords.first?.description == "Original")
        #expect(duplicateWithoutDescription.pictureType?.uint32Value == Self.fourCharCode("frcv").uint32Value)
        #expect(duplicateWithoutDescription.pictureDescription == "Original")
        #expect(duplicateWithoutDescription.objectSpecifier != nil)

        let duplicateWithDescriptionPayload = try SwiftTagAppleScriptPicturePayload.fromImportPictureCommand(
            data: firstPictureDataFromScript,
            arguments: ["Description": "Edited from import picture"]
        )
        let duplicateWithDescriptionIndex = try SwiftTagAppleScriptController.shared.upsertPicture(
            duplicateWithDescriptionPayload,
            forSessionID: sessionID,
            trackID: trackID
        )
        let editedDuplicatePictures = scriptTrack.pictures
        let duplicateWithDescription = try #require(
            editedDuplicatePictures.indices.contains(duplicateWithDescriptionIndex)
                ? editedDuplicatePictures[duplicateWithDescriptionIndex]
                : nil
        )

        #expect(scriptTrack.countOfPictures == 1)
        #expect(viewModel.trackItems.first?.flacPictureRecords.first?.description == "Edited from import picture")
        #expect(duplicateWithDescription.pictureDescription == "Edited from import picture")

        let appendedPayload = try SwiftTagAppleScriptPicturePayload.fromImportPictureCommand(
            data: secondPictureData as NSData,
            arguments: [
                "MimeType": "image/jpeg",
                "Description": "Second front"
            ]
        )
        let appendedIndex = try SwiftTagAppleScriptController.shared.upsertPicture(
            appendedPayload,
            forSessionID: sessionID,
            trackID: trackID
        )
        let appendedPictures = scriptTrack.pictures
        let appendedPicture = try #require(
            appendedPictures.indices.contains(appendedIndex)
                ? appendedPictures[appendedIndex]
                : nil
        )

        #expect(scriptTrack.countOfPictures == 2)
        #expect(viewModel.trackItems.first?.flacPictureRecords.map(\.description) == [
            "Edited from import picture",
            "Second front"
        ])
        #expect(viewModel.trackItems.first?.flacPictureRecords.last?.mimeType == "image/png")
        #expect(appendedPicture.pictureType?.uint32Value == Self.fourCharCode("frcv").uint32Value)
        #expect(appendedPicture.mimeType == "image/png")
        #expect(appendedPicture.pictureDescription == "Second front")
    }

    @MainActor
    @Test
    func scriptClassDescriptionsSupportPictureMakeDataPath() throws {
        let track = SwiftTagScriptTrack(sessionID: UUID(), trackID: UUID())
        let makeSelector = NSSelectorFromString("handleMakeScriptCommand:")

        #expect(track.responds(to: makeSelector))

        let commandDescription = try #require(
            NSScriptSuiteRegistry.shared().commandDescription(
                withAppleEventClass: Self.fourCharCode("core").uint32Value,
                andAppleEventCode: Self.fourCharCode("crel").uint32Value
            )
        )
        let classDescription = try #require(NSScriptClassDescription(for: SwiftTagScriptTrack.self))
        let pictureClassDescription = try #require(NSScriptClassDescription(for: SwiftTagScriptPicture.self))

        #expect(classDescription.supportsCommand(commandDescription))
        #expect(classDescription.selector(forCommand: commandDescription) == makeSelector)
        #expect(pictureClassDescription.hasWritableProperty(forKey: "data"))
        #expect(track.responds(to: NSSelectorFromString("removeObjectFromPicturesAtIndex:")))
    }

    @MainActor
    @Test
    func selectedTracksSetterKeepsEveryWhoseMatchWithDuplicateTitles() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let firstTrack = Track(
            tags: [TagKey.title: "Test Title"],
            sourceFileURL: URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-duplicate-1.flac")
        )
        let secondTrack = Track(
            tags: [TagKey.title: "Test Title"],
            sourceFileURL: URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-duplicate-2.flac")
        )
        let otherTrack = Track(
            tags: [TagKey.title: "Other Title"],
            sourceFileURL: URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-other.flac")
        )

        var sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
            tracks: [firstTrack, secondTrack, otherTrack],
            selectedTrackIDs: []
        )
        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    sessionSnapshot
                },
                addTracks: { _ in
                    []
                },
                selectTracks: { trackIDs in
                    sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
                        tracks: sessionSnapshot.tracks,
                        selectedTrackIDs: trackIDs
                    )
                },
                saveDocument: { _ in
                    .init()
                }
            )
        )

        let scriptWindow = try #require(
            SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionID)
        )
        let matchingTracksSpecifier = try Self.whoseTrackSpecifier(
            in: scriptWindow,
            propertyKey: "title",
            value: "Test Title"
        )

        let matchingTracks = Self.evaluatedTrackWrappers(from: matchingTracksSpecifier)
        #expect(matchingTracks.count == 2)

        scriptWindow.setValue(matchingTracksSpecifier, forKey: "selectedTracks")

        #expect(sessionSnapshot.selectedTrackIDs == Set([firstTrack.id, secondTrack.id]))
        #expect(scriptWindow.countOfSelectedTracks == 2)
        #expect(scriptWindow.selectedTracks.compactMap(\.title) == ["Test Title", "Test Title"])
    }

    @MainActor
    @Test
    func trackFileWhoseSpecifiersMatchFileDescriptorsAndPaths() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let firstTrackURL = URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-file-1.flac")
        let secondTrackURL = URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-file-2.flac")
        let firstTrack = Track(
            tags: [TagKey.title: "First File"],
            sourceFileURL: firstTrackURL
        )
        let secondTrack = Track(
            tags: [TagKey.title: "Second File"],
            sourceFileURL: secondTrackURL
        )

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: [firstTrack, secondTrack],
                        selectedTrackIDs: []
                    )
                },
                addTracks: { _ in [] },
                selectTracks: { _ in },
                saveDocument: { _ in .init() }
            )
        )

        let scriptWindow = try #require(
            SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionID)
        )
        let scriptTrack = try #require(scriptWindow.tracks.first)
        #expect(scriptTrack.fileURL == firstTrackURL.standardizedFileURL)

        let scriptFileURL = try #require(scriptTrack.value(forKey: "fileURL") as? SwiftTagScriptFileURL)
        #expect(scriptFileURL.scriptingFileDescriptor?.fileURLValue as URL? == firstTrackURL.standardizedFileURL)

        let descriptorMatches = Self.evaluatedTrackWrappers(
            from: try Self.whoseTrackSpecifier(
                in: scriptWindow,
                propertyKey: "fileURL",
                value: NSAppleEventDescriptor(fileURL: firstTrackURL)
            )
        )
        #expect(descriptorMatches.map(\.fileURL) == [firstTrackURL.standardizedFileURL])

        let pathMatches = Self.evaluatedTrackWrappers(
            from: try Self.whoseTrackSpecifier(
                in: scriptWindow,
                propertyKey: "fileURL",
                value: firstTrackURL.path
            )
        )
        #expect(pathMatches.map(\.fileURL) == [firstTrackURL.standardizedFileURL])
    }

    @MainActor
    @Test
    func editorWindowTracksFollowVisibleTableOrderForIndexSpecifiers() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let numberedTrack = Track(
            tags: [
                TagKey.title: "Numbered First",
                TagKey.trackNumber: "1"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/03-numbered-first.flac")
        )
        let filenameFirstTrack = Track(
            tags: [TagKey.title: "Filename First"],
            sourceFileURL: URL(fileURLWithPath: "/tmp/01-filename-first.flac")
        )
        let filenameSecondTrack = Track(
            tags: [TagKey.title: "Filename Second"],
            sourceFileURL: URL(fileURLWithPath: "/tmp/02-filename-second.flac")
        )

        var sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
            tracks: [filenameSecondTrack, filenameFirstTrack, numberedTrack],
            selectedTrackIDs: []
        )
        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    sessionSnapshot
                },
                addTracks: { _ in
                    []
                },
                selectTracks: { trackIDs in
                    sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
                        tracks: sessionSnapshot.tracks,
                        selectedTrackIDs: trackIDs
                    )
                },
                saveDocument: { _ in
                    .init()
                }
            )
        )

        let scriptWindow = SwiftTagScriptEditorWindow(sessionID: sessionID)

        #expect(scriptWindow.tracks.compactMap(\.title) == [
            "Numbered First",
            "Filename First",
            "Filename Second"
        ])
        #expect(
            SwiftTagAppleScriptController.shared.indexOfTrack(
                trackID: numberedTrack.id,
                forSessionID: sessionID
            ) == 0
        )

        scriptWindow.setValue(scriptWindow.objectInTracks(at: 0), forKey: "selectedTracks")

        #expect(sessionSnapshot.selectedTrackIDs == Set([numberedTrack.id]))
        #expect(scriptWindow.selectedTracks.compactMap(\.title) == ["Numbered First"])
    }

    @MainActor
    @Test
    func trackTagsSupportCanonicalLookupUpsertRenamingAndDeletion() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let trackURL = URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-tag-track.flac")
        let viewModel = TagEditorViewModel()

        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: viewModel.trackItems,
                        selectedTrackIDs: viewModel.selectedTrackIDs
                    )
                },
                addTracks: { urls in
                    #expect(urls == [trackURL.standardizedFileURL])

                    let addedTrack = Track(
                        album: "The Planets",
                        albumArtist: "London Symphony Orchestra",
                        totalTracks: "7",
                        tags: [
                            TagKey.album: "The Planets",
                            TagKey.albumArtist: "London Symphony Orchestra",
                            TagKey.title: "Mars, the Bringer of War",
                            TagKey.artist: "Gustav Holst",
                            "COMMENT": "Live broadcast",
                            "DISCTOTAL": "2"
                        ],
                        sourceFileURL: trackURL
                    )
                    viewModel.trackItems = [addedTrack]
                    viewModel.selectedTrackIDs = [addedTrack.id]
                    viewModel.reloadMiscTagRowsFromSelection()
                    return [addedTrack.id]
                },
                selectTracks: { trackIDs in
                    viewModel.selectedTrackIDs = trackIDs
                    viewModel.reloadMiscTagRowsFromSelection()
                },
                saveDocument: { _ in
                    .init()
                },
                upsertTag: { trackID, key, value in
                    try viewModel.appleScriptUpsertTag(key: key, value: value, forTrackID: trackID)
                },
                deleteTag: { trackID, key in
                    try viewModel.appleScriptDeleteTag(key: key, forTrackID: trackID)
                }
            )
        )

        let scriptWindow = SwiftTagScriptEditorWindow(sessionID: sessionID)
        let addedTracks = try scriptWindow.addTracks(at: [trackURL])
        #expect(addedTracks.count == 1)

        let scriptTrack = try #require(addedTracks.first)
        let initialKeys = scriptTrack.tags.compactMap(\.key)

        #expect(initialKeys == initialKeys.sorted())
        #expect(initialKeys.contains(TagKey.album))
        #expect(initialKeys.contains(TagKey.albumArtist))
        #expect(initialKeys.contains(TagKey.artist))
        #expect(initialKeys.contains("COMMENT"))
        #expect(initialKeys.contains(TagKey.title))
        #expect(initialKeys.contains(SwiftTagAppleScriptTagKey.totalDiscs))
        #expect(initialKeys.contains(SwiftTagAppleScriptTagKey.totalTracks))
        #expect(!initialKeys.contains("DISCTOTAL"))
        #expect(!initialKeys.contains("ALBUM ARTIST"))

        #expect(scriptTrack.valueInTags(withUniqueID: "ALBUM ARTIST") == nil)

        let totalTracksTag = try #require(scriptTrack.valueInTags(withUniqueID: "TRACKTOTAL") as? SwiftTagScriptTag)
        #expect(totalTracksTag.id == SwiftTagAppleScriptTagKey.totalTracks)
        #expect(totalTracksTag.value == "7")
        totalTracksTag.value = ""
        #expect(viewModel.trackItems.first?.tags["TOTALTRACKS"] == "")
        #expect(viewModel.trackItems.first?.tags["TRACKTOTAL"] == nil)
        #expect(scriptTrack.trackCount == nil)
        #expect((scriptTrack.valueInTags(withUniqueID: SwiftTagAppleScriptTagKey.totalTracks) as? SwiftTagScriptTag)?.value == nil)

        scriptTrack.trackCount = NSNumber(value: 11)
        #expect(viewModel.trackItems.first?.totalTracks == "11")
        #expect(viewModel.trackItems.first?.tags["TOTALTRACKS"] == "11")
        #expect(viewModel.trackItems.first?.tags["TRACKTOTAL"] == nil)

        scriptTrack.album = ""
        #expect(viewModel.trackItems.first?.tags[TagKey.album] == "")
        #expect(scriptTrack.album == nil)
        #expect((scriptTrack.valueInTags(withUniqueID: TagKey.album) as? SwiftTagScriptTag)?.value == nil)

        scriptTrack.album = "The Planets"
        #expect(viewModel.trackItems.first?.tags[TagKey.album] == "The Planets")

        let albumArtistTag = try #require(scriptTrack.valueInTags(withUniqueID: TagKey.albumArtist) as? SwiftTagScriptTag)
        #expect(albumArtistTag.id == TagKey.albumArtist)
        #expect(albumArtistTag.key == TagKey.albumArtist)
        #expect(albumArtistTag.value == "London Symphony Orchestra")
        albumArtistTag.value = "London Philharmonic Orchestra"
        #expect(viewModel.trackItems.first?.tags[TagKey.albumArtist] == "London Philharmonic Orchestra")
        #expect(viewModel.trackItems.first?.tags["ALBUM ARTIST"] == nil)
        #expect(scriptTrack.albumArtist == "London Philharmonic Orchestra")

        let titleTag = try #require(scriptTrack.valueInTags(withUniqueID: TagKey.title) as? SwiftTagScriptTag)
        #expect(titleTag.id == TagKey.title)
        #expect(titleTag.value == "Mars, the Bringer of War")
        titleTag.value = "Mars"
        #expect(viewModel.trackItems.first?.tags[TagKey.title] == "Mars")

        let artistTagSpecifier = try Self.whoseTagSpecifier(
            in: scriptTrack,
            propertyKey: "key",
            value: TagKey.artist
        )
        let matchingArtistTags = Self.evaluatedTagWrappers(from: artistTagSpecifier)
        #expect(matchingArtistTags.count == 1)
        #expect(matchingArtistTags.first?.id == TagKey.artist)
        #expect(matchingArtistTags.first?.key == TagKey.artist)
        #expect(matchingArtistTags.first?.value == "Gustav Holst")

        let tagCountBeforeArtistUpsert = scriptTrack.countOfTags
        let artistTagUpdate = SwiftTagScriptTag()
        artistTagUpdate.key = TagKey.artist
        artistTagUpdate.value = "London Symphony Orchestra"
        scriptTrack.insertObject(artistTagUpdate, inTagsAt: 0)
        #expect(scriptTrack.countOfTags == tagCountBeforeArtistUpsert)
        #expect(viewModel.trackItems.first?.tags[TagKey.artist] == "London Symphony Orchestra")

        let detachedTag = SwiftTagScriptTag()
        detachedTag.key = "SOMEKEY"
        detachedTag.value = "SOMEVALUE"
        #expect(detachedTag.objectSpecifier == nil)

        scriptTrack.insertObject(detachedTag, inTagsAt: scriptTrack.countOfTags)
        #expect(viewModel.trackItems.first?.tags["SOMEKEY"] == "SOMEVALUE")
        let insertedTag = try #require(scriptTrack.valueInTags(withUniqueID: "SOMEKEY") as? SwiftTagScriptTag)
        insertedTag.key = "RENAMEDKEY"
        #expect(scriptTrack.valueInTags(withUniqueID: "SOMEKEY") == nil)
        #expect(viewModel.trackItems.first?.tags["RENAMEDKEY"] == "SOMEVALUE")

        let replacementTag = SwiftTagScriptTag()
        replacementTag.key = "RENAMEDKEY"
        replacementTag.value = "UPDATED"
        scriptTrack.replaceObjectInTags(at: scriptTrack.countOfTags, with: replacementTag)
        #expect(viewModel.trackItems.first?.tags["RENAMEDKEY"] == "UPDATED")

        let renamedIndex = try #require(scriptTrack.tags.firstIndex(where: { $0.key == "RENAMEDKEY" }))
        scriptTrack.mutableArrayValue(forKey: "tags").removeObject(at: renamedIndex)
        #expect(viewModel.trackItems.first?.tags["RENAMEDKEY"] == nil)
        #expect(scriptTrack.valueInTags(withUniqueID: "RENAMEDKEY") == nil)

        let albumTag = try #require(scriptTrack.valueInTags(withUniqueID: TagKey.album) as? SwiftTagScriptTag)
        albumTag.value = "Tag Element Album"
        #expect(viewModel.trackItems.first?.album == "Tag Element Album")
        #expect(scriptTrack.album == "Tag Element Album")
        try albumTag.delete()
        #expect(viewModel.trackItems.first?.album == "")
        #expect(viewModel.trackItems.first?.tags[TagKey.album] == nil)
        #expect(scriptTrack.album == nil)
        #expect(scriptTrack.valueInTags(withUniqueID: TagKey.album) == nil)

        scriptTrack.album = "Property Delete Album"
        #expect(viewModel.trackItems.first?.tags[TagKey.album] == "Property Delete Album")

        try scriptTrack.deleteTagValue(forScriptPropertyKey: "album")
        #expect(viewModel.trackItems.first?.album == "")
        #expect(viewModel.trackItems.first?.tags[TagKey.album] == nil)
        #expect(scriptTrack.album == nil)

        try scriptTrack.deleteTagValue(forScriptPropertyKey: "trackCount")
        #expect(viewModel.trackItems.first?.totalTracks == "")
        #expect(viewModel.trackItems.first?.tags["TOTALTRACKS"] == nil)
        #expect(scriptTrack.trackCount == nil)
    }

    @MainActor
    @Test
    func addingTracksThroughScriptEditorWindowReturnsAddedTrackWrappers() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let addedURL = URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-added.flac")
        var sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(tracks: [], selectedTrackIDs: [])
        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    sessionSnapshot
                },
                addTracks: { urls in
                    #expect(urls == [addedURL.standardizedFileURL])

                    let addedTrack = Track(
                        tags: [TagKey.title: "Added Track"],
                        sourceFileURL: addedURL
                    )
                    sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
                        tracks: [addedTrack],
                        selectedTrackIDs: []
                    )
                    return [addedTrack.id]
                },
                selectTracks: { trackIDs in
                    sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
                        tracks: sessionSnapshot.tracks,
                        selectedTrackIDs: trackIDs
                    )
                },
                saveDocument: { _ in
                    .init()
                }
            )
        )

        let scriptWindow = SwiftTagScriptEditorWindow(sessionID: sessionID)
        let addedTracks = try scriptWindow.addTracks(at: [addedURL])

        #expect(addedTracks.count == 1)
        #expect(scriptWindow.countOfTracks == 1)
        #expect(addedTracks.first?.fileURL == addedURL.standardizedFileURL)
        #expect(scriptWindow.tracks.first?.title == "Added Track")
    }

    @MainActor
    @Test
    func addingTracksThroughScriptEditorWindowPassesLockRequest() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let addedURL = URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-locked-added.flac")
        var receivedLocked: Bool?
        var sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(tracks: [], selectedTrackIDs: [])
        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    sessionSnapshot
                },
                addTracksWithLock: { urls, locked in
                    #expect(urls == [addedURL.standardizedFileURL])
                    receivedLocked = locked

                    let addedTrack = Track(
                        tags: [TagKey.title: "Locked Added Track"],
                        sourceFileURL: addedURL,
                        isLocked: locked
                    )
                    sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
                        tracks: [addedTrack],
                        selectedTrackIDs: []
                    )
                    return [addedTrack.id]
                },
                selectTracks: { trackIDs in
                    sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
                        tracks: sessionSnapshot.tracks,
                        selectedTrackIDs: trackIDs
                    )
                },
                saveDocument: { _ in
                    .init()
                }
            )
        )

        let scriptWindow = SwiftTagScriptEditorWindow(sessionID: sessionID)
        let addedTracks = try scriptWindow.addTracks(at: [addedURL], locked: true)

        #expect(receivedLocked == true)
        #expect(addedTracks.count == 1)
        #expect(sessionSnapshot.tracks.first?.isLocked == true)
        #expect(scriptWindow.tracks.first?.title == "Locked Added Track")
    }

    @MainActor
    @Test
    func trackLockedPropertyReadsAndWritesBridgeLockState() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let trackID = UUID()
        let trackURL = URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-lock-property.flac")
        var track = Track(
            id: trackID,
            tags: [TagKey.title: "Lock Property Track"],
            sourceFileURL: trackURL,
            isLocked: false
        )
        SwiftTagAppleScriptController.shared.registerSessionBridge(
            sessionID: sessionID,
            bridge: SwiftTagAppleScriptSessionBridge(
                documentSnapshot: {
                    SwiftTagAppleScriptDocumentSnapshot(
                        name: "Untitled",
                        modified: false,
                        saveState: .init()
                    )
                },
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(
                        tracks: [track],
                        selectedTrackIDs: []
                    )
                },
                addTracks: { _ in [] },
                selectTracks: { _ in },
                setTrackLocked: { requestedTrackID, locked in
                    #expect(requestedTrackID == trackID)
                    track.isLocked = locked
                },
                saveDocument: { _ in
                    .init()
                }
            )
        )

        let scriptTrack = SwiftTagScriptTrack(sessionID: sessionID, trackID: trackID)

        #expect(!scriptTrack.trackLocked)
        scriptTrack.trackLocked = true
        #expect(track.isLocked)
        #expect(scriptTrack.trackLocked)
        scriptTrack.setValue(NSNumber(value: false), forKey: "trackLocked")
        #expect(!track.isLocked)
        #expect(!scriptTrack.trackLocked)
    }
}

private extension SwiftTagAppleScriptTests {
    static func evaluatedTrackWrappers(from value: Any?) -> [SwiftTagScriptTrack] {
        let evaluatedValue: Any?
        if let specifier = value as? NSScriptObjectSpecifier {
            evaluatedValue = specifier.objectsByEvaluatingSpecifier
        } else {
            evaluatedValue = value
        }

        if let track = evaluatedValue as? SwiftTagScriptTrack {
            return [track]
        }

        if let tracks = evaluatedValue as? [SwiftTagScriptTrack] {
            return tracks
        }

        if let tracks = evaluatedValue as? NSArray {
            return tracks.compactMap { $0 as? SwiftTagScriptTrack }
        }

        return []
    }

    static func evaluatedPictureWrappers(from value: Any?) -> [SwiftTagScriptPicture] {
        let evaluatedValue: Any?
        if let specifier = value as? NSScriptObjectSpecifier {
            evaluatedValue = specifier.objectsByEvaluatingSpecifier
        } else {
            evaluatedValue = value
        }

        if let picture = evaluatedValue as? SwiftTagScriptPicture {
            return [picture]
        }

        if let pictures = evaluatedValue as? [SwiftTagScriptPicture] {
            return pictures
        }

        if let pictures = evaluatedValue as? NSArray {
            return pictures.compactMap { $0 as? SwiftTagScriptPicture }
        }

        return []
    }

    static func evaluatedTagWrappers(from value: Any?) -> [SwiftTagScriptTag] {
        let evaluatedValue: Any?
        if let specifier = value as? NSScriptObjectSpecifier {
            evaluatedValue = specifier.objectsByEvaluatingSpecifier
        } else {
            evaluatedValue = value
        }

        if let tag = evaluatedValue as? SwiftTagScriptTag {
            return [tag]
        }

        if let tags = evaluatedValue as? [SwiftTagScriptTag] {
            return tags
        }

        if let tags = evaluatedValue as? NSArray {
            return tags.compactMap { $0 as? SwiftTagScriptTag }
        }

        return []
    }

    @MainActor
    static func whoseTrackSpecifier(
        in scriptWindow: SwiftTagScriptEditorWindow,
        propertyKey: String,
        value: Any
    ) throws -> NSWhoseSpecifier {
        let editorWindowClassDescription = try #require(
            NSScriptClassDescription(for: SwiftTagScriptEditorWindow.self)
        )
        let trackClassDescription = try #require(
            NSScriptClassDescription(for: SwiftTagScriptTrack.self)
        )
        let containerSpecifier = try #require(scriptWindow.objectSpecifier)
        let propertySpecifier = NSPropertySpecifier(
            containerClassDescription: trackClassDescription,
            containerSpecifier: nil,
            key: propertyKey
        )
        propertySpecifier.containerIsObjectBeingTested = true
        let test = NSSpecifierTest(
            objectSpecifier: propertySpecifier,
            comparisonOperator: .equal,
            test: value
        )

        return NSWhoseSpecifier(
            containerClassDescription: editorWindowClassDescription,
            containerSpecifier: containerSpecifier,
            key: "tracks",
            test: test
        )
    }

    @MainActor
    static func whoseTagSpecifier(
        in scriptTrack: SwiftTagScriptTrack,
        propertyKey: String,
        value: Any
    ) throws -> NSWhoseSpecifier {
        let trackClassDescription = try #require(
            NSScriptClassDescription(for: SwiftTagScriptTrack.self)
        )
        let tagClassDescription = try #require(
            NSScriptClassDescription(for: SwiftTagScriptTag.self)
        )
        let containerSpecifier = try #require(scriptTrack.objectSpecifier)
        let propertySpecifier = NSPropertySpecifier(
            containerClassDescription: tagClassDescription,
            containerSpecifier: nil,
            key: propertyKey
        )
        propertySpecifier.containerIsObjectBeingTested = true
        let test = NSSpecifierTest(
            objectSpecifier: propertySpecifier,
            comparisonOperator: .equal,
            test: value
        )

        return NSWhoseSpecifier(
            containerClassDescription: trackClassDescription,
            containerSpecifier: containerSpecifier,
            key: "tags",
            test: test
        )
    }

    @MainActor
    static func whosePictureSpecifier(
        in scriptTrack: SwiftTagScriptTrack,
        propertyKey: String,
        value: Any
    ) throws -> NSWhoseSpecifier {
        let trackClassDescription = try #require(
            NSScriptClassDescription(for: SwiftTagScriptTrack.self)
        )
        let pictureClassDescription = try #require(
            NSScriptClassDescription(for: SwiftTagScriptPicture.self)
        )
        let containerSpecifier = try #require(scriptTrack.objectSpecifier)
        let propertySpecifier = NSPropertySpecifier(
            containerClassDescription: pictureClassDescription,
            containerSpecifier: nil,
            key: propertyKey
        )
        propertySpecifier.containerIsObjectBeingTested = true
        let test = NSSpecifierTest(
            objectSpecifier: propertySpecifier,
            comparisonOperator: .equal,
            test: value
        )

        return NSWhoseSpecifier(
            containerClassDescription: trackClassDescription,
            containerSpecifier: containerSpecifier,
            key: "pictures",
            test: test
        )
    }

    static func singlePixelPNGData() -> Data? {
        Data(
            base64Encoded:
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO3ZbZ0AAAAASUVORK5CYII="
        )
    }

    static func pngData(color: NSColor) throws -> Data {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRepresentation.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return pngData
    }

    static func tempPackageURL(name: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftTagAppleScriptTests", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let packageURL = directoryURL
            .appendingPathComponent("\(name)-\(UUID().uuidString)")
            .appendingPathExtension("swifttag")
        try? FileManager.default.removeItem(at: packageURL)
        return packageURL
    }

    static func fourCharCode(_ value: String) -> NSNumber {
        let bytes = Array(value.utf8.prefix(4))
        let paddedBytes = bytes + Array(repeating: UInt8(ascii: " "), count: max(0, 4 - bytes.count))
        let code = paddedBytes.prefix(4).reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
        return NSNumber(value: code)
    }

    @MainActor
    static func expectAppleScriptCode(
        _ application: NSApplication,
        key: String,
        code: String
    ) throws {
        let value = try #require(application.value(forKey: key) as? NSNumber)
        #expect(value.uint32Value == fourCharCode(code).uint32Value)
    }

    static func expectColorRecord(
        _ record: NSDictionary,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double
    ) throws {
        let redValue = try #require(record["red"] as? NSNumber)
        let greenValue = try #require(record["green"] as? NSNumber)
        let blueValue = try #require(record["blue"] as? NSNumber)
        let alphaValue = try #require(record["alpha"] as? NSNumber)

        #expect(abs(redValue.doubleValue - red) < 0.001)
        #expect(abs(greenValue.doubleValue - green) < 0.001)
        #expect(abs(blueValue.doubleValue - blue) < 0.001)
        #expect(abs(alphaValue.doubleValue - alpha) < 0.001)
    }
}
