import AppKit
import Foundation

@MainActor
final class UnsavedChangesCoordinator {
    static let shared = UnsavedChangesCoordinator()

    private var providersBySessionID: [UUID: () -> (tagEdits: Int, pictureEdits: Int)] = [:]

    private init() {}

    func register(sessionID: UUID, provider: @escaping () -> (tagEdits: Int, pictureEdits: Int)) {
        providersBySessionID[sessionID] = provider
    }

    func unregister(sessionID: UUID) {
        providersBySessionID.removeValue(forKey: sessionID)
    }

    func totalUnsavedEdits() -> (tagEdits: Int, pictureEdits: Int) {
        providersBySessionID.values.reduce(into: (tagEdits: 0, pictureEdits: 0)) { result, provider in
            let counts = provider()
            result.tagEdits += counts.tagEdits
            result.pictureEdits += counts.pictureEdits
        }
    }

    @discardableResult
    func confirmQuitIfNeeded() -> Bool {
        let counts = totalUnsavedEdits()
        guard counts.tagEdits > 0 || counts.pictureEdits > 0 else {
            return true
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Quit SwiftTag?"
        alert.informativeText = "There are pending changes that have not been saved: \(counts.tagEdits) tag edits, \(counts.pictureEdits) picture edits."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    @discardableResult
    func confirmCloseWindowIfNeeded(for sessionID: UUID) -> Bool {
        guard let provider = providersBySessionID[sessionID] else {
            return true
        }

        let counts = provider()
        guard counts.tagEdits > 0 || counts.pictureEdits > 0 else {
            return true
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Close Window?"
        alert.informativeText = "There are pending changes that have not been saved: \(counts.tagEdits) tag edits, \(counts.pictureEdits) picture edits."
        alert.addButton(withTitle: "Close Window")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
