import AppKit
import Foundation

@MainActor
final class EditorWindowCoordinator {
    static let shared = EditorWindowCoordinator()

    private var openEditorWindowAction: ((EditorSessionValue) -> Void)?
    private var sessionByFingerprint: [String: EditorSessionValue] = [:]
    private var registrationBySessionID: [UUID: SessionRegistration] = [:]
    private var pendingSessionToOpen: EditorSessionValue?

    private init() {}

    private struct SessionRegistration {
        let sessionValue: EditorSessionValue
        let fingerprint: String
        let normalizedPaths: Set<String>
    }

    func setOpenEditorWindowAction(_ action: @escaping (EditorSessionValue) -> Void) {
        openEditorWindowAction = action
        flushPendingSessionToOpenIfNeeded()
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

    func unregister(sessionID: UUID) {
        if let registration = registrationBySessionID.removeValue(forKey: sessionID) {
            sessionByFingerprint.removeValue(forKey: registration.fingerprint)
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
            pendingSessionToOpen = sessionValue
            return
        }

        openEditorWindowAction(sessionValue)
    }

    private func flushPendingSessionToOpenIfNeeded() {
        guard let pendingSessionToOpen, let openEditorWindowAction else {
            return
        }

        self.pendingSessionToOpen = nil
        openEditorWindowAction(pendingSessionToOpen)
    }

    func resetForTesting() {
        openEditorWindowAction = nil
        sessionByFingerprint.removeAll()
        registrationBySessionID.removeAll()
        pendingSessionToOpen = nil
    }
}
