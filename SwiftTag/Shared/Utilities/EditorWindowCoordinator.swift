import AppKit
import Foundation

@MainActor
final class EditorWindowCoordinator {
    static let shared = EditorWindowCoordinator()

    private var openEditorWindowAction: ((EditorSessionValue) -> Void)?
    private var sessionByFingerprint: [String: EditorSessionValue] = [:]
    private var registrationBySessionID: [UUID: SessionRegistration] = [:]
    private var externalOpenHandlerBySessionID: [UUID: ([URL]) -> Void] = [:]
    private var pendingFilesBySessionID: [UUID: [URL]] = [:]
    private var pendingBootstrapFiles: [URL] = []
    private var pendingSessionsToOpen: [EditorSessionValue] = []
    private var activeSessionID: UUID?

    private init() {}

    private struct SessionRegistration {
        let sessionValue: EditorSessionValue
        let fingerprint: String
        let normalizedPaths: Set<String>
    }

    func setOpenEditorWindowAction(_ action: @escaping (EditorSessionValue) -> Void) {
        openEditorWindowAction = action
        flushPendingSessionsToOpenIfNeeded()
    }

    func register(sessionValue: EditorSessionValue, trackReferences: [ImportedTrackReference]) {
        let normalizedPaths = TrackSetFingerprint.normalizedPaths(from: trackReferences)
        let newFingerprint = TrackSetFingerprint.make(fromNormalizedPaths: normalizedPaths)
        let previousFingerprint = registrationBySessionID[sessionValue.sessionID]?.fingerprint

        if let previousFingerprint, previousFingerprint != newFingerprint {
            sessionByFingerprint.removeValue(forKey: previousFingerprint)
        }

        registrationBySessionID[sessionValue.sessionID] = SessionRegistration(
            sessionValue: sessionValue,
            fingerprint: newFingerprint,
            normalizedPaths: Set(normalizedPaths)
        )

        guard !newFingerprint.isEmpty else {
            return
        }

        sessionByFingerprint[newFingerprint] = sessionValue
    }

    func registerExternalOpenHandler(
        sessionID: UUID,
        handler: @escaping ([URL]) -> Void
    ) {
        externalOpenHandlerBySessionID[sessionID] = handler
        flushPendingBootstrapFilesIfNeeded(to: sessionID)
        flushPendingFilesIfNeeded(for: sessionID)
    }

    func markSessionFocused(_ sessionID: UUID) {
        guard registrationBySessionID[sessionID] != nil else {
            return
        }
        activeSessionID = sessionID
    }

    func unregister(sessionID: UUID) {
        if let registration = registrationBySessionID.removeValue(forKey: sessionID) {
            sessionByFingerprint.removeValue(forKey: registration.fingerprint)
        }
        externalOpenHandlerBySessionID.removeValue(forKey: sessionID)
        pendingFilesBySessionID.removeValue(forKey: sessionID)
        if activeSessionID == sessionID {
            activeSessionID = nil
        }
    }

    func existingSession(forFingerprint fingerprint: String) -> EditorSessionValue? {
        guard !fingerprint.isEmpty else {
            return nil
        }

        if let exactSession = sessionByFingerprint[fingerprint] {
            return exactSession
        }

        let savedPaths = Set(fingerprint.split(separator: "\n").map(String.init))
        guard !savedPaths.isEmpty else {
            return nil
        }

        let bestMatch = registrationBySessionID.values
            .filter { savedPaths.isSubset(of: $0.normalizedPaths) }
            .sorted {
                if $0.normalizedPaths.count != $1.normalizedPaths.count {
                    return $0.normalizedPaths.count < $1.normalizedPaths.count
                }

                return $0.sessionValue.sessionID.uuidString < $1.sessionValue.sessionID.uuidString
            }
            .first

        return bestMatch?.sessionValue
    }

    func openEditorWindow(for sessionValue: EditorSessionValue) {
        NSApp.activate(ignoringOtherApps: true)

        guard let openEditorWindowAction else {
            pendingSessionsToOpen.append(sessionValue)
            return
        }

        openEditorWindowAction(sessionValue)
    }

    func routeFinderOpenedFiles(_ urls: [URL], appIsActive: Bool) -> Bool {
        let flacFiles = normalizedFlacFiles(from: urls)
        guard !flacFiles.isEmpty else {
            return false
        }

        if appIsActive,
           let activeSessionID,
           let activeSession = registrationBySessionID[activeSessionID]?.sessionValue {
            openEditorWindow(for: activeSession)
            enqueuePendingFiles(flacFiles, for: activeSessionID)
            flushPendingFilesIfNeeded(for: activeSessionID)
            return true
        }

        if !appIsActive, registrationBySessionID.isEmpty {
            pendingBootstrapFiles = normalizedFlacFiles(from: pendingBootstrapFiles + flacFiles)
            return true
        }

        let newSessionValue = EditorSessionValue()
        enqueuePendingFiles(flacFiles, for: newSessionValue.sessionID)
        openEditorWindow(for: newSessionValue)
        return true
    }

    private func flushPendingSessionsToOpenIfNeeded() {
        guard let openEditorWindowAction else {
            return
        }

        let sessionsToOpen = pendingSessionsToOpen
        pendingSessionsToOpen.removeAll()
        for sessionValue in sessionsToOpen {
            openEditorWindowAction(sessionValue)
        }
    }

    private func enqueuePendingFiles(_ urls: [URL], for sessionID: UUID) {
        let existingFiles = pendingFilesBySessionID[sessionID, default: []]
        pendingFilesBySessionID[sessionID] = normalizedFlacFiles(from: existingFiles + urls)
    }

    private func flushPendingFilesIfNeeded(for sessionID: UUID) {
        guard let handler = externalOpenHandlerBySessionID[sessionID],
              let pendingFiles = pendingFilesBySessionID[sessionID],
              !pendingFiles.isEmpty else {
            return
        }

        pendingFilesBySessionID.removeValue(forKey: sessionID)
        handler(pendingFiles)
    }

    private func flushPendingBootstrapFilesIfNeeded(to sessionID: UUID) {
        guard let handler = externalOpenHandlerBySessionID[sessionID],
              !pendingBootstrapFiles.isEmpty else {
            return
        }

        let pendingFiles = pendingBootstrapFiles
        pendingBootstrapFiles.removeAll()
        handler(pendingFiles)
    }

    private func normalizedFlacFiles(from urls: [URL]) -> [URL] {
        let uniquePaths = Set(
            urls
                .filter { $0.isFileURL }
                .filter { $0.pathExtension.localizedCaseInsensitiveCompare("flac") == .orderedSame }
                .map { $0.standardizedFileURL.path }
        )

        return uniquePaths
            .map(URL.init(fileURLWithPath:))
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    func resetForTesting() {
        openEditorWindowAction = nil
        sessionByFingerprint.removeAll()
        registrationBySessionID.removeAll()
        externalOpenHandlerBySessionID.removeAll()
        pendingFilesBySessionID.removeAll()
        pendingBootstrapFiles.removeAll()
        pendingSessionsToOpen.removeAll()
        activeSessionID = nil
    }
}
