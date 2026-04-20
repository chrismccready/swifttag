import AppKit
import Foundation
import Testing
@testable import SwiftTag

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

        let scriptWindow = SwiftTagScriptEditorWindow()
        application.insertInScriptEditorWindows(scriptWindow)

        let openedSession = try #require(openedSessions.first)
        #expect(openedSessions.count == 1)
        #expect(openedSession.sessionID.uuidString == scriptWindow.windowID)

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
}

private extension SwiftTagAppleScriptTests {
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
}
