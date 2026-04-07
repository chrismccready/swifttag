import AppKit
import Foundation

protocol EditorWindowSessionIdentifying: AnyObject {
    var editorSessionID: UUID { get }
}

@MainActor
final class EditorWindowCoordinator {
    static let shared = EditorWindowCoordinator()

    private var fallbackOpenEditorWindowAction: ((EditorSessionValue) -> Void)?
    private var openEditorWindowActionBySessionID: [UUID: (EditorSessionValue) -> Void] = [:]
    private var sessionByFingerprint: [String: EditorSessionValue] = [:]
    private var sessionBySwiftTagDocumentPath: [String: EditorSessionValue] = [:]
    private var sessionBySwiftTagDocumentID: [UUID: EditorSessionValue] = [:]
    private var registrationBySessionID: [UUID: SessionRegistration] = [:]
    private var externalOpenHandlerBySessionID: [UUID: ([URL]) -> Void] = [:]
    private var swiftTagDocumentOpenHandlerBySessionID: [UUID: (URL) -> Void] = [:]
    private var pendingFilesBySessionID: [UUID: [URL]] = [:]
    private var pendingSwiftTagDocumentsBySessionID: [UUID: URL] = [:]
    private var pendingBootstrapFiles: [URL] = []
    private var pendingSessionsToOpen: [EditorSessionValue] = []
    private var activeSessionID: UUID?
    private var closingSessionIDs: Set<UUID> = []

    private init() {}

    private struct SessionRegistration {
        let sessionValue: EditorSessionValue
        let fingerprint: String
        let normalizedPaths: Set<String>
        let swiftTagDocumentPath: String?
        let swiftTagDocumentID: UUID?
    }

    func setOpenEditorWindowAction(_ action: @escaping (EditorSessionValue) -> Void) {
        fallbackOpenEditorWindowAction = action
        flushPendingSessionsToOpenIfNeeded()
    }

    func setOpenEditorWindowAction(
        for sessionID: UUID,
        action: @escaping (EditorSessionValue) -> Void
    ) {
        openEditorWindowActionBySessionID[sessionID] = action
        flushPendingSessionsToOpenIfNeeded()
    }

    func register(
        sessionValue: EditorSessionValue,
        trackReferences: [ImportedTrackReference],
        swiftTagDocumentURL: URL? = nil,
        swiftTagDocumentID: UUID? = nil
    ) {
        closingSessionIDs.remove(sessionValue.sessionID)
        let normalizedPaths = TrackSetFingerprint.normalizedPaths(from: trackReferences)
        let newFingerprint = TrackSetFingerprint.make(fromNormalizedPaths: normalizedPaths)
        let normalizedSwiftTagDocumentPath = swiftTagDocumentURL?.standardizedFileURL.path
        let previousRegistration = registrationBySessionID[sessionValue.sessionID]
        let previousFingerprint = previousRegistration?.fingerprint

        if let previousFingerprint, previousFingerprint != newFingerprint {
            sessionByFingerprint.removeValue(forKey: previousFingerprint)
        }
        if let previousDocumentPath = previousRegistration?.swiftTagDocumentPath,
           previousDocumentPath != normalizedSwiftTagDocumentPath {
            sessionBySwiftTagDocumentPath.removeValue(forKey: previousDocumentPath)
        }
        if let previousDocumentID = previousRegistration?.swiftTagDocumentID,
           previousDocumentID != swiftTagDocumentID {
            sessionBySwiftTagDocumentID.removeValue(forKey: previousDocumentID)
        }

        registrationBySessionID[sessionValue.sessionID] = SessionRegistration(
            sessionValue: sessionValue,
            fingerprint: newFingerprint,
            normalizedPaths: Set(normalizedPaths),
            swiftTagDocumentPath: normalizedSwiftTagDocumentPath,
            swiftTagDocumentID: swiftTagDocumentID
        )

        guard !newFingerprint.isEmpty else {
            if let normalizedSwiftTagDocumentPath {
                sessionBySwiftTagDocumentPath[normalizedSwiftTagDocumentPath] = sessionValue
            }
            if let swiftTagDocumentID {
                sessionBySwiftTagDocumentID[swiftTagDocumentID] = sessionValue
            }
            return
        }

        sessionByFingerprint[newFingerprint] = sessionValue
        if let normalizedSwiftTagDocumentPath {
            sessionBySwiftTagDocumentPath[normalizedSwiftTagDocumentPath] = sessionValue
        }
        if let swiftTagDocumentID {
            sessionBySwiftTagDocumentID[swiftTagDocumentID] = sessionValue
        }
    }

    func registerExternalOpenHandler(
        sessionID: UUID,
        handler: @escaping ([URL]) -> Void
    ) {
        externalOpenHandlerBySessionID[sessionID] = handler
        flushPendingBootstrapFilesIfNeeded(to: sessionID)
        flushPendingFilesIfNeeded(for: sessionID)
    }

    func registerSwiftTagDocumentOpenHandler(
        sessionID: UUID,
        handler: @escaping (URL) -> Void
    ) {
        swiftTagDocumentOpenHandlerBySessionID[sessionID] = handler
        flushPendingSwiftTagDocumentIfNeeded(for: sessionID)
    }

    func markSessionFocused(_ sessionID: UUID) {
        guard registrationBySessionID[sessionID] != nil,
              !closingSessionIDs.contains(sessionID) else {
            return
        }
        activeSessionID = sessionID
    }

    func markSessionClosing(_ sessionID: UUID) {
        closingSessionIDs.insert(sessionID)
        if activeSessionID == sessionID {
            activeSessionID = nil
        }
    }

    func unregister(sessionID: UUID) {
        if let registration = registrationBySessionID.removeValue(forKey: sessionID) {
            sessionByFingerprint.removeValue(forKey: registration.fingerprint)
            if let swiftTagDocumentPath = registration.swiftTagDocumentPath {
                sessionBySwiftTagDocumentPath.removeValue(forKey: swiftTagDocumentPath)
            }
            if let swiftTagDocumentID = registration.swiftTagDocumentID {
                sessionBySwiftTagDocumentID.removeValue(forKey: swiftTagDocumentID)
            }
        }
        openEditorWindowActionBySessionID.removeValue(forKey: sessionID)
        externalOpenHandlerBySessionID.removeValue(forKey: sessionID)
        swiftTagDocumentOpenHandlerBySessionID.removeValue(forKey: sessionID)
        pendingFilesBySessionID.removeValue(forKey: sessionID)
        pendingSwiftTagDocumentsBySessionID.removeValue(forKey: sessionID)
        closingSessionIDs.remove(sessionID)
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

        guard let openEditorWindowAction = currentOpenEditorWindowAction() else {
            pendingSessionsToOpen.append(sessionValue)
            return
        }

        openEditorWindowAction(sessionValue)
    }

    func routeOpenedSwiftTagDocuments(_ urls: [URL]) -> Bool {
        let documentURLs = normalizedSwiftTagDocuments(from: urls)
        guard !documentURLs.isEmpty else {
            return false
        }

        for documentURL in documentURLs {
            if let existingSession = existingSession(forSwiftTagDocumentURL: documentURL) {
                openEditorWindow(for: existingSession)
                continue
            }

            let newSessionValue = EditorSessionValue()
            enqueuePendingSwiftTagDocument(documentURL, for: newSessionValue.sessionID)
            openEditorWindow(for: newSessionValue)
        }

        return true
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

    func routeOpenedDocuments(_ urls: [URL], appIsActive: Bool) -> Bool {
        let didRouteSwiftTagDocuments = routeOpenedSwiftTagDocuments(urls)
        let didRouteFlacFiles = routeFinderOpenedFiles(urls, appIsActive: appIsActive)
        return didRouteSwiftTagDocuments || didRouteFlacFiles
    }

    private func flushPendingSessionsToOpenIfNeeded() {
        guard let openEditorWindowAction = currentOpenEditorWindowAction() else {
            return
        }

        let sessionsToOpen = pendingSessionsToOpen
        pendingSessionsToOpen.removeAll()
        for sessionValue in sessionsToOpen {
            openEditorWindowAction(sessionValue)
        }
    }

    private func currentOpenEditorWindowAction() -> ((EditorSessionValue) -> Void)? {
        if let activeSessionID,
           !closingSessionIDs.contains(activeSessionID),
           let activeAction = openEditorWindowActionBySessionID[activeSessionID] {
            return activeAction
        }

        if let firstAvailableSessionID = openEditorWindowActionBySessionID.keys
            .filter({ !closingSessionIDs.contains($0) })
            .sorted(by: { $0.uuidString < $1.uuidString })
            .first,
           let firstAvailableAction = openEditorWindowActionBySessionID[firstAvailableSessionID] {
            return firstAvailableAction
        }

        return fallbackOpenEditorWindowAction
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

    private func enqueuePendingSwiftTagDocument(_ url: URL, for sessionID: UUID) {
        pendingSwiftTagDocumentsBySessionID[sessionID] = url.standardizedFileURL
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

    private func flushPendingSwiftTagDocumentIfNeeded(for sessionID: UUID) {
        guard let handler = swiftTagDocumentOpenHandlerBySessionID[sessionID],
              let documentURL = pendingSwiftTagDocumentsBySessionID[sessionID] else {
            return
        }

        pendingSwiftTagDocumentsBySessionID.removeValue(forKey: sessionID)
        handler(documentURL)
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

    private func normalizedSwiftTagDocuments(from urls: [URL]) -> [URL] {
        let uniquePaths = Set(
            urls
                .filter { $0.isFileURL }
                .filter {
                    $0.pathExtension.localizedCaseInsensitiveCompare(
                        SwiftTagDocumentType.fileExtension
                    ) == .orderedSame
                }
                .map { $0.standardizedFileURL.path }
        )

        return uniquePaths
            .map(URL.init(fileURLWithPath:))
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    private func existingSession(forSwiftTagDocumentURL documentURL: URL) -> EditorSessionValue? {
        guard let sessionValue = sessionBySwiftTagDocumentPath[documentURL.standardizedFileURL.path] else {
            return nil
        }

        return liveSessionValue(
            for: sessionValue,
            requiresExternalOpenHandler: false,
            requiresSwiftTagDocumentOpenHandler: true
        )
    }

    private func liveSessionValue(
        for sessionValue: EditorSessionValue,
        requiresExternalOpenHandler: Bool,
        requiresSwiftTagDocumentOpenHandler: Bool
    ) -> EditorSessionValue? {
        let sessionID = sessionValue.sessionID
        guard registrationBySessionID[sessionID] != nil else {
            return nil
        }

        if closingSessionIDs.contains(sessionID) {
            unregister(sessionID: sessionID)
            return nil
        }

        if requiresExternalOpenHandler,
           externalOpenHandlerBySessionID[sessionID] == nil {
            unregister(sessionID: sessionID)
            return nil
        }

        if requiresSwiftTagDocumentOpenHandler,
           swiftTagDocumentOpenHandlerBySessionID[sessionID] == nil {
            unregister(sessionID: sessionID)
            return nil
        }

        return sessionValue
    }

    func resetForTesting() {
        fallbackOpenEditorWindowAction = nil
        openEditorWindowActionBySessionID.removeAll()
        sessionByFingerprint.removeAll()
        sessionBySwiftTagDocumentPath.removeAll()
        sessionBySwiftTagDocumentID.removeAll()
        registrationBySessionID.removeAll()
        externalOpenHandlerBySessionID.removeAll()
        swiftTagDocumentOpenHandlerBySessionID.removeAll()
        pendingFilesBySessionID.removeAll()
        pendingSwiftTagDocumentsBySessionID.removeAll()
        pendingBootstrapFiles.removeAll()
        pendingSessionsToOpen.removeAll()
        activeSessionID = nil
        closingSessionIDs.removeAll()
    }
}
