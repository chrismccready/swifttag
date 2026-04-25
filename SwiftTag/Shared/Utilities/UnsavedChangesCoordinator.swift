import AppKit
import Foundation

@MainActor
final class UnsavedChangesCoordinator {
    static let shared = UnsavedChangesCoordinator()

    private struct SessionRegistration {
        let contextProvider: () -> UnsavedChangesSessionContext
        let actionHandler: (UnsavedChangesSaveChoice, UnsavedChangesPromptTrigger) async -> UnsavedChangesActionResult
    }

    private enum AlertSelection {
        case saveChoice(UnsavedChangesSaveChoice)
        case discard
        case cancel
    }

    private var registrationsBySessionID: [UUID: SessionRegistration] = [:]
    private var allowNextCloseSessionIDs: Set<UUID> = []
    private var inFlightSessionIDs: Set<UUID> = []
    private var isQuitWorkflowRunning: Bool = false

    private init() {}

    func register(
        sessionID: UUID,
        contextProvider: @escaping () -> UnsavedChangesSessionContext,
        actionHandler: @escaping (UnsavedChangesSaveChoice, UnsavedChangesPromptTrigger) async -> UnsavedChangesActionResult
    ) {
        registrationsBySessionID[sessionID] = SessionRegistration(
            contextProvider: contextProvider,
            actionHandler: actionHandler
        )
    }

    func unregister(sessionID: UUID) {
        registrationsBySessionID.removeValue(forKey: sessionID)
        allowNextCloseSessionIDs.remove(sessionID)
        inFlightSessionIDs.remove(sessionID)
    }

    func allowNextClose(for sessionID: UUID) {
        allowNextCloseSessionIDs.insert(sessionID)
    }

    func totalUnsavedEdits() -> UnsavedChangesEditCounts {
        registrationsBySessionID.values.reduce(
            into: UnsavedChangesEditCounts(tagEdits: 0, pictureEdits: 0)
        ) { result, registration in
            let counts = registration.contextProvider().editCounts
            result = UnsavedChangesEditCounts(
                tagEdits: result.tagEdits + counts.tagEdits,
                pictureEdits: result.pictureEdits + counts.pictureEdits
            )
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isQuitWorkflowRunning else {
            return .terminateCancel
        }

        let sessionIDs = orderedUnsavedSessionIDs()
        guard !sessionIDs.isEmpty else {
            return .terminateNow
        }

        isQuitWorkflowRunning = true
        Task { @MainActor in
            await beginQuitFlow(for: sessionIDs)
        }
        return .terminateLater
    }

    @discardableResult
    func confirmCloseWindowIfNeeded(for sessionID: UUID, window: NSWindow) -> Bool {
        if allowNextCloseSessionIDs.contains(sessionID) {
            allowNextCloseSessionIDs.remove(sessionID)
            return true
        }

        guard !isQuitWorkflowRunning,
              let registration = registrationsBySessionID[sessionID] else {
            return true
        }

        guard let configuration = UnsavedChangesChoiceResolver.resolve(
            trigger: .closeWindow,
            context: registration.contextProvider()
        ) else {
            return true
        }

        guard inFlightSessionIDs.insert(sessionID).inserted else {
            return false
        }

        Task { @MainActor in
            await beginWindowCloseFlow(
                for: sessionID,
                window: window,
                configuration: configuration,
                registration: registration
            )
        }
        return false
    }

    private func beginWindowCloseFlow(
        for sessionID: UUID,
        window: NSWindow,
        configuration: UnsavedChangesDialogConfiguration,
        registration: SessionRegistration
    ) async {
        let selection = await promptSelection(for: configuration, in: window)

        switch selection {
        case .cancel:
            inFlightSessionIDs.remove(sessionID)
        case .discard:
            allowNextCloseSessionIDs.insert(sessionID)
            inFlightSessionIDs.remove(sessionID)
            window.performClose(nil)
        case let .saveChoice(choice):
            let result = await registration.actionHandler(choice, .closeWindow)
            switch result {
            case .completed:
                allowNextCloseSessionIDs.insert(sessionID)
                inFlightSessionIDs.remove(sessionID)
                window.performClose(nil)
            case .cancelled, .failed:
                inFlightSessionIDs.remove(sessionID)
            }
        }
    }

    private func beginQuitFlow(for sessionIDs: [UUID]) async {
        defer {
            isQuitWorkflowRunning = false
        }

        var bypassSessionIDs: Set<UUID> = []

        for sessionID in sessionIDs {
            guard let registration = registrationsBySessionID[sessionID] else {
                continue
            }
            guard let configuration = UnsavedChangesChoiceResolver.resolve(
                trigger: .quitApplication,
                context: registration.contextProvider()
            ) else {
                continue
            }
            guard inFlightSessionIDs.insert(sessionID).inserted else {
                NSApp.reply(toApplicationShouldTerminate: false)
                return
            }

            let selection = await promptSelection(for: configuration, in: window(for: sessionID))

            switch selection {
            case .cancel:
                inFlightSessionIDs.remove(sessionID)
                NSApp.reply(toApplicationShouldTerminate: false)
                return
            case .discard:
                bypassSessionIDs.insert(sessionID)
                inFlightSessionIDs.remove(sessionID)
            case let .saveChoice(choice):
                let result = await registration.actionHandler(choice, .quitApplication)
                switch result {
                case .completed:
                    bypassSessionIDs.insert(sessionID)
                    inFlightSessionIDs.remove(sessionID)
                case .cancelled, .failed:
                    inFlightSessionIDs.remove(sessionID)
                    NSApp.reply(toApplicationShouldTerminate: false)
                    return
                }
            }
        }

        allowNextCloseSessionIDs.formUnion(bypassSessionIDs)
        NSApp.reply(toApplicationShouldTerminate: true)
    }

    private func orderedUnsavedSessionIDs() -> [UUID] {
        let unsavedSessionIDs = registrationsBySessionID.compactMap { sessionID, registration in
            let configuration = UnsavedChangesChoiceResolver.resolve(
                trigger: .quitApplication,
                context: registration.contextProvider()
            )
            return configuration == nil ? nil : sessionID
        }

        guard let keyWindow = NSApp.keyWindow,
              let sessionDelegate = keyWindow.delegate as? EditorWindowSessionIdentifying,
              unsavedSessionIDs.contains(sessionDelegate.editorSessionID) else {
            return unsavedSessionIDs.sorted { $0.uuidString < $1.uuidString }
        }

        return [sessionDelegate.editorSessionID] + unsavedSessionIDs
            .filter { $0 != sessionDelegate.editorSessionID }
            .sorted { $0.uuidString < $1.uuidString }
    }

    private func window(for sessionID: UUID) -> NSWindow? {
        NSApp.windows.first { window in
            guard let sessionDelegate = window.delegate as? EditorWindowSessionIdentifying else {
                return false
            }
            return sessionDelegate.editorSessionID == sessionID
        }
    }

    private func promptSelection(
        for configuration: UnsavedChangesDialogConfiguration,
        in window: NSWindow?
    ) async -> AlertSelection {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = configuration.alertTitle
        alert.informativeText = configuration.informativeText

        var mappings: [AlertSelection] = []
        for choice in configuration.saveChoices {
            alert.addButton(withTitle: choice.title)
            mappings.append(.saveChoice(choice))
        }
        alert.addButton(withTitle: configuration.discardTitle)
        mappings.append(.discard)
        alert.addButton(withTitle: "Cancel")
        mappings.append(.cancel)
        alert.buttons.last?.keyEquivalent = "\u{1b}"

        if let window {
            return await withCheckedContinuation { continuation in
                alert.beginSheetModal(for: window) { response in
                    continuation.resume(returning: self.selection(for: response, mappings: mappings))
                }
            }
        }

        return selection(for: alert.runModal(), mappings: mappings)
    }

    private func selection(
        for response: NSApplication.ModalResponse,
        mappings: [AlertSelection]
    ) -> AlertSelection {
        let offset = Int(response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
        guard mappings.indices.contains(offset) else {
            return .cancel
        }

        return mappings[offset]
    }
}
