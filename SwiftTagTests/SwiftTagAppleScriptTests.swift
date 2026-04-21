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
                sessionSnapshot: {
                    SwiftTagAppleScriptSessionSnapshot(tracks: [], selectedTrackID: nil)
                },
                addTracks: { _ in
                    []
                },
                selectTrack: { _ in
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
    func editorWindowTracksSupportSelectionAndTypedTrackProperties() throws {
        SwiftTagAppleScriptController.shared.resetForTesting()
        EditorWindowCoordinator.shared.resetForTesting()
        defer {
            SwiftTagAppleScriptController.shared.resetForTesting()
            EditorWindowCoordinator.shared.resetForTesting()
        }

        let sessionID = UUID()
        let trackURL = URL(fileURLWithPath: "/tmp/SwiftTagAppleScriptTests-track.flac")
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
            sourceFileURL: trackURL,
            duration: 321.5
        )

        var sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
            tracks: [track],
            selectedTrackID: nil
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
                selectTrack: { trackID in
                    sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
                        tracks: sessionSnapshot.tracks,
                        selectedTrackID: trackID
                    )
                },
                saveDocument: { _ in
                    .init()
                }
            )
        )

        let scriptWindow = SwiftTagScriptEditorWindow(sessionID: sessionID)
        #expect(scriptWindow.countOfTracks == 1)
        let scriptTrack = try #require(scriptWindow.tracks.first)

        #expect(scriptTrack.album == "The Planets")
        #expect(scriptTrack.albumArtist == "London Symphony Orchestra")
        #expect(scriptTrack.artist == "Gustav Holst")
        #expect(scriptTrack.comment == "Live broadcast")
        #expect(scriptTrack.compilation?.boolValue == true)
        #expect(scriptTrack.discCount?.intValue == 2)
        #expect(scriptTrack.discNumber?.intValue == 1)
        #expect(scriptTrack.duration?.doubleValue == 321.5)
        #expect(scriptTrack.fileURL == trackURL.standardizedFileURL)
        #expect(scriptTrack.rating?.intValue == 5)
        #expect(scriptTrack.title == "Mars, the Bringer of War")
        #expect(scriptTrack.trackCount?.intValue == 7)
        #expect(scriptTrack.trackNumber?.intValue == 3)

        let calendar = Calendar(identifier: .gregorian)
        let releaseDate = try #require(scriptTrack.releaseDate)
        #expect(calendar.component(.year, from: releaseDate) == 2024)
        #expect(calendar.component(.month, from: releaseDate) == 3)
        #expect(calendar.component(.day, from: releaseDate) == 14)

        scriptWindow.selectedTrack = scriptTrack
        #expect(sessionSnapshot.selectedTrackID == track.id)
        #expect(scriptWindow.selectedTrack?.fileURL == trackURL.standardizedFileURL)
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
        var sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(tracks: [], selectedTrackID: nil)
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
                        selectedTrackID: nil
                    )
                    return [addedTrack.id]
                },
                selectTrack: { trackID in
                    sessionSnapshot = SwiftTagAppleScriptSessionSnapshot(
                        tracks: sessionSnapshot.tracks,
                        selectedTrackID: trackID
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
