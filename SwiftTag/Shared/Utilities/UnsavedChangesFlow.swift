import Foundation

struct UnsavedChangesEditCounts: Equatable {
    let tagEdits: Int
    let pictureEdits: Int

    var hasUnsavedEdits: Bool {
        tagEdits > 0 || pictureEdits > 0
    }
}

struct UnsavedChangesSessionContext: Equatable {
    let editCounts: UnsavedChangesEditCounts
    let hasReferencedSwiftTagDocument: Bool
    let referencedSwiftTagDocumentURL: URL?
}

enum UnsavedChangesPromptTrigger: Equatable {
    case closeWindow
    case quitApplication

    var alertTitle: String {
        switch self {
        case .closeWindow:
            return "Close Window?"
        case .quitApplication:
            return "Quit SwiftTag?"
        }
    }

    var discardTitle: String {
        switch self {
        case .closeWindow:
            return "Close Window"
        case .quitApplication:
            return "Quit"
        }
    }
}

enum UnsavedChangesSaveChoice: Equatable {
    case saveFlacFiles
    case saveReferencedSwiftTagDocument(name: String?)
    case saveFlacFilesAndReferencedSwiftTagDocument(name: String?)
    case saveNewSwiftTagDocument
    case saveFlacFilesAndNewSwiftTagDocument

    var title: String {
        switch self {
        case .saveFlacFiles:
            return "Save FLAC files"
        case let .saveReferencedSwiftTagDocument(name):
            return "Save \(Self.documentLabel(for: name))"
        case let .saveFlacFilesAndReferencedSwiftTagDocument(name):
            return "Save FLAC files & \(Self.documentLabel(for: name))"
        case .saveNewSwiftTagDocument:
            return "Save New SwiftTag Document..."
        case .saveFlacFilesAndNewSwiftTagDocument:
            return "Save FLAC files & New SwiftTag Document..."
        }
    }

    private static func documentLabel(for name: String?) -> String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedName, !trimmedName.isEmpty else {
            return "SwiftTag Document"
        }

        return trimmedName.truncated(limit: 24, position: .middle)
    }
}

struct UnsavedChangesDialogConfiguration: Equatable {
    let trigger: UnsavedChangesPromptTrigger
    let editCounts: UnsavedChangesEditCounts
    let saveChoices: [UnsavedChangesSaveChoice]

    var alertTitle: String {
        trigger.alertTitle
    }

    var discardTitle: String {
        trigger.discardTitle
    }

    var informativeText: String {
        "There are pending changes that have not been saved: \(editCounts.tagEdits) tag edits, \(editCounts.pictureEdits) picture edits. Choose how to continue."
    }
}

enum UnsavedChangesChoiceResolver {
    static func resolve(
        trigger: UnsavedChangesPromptTrigger,
        context: UnsavedChangesSessionContext
    ) -> UnsavedChangesDialogConfiguration? {
        guard context.editCounts.hasUnsavedEdits else {
            return nil
        }

        let saveChoices: [UnsavedChangesSaveChoice]
        if context.hasReferencedSwiftTagDocument {
            let referencedDocumentName = context.referencedSwiftTagDocumentURL?.lastPathComponent
            saveChoices = [
                .saveFlacFiles,
                .saveReferencedSwiftTagDocument(name: referencedDocumentName),
                .saveFlacFilesAndReferencedSwiftTagDocument(name: referencedDocumentName)
            ]
        } else {
            saveChoices = [
                .saveFlacFiles,
                .saveNewSwiftTagDocument,
                .saveFlacFilesAndNewSwiftTagDocument
            ]
        }

        return UnsavedChangesDialogConfiguration(
            trigger: trigger,
            editCounts: context.editCounts,
            saveChoices: saveChoices
        )
    }
}

enum UnsavedChangesActionResult: Equatable {
    case completed
    case cancelled
    case failed
}