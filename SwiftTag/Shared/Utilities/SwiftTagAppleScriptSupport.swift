import AppKit
import Foundation

enum SwiftTagAppleScriptCommandError: LocalizedError {
    case missingOpenTarget
    case noSwiftTagDocumentsProvided
    case invalidFileValue
    case invalidSaveDestination
    case saveLocationRequired
    case sessionUnavailable
    case saveAlreadyInProgress

    var errorDescription: String? {
        switch self {
        case .missingOpenTarget:
            return "Open command requires one or more SwiftTag document files."
        case .noSwiftTagDocumentsProvided:
            return "No .swifttag documents were provided."
        case .invalidFileValue:
            return "AppleScript file argument must resolve to a local file URL."
        case .invalidSaveDestination:
            return "Save destination must be a single local file URL."
        case .saveLocationRequired:
            return "Save command needs an existing SwiftTag document or an explicit destination file."
        case .sessionUnavailable:
            return "Target editor window is not available for AppleScript save."
        case .saveAlreadyInProgress:
            return "Save command cannot run while another save operation is already running."
        }
    }

    var scriptErrorNumber: Int {
        switch self {
        case .missingOpenTarget:
            Int(NSRequiredArgumentsMissingScriptError)
        case .noSwiftTagDocumentsProvided, .invalidFileValue, .invalidSaveDestination, .saveLocationRequired:
            Int(NSArgumentsWrongScriptError)
        case .sessionUnavailable:
            Int(NSReceiversCantHandleCommandScriptError)
        case .saveAlreadyInProgress:
            Int(NSInternalScriptError)
        }
    }
}

private enum SwiftTagAppleScriptFileURLResolver {
    nonisolated static func fileURLs(from value: Any?) throws -> [URL] {
        guard let value else {
            throw SwiftTagAppleScriptCommandError.missingOpenTarget
        }

        if let values = value as? [Any] {
            let urls = try values.map(fileURL(fromSingleValue:))
            return urls
        }

        if let values = value as? NSArray {
            let urls = try values.compactMap { item in
                try fileURL(fromSingleValue: item)
            }
            return urls
        }

        return [try fileURL(fromSingleValue: value)]
    }

    nonisolated static func singleFileURL(from value: Any?) throws -> URL? {
        guard let value else {
            return nil
        }

        if let values = value as? [Any] {
            guard values.count == 1 else {
                throw SwiftTagAppleScriptCommandError.invalidSaveDestination
            }
            return try fileURL(fromSingleValue: values[0])
        }

        if let values = value as? NSArray {
            guard values.count == 1, let firstValue = values.firstObject else {
                throw SwiftTagAppleScriptCommandError.invalidSaveDestination
            }
            return try fileURL(fromSingleValue: firstValue)
        }

        return try fileURL(fromSingleValue: value)
    }

    nonisolated private static func fileURL(fromSingleValue value: Any) throws -> URL {
        if let url = value as? URL, url.isFileURL {
            return url.standardizedFileURL
        }

        if let url = value as? NSURL, url.isFileURL {
            return (url as URL).standardizedFileURL
        }

        if let string = value as? String {
            return try normalizedFileURL(from: string)
        }

        if let string = value as? NSString {
            return try normalizedFileURL(from: string as String)
        }

        throw SwiftTagAppleScriptCommandError.invalidFileValue
    }

    nonisolated private static func normalizedFileURL(from rawValue: String) throws -> URL {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            throw SwiftTagAppleScriptCommandError.invalidFileValue
        }

        if let url = URL(string: trimmedValue), url.isFileURL {
            return url.standardizedFileURL
        }

        return URL(fileURLWithPath: trimmedValue).standardizedFileURL
    }
}

private extension NSScriptCommand {
    func fail(_ error: Error) -> Any? {
        if let appleScriptError = error as? SwiftTagAppleScriptCommandError {
            scriptErrorNumber = appleScriptError.scriptErrorNumber
            scriptErrorString = appleScriptError.errorDescription
            return nil
        }

        scriptErrorNumber = Int(NSInternalScriptError)
        scriptErrorString = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return nil
    }
}

struct SwiftTagAppleScriptDocumentSnapshot {
    let name: String
    let modified: Bool
    let saveState: SwiftTagDocumentSaveState
}

struct SwiftTagAppleScriptSessionBridge {
    let documentSnapshot: () -> SwiftTagAppleScriptDocumentSnapshot
    let saveDocument: (URL?) throws -> SwiftTagDocumentSaveState
}

@MainActor
@objc(SwiftTagScriptEditorWindow)
final class SwiftTagScriptEditorWindow: NSObject {
    private let sessionIDValue: UUID
    private weak var liveWindow: NSWindow?
    private var pendingCreationExpiration: Date?

    @objc
    override init() {
        sessionIDValue = UUID()
        super.init()
    }

    init(
        sessionID: UUID,
        liveWindow: NSWindow? = nil,
        pendingCreationExpiration: Date? = nil
    ) {
        sessionIDValue = sessionID
        self.liveWindow = liveWindow
        self.pendingCreationExpiration = pendingCreationExpiration
        super.init()
    }

    @objc(windowID)
    var windowID: String {
        sessionIDValue.uuidString
    }

    @objc(name)
    var name: String {
        let windowTitle = liveWindow?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !windowTitle.isEmpty {
            return windowTitle
        }

        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }

        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bundleName
        }

        return "SwiftTag"
    }

    @objc(document)
    var document: SwiftTagScriptDocument {
        SwiftTagAppleScriptController.shared.document(forSessionID: sessionIDValue)
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let classDescription = NSScriptClassDescription(for: NSApplication.self) else {
            return nil
        }

        if let index = SwiftTagAppleScriptController.shared.indexOfEditorWindow(sessionID: sessionIDValue) {
            return NSIndexSpecifier(
                containerClassDescription: classDescription,
                containerSpecifier: nil,
                key: "scriptEditorWindows",
                index: index
            )
        }

        return NSUniqueIDSpecifier(
            containerClassDescription: classDescription,
            containerSpecifier: nil,
            key: "scriptEditorWindows",
            uniqueID: windowID
        )
    }

    func saveSwiftTagDocument(to destinationURL: URL?) throws -> SwiftTagScriptDocument {
        try SwiftTagAppleScriptController.shared.saveDocument(
            forSessionID: sessionIDValue,
            destinationURL: destinationURL
        )
    }

    @objc(handleSaveScriptCommand:)
    func handleSaveScriptCommand(_ command: NSScriptCommand) -> Any? {
        do {
            let destinationURL = try SwiftTagAppleScriptFileURLResolver.singleFileURL(
                from: command.evaluatedArguments?["File"]
                    ?? command.evaluatedArguments?["file"]
                    ?? command.evaluatedArguments?["in"]
            )
            return try saveSwiftTagDocument(to: destinationURL)
        } catch {
            return command.fail(error)
        }
    }

    fileprivate var sessionID: UUID {
        sessionIDValue
    }

    fileprivate var awaitsMaterialization: Bool {
        guard let pendingCreationExpiration else {
            return false
        }

        return pendingCreationExpiration > Date()
    }

    fileprivate func markAwaitingMaterialization(timeout: TimeInterval = 5) {
        guard liveWindow == nil else {
            return
        }

        pendingCreationExpiration = Date().addingTimeInterval(timeout)
    }

    fileprivate func clearExpiredPendingState(referenceDate: Date = .now) {
        guard let pendingCreationExpiration,
              pendingCreationExpiration <= referenceDate else {
            return
        }

        self.pendingCreationExpiration = nil
    }

    fileprivate func updateLiveWindow(_ window: NSWindow?) {
        liveWindow = window
        if window != nil {
            pendingCreationExpiration = nil
        }
    }
}

@MainActor
@objc(SwiftTagScriptDocument)
final class SwiftTagScriptDocument: NSObject {
    private let sessionIDValue: UUID
    private var fallbackFileURL: URL?

    init(sessionID: UUID, fallbackFileURL: URL? = nil) {
        sessionIDValue = sessionID
        self.fallbackFileURL = fallbackFileURL?.standardizedFileURL
        super.init()
    }

    @objc(name)
    var name: String {
        snapshot.name
    }

    @objc(modified)
    var modified: Bool {
        snapshot.modified
    }

    @objc(fileURL)
    var fileURL: URL? {
        snapshot.saveState.navigationDocumentURL
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let classDescription = NSScriptClassDescription(for: NSApplication.self) else {
            return nil
        }

        if let index = SwiftTagAppleScriptController.shared.indexOfDocument(sessionID: sessionIDValue) {
            return NSIndexSpecifier(
                containerClassDescription: classDescription,
                containerSpecifier: nil,
                key: "scriptDocuments",
                index: index
            )
        }

        return NSUniqueIDSpecifier(
            containerClassDescription: classDescription,
            containerSpecifier: nil,
            key: "scriptDocuments",
            uniqueID: sessionIDValue.uuidString
        )
    }

    func saveSwiftTagDocument(to destinationURL: URL?) throws -> SwiftTagScriptDocument {
        try SwiftTagAppleScriptController.shared.saveDocument(
            forSessionID: sessionIDValue,
            destinationURL: destinationURL
        )
    }

    @objc(handleSaveScriptCommand:)
    func handleSaveScriptCommand(_ command: NSScriptCommand) -> Any? {
        do {
            let destinationURL = try SwiftTagAppleScriptFileURLResolver.singleFileURL(
                from: command.evaluatedArguments?["File"]
                    ?? command.evaluatedArguments?["file"]
                    ?? command.evaluatedArguments?["in"]
            )
            return try saveSwiftTagDocument(to: destinationURL)
        } catch {
            return command.fail(error)
        }
    }

    fileprivate var sessionID: UUID {
        sessionIDValue
    }

    fileprivate func updateFallbackFileURL(_ url: URL?) {
        fallbackFileURL = url?.standardizedFileURL
    }

    private var snapshot: SwiftTagAppleScriptDocumentSnapshot {
        SwiftTagAppleScriptController.shared.documentSnapshot(
            forSessionID: sessionIDValue,
            fallbackFileURL: fallbackFileURL
        )
    }
}

@MainActor
final class SwiftTagAppleScriptController {
    static let shared = SwiftTagAppleScriptController()

    private var editorWindowsBySessionID: [UUID: SwiftTagScriptEditorWindow] = [:]
    private var documentsBySessionID: [UUID: SwiftTagScriptDocument] = [:]
    private var sessionBridgesBySessionID: [UUID: SwiftTagAppleScriptSessionBridge] = [:]
    private var pendingDocumentURLBySessionID: [UUID: URL] = [:]

    private init() {}

    func orderedEditorWindows() -> [SwiftTagScriptEditorWindow] {
        let liveWindows = orderedLiveEditorWindows()
        let now = Date()
        var orderedWrappers: [SwiftTagScriptEditorWindow] = []
        var liveSessionIDs: Set<UUID> = []

        for (sessionID, window) in liveWindows {
            liveSessionIDs.insert(sessionID)
            let wrapper = editorWindow(
                forSessionID: sessionID,
                liveWindow: window,
                markPending: false
            )
            orderedWrappers.append(wrapper)
        }

        var pendingWrappers: [SwiftTagScriptEditorWindow] = []
        for (sessionID, wrapper) in editorWindowsBySessionID where !liveSessionIDs.contains(sessionID) {
            wrapper.updateLiveWindow(nil)
            wrapper.clearExpiredPendingState(referenceDate: now)
            if wrapper.awaitsMaterialization {
                pendingWrappers.append(wrapper)
            } else if sessionBridgesBySessionID[sessionID] == nil,
                      pendingDocumentURLBySessionID[sessionID] == nil {
                editorWindowsBySessionID.removeValue(forKey: sessionID)
            }
        }

        pendingWrappers.sort { $0.windowID < $1.windowID }
        return orderedWrappers + pendingWrappers
    }

    func orderedDocuments() -> [SwiftTagScriptDocument] {
        let orderedWindowSessionIDs = orderedEditorWindows().map(\.sessionID)
        var orderedSessionIDs = orderedWindowSessionIDs
        let extraSessionIDs = Set(sessionBridgesBySessionID.keys)
            .union(pendingDocumentURLBySessionID.keys)
            .subtracting(orderedWindowSessionIDs)
            .sorted { $0.uuidString < $1.uuidString }
        orderedSessionIDs.append(contentsOf: extraSessionIDs)

        let orderedDocuments = orderedSessionIDs.map { sessionID in
            document(
                forSessionID: sessionID,
                fallbackFileURL: pendingDocumentURLBySessionID[sessionID]
            )
        }

        let liveDocumentSessionIDs = Set(orderedSessionIDs)
        for sessionID in documentsBySessionID.keys where !liveDocumentSessionIDs.contains(sessionID) {
            documentsBySessionID.removeValue(forKey: sessionID)
        }

        return orderedDocuments
    }

    func insertEditorWindow(_ scriptWindow: SwiftTagScriptEditorWindow) {
        editorWindowsBySessionID[scriptWindow.sessionID] = scriptWindow
        scriptWindow.markAwaitingMaterialization()
        EditorWindowCoordinator.shared.openEditorWindow(
            for: EditorSessionValue(sessionID: scriptWindow.sessionID)
        )
        synchronizeWindow(for: scriptWindow.sessionID)
    }

    func registerSessionBridge(sessionID: UUID, bridge: SwiftTagAppleScriptSessionBridge) {
        sessionBridgesBySessionID[sessionID] = bridge
    }

    func unregister(sessionID: UUID) {
        editorWindowsBySessionID.removeValue(forKey: sessionID)
        documentsBySessionID.removeValue(forKey: sessionID)
        sessionBridgesBySessionID.removeValue(forKey: sessionID)
        pendingDocumentURLBySessionID.removeValue(forKey: sessionID)
    }

    func editorWindow(withUniqueID uniqueID: Any) -> SwiftTagScriptEditorWindow? {
        guard let sessionID = normalizedSessionID(from: uniqueID) else {
            return nil
        }

        _ = orderedEditorWindows()
        return editorWindowsBySessionID[sessionID]
    }

    func document(withUniqueID uniqueID: Any) -> SwiftTagScriptDocument? {
        guard let sessionID = normalizedSessionID(from: uniqueID) else {
            return nil
        }

        _ = orderedDocuments()
        return documentsBySessionID[sessionID]
    }

    func document(forSessionID sessionID: UUID, fallbackFileURL: URL? = nil) -> SwiftTagScriptDocument {
        if let wrapper = documentsBySessionID[sessionID] {
            if fallbackFileURL != nil {
                wrapper.updateFallbackFileURL(fallbackFileURL)
            }
            return wrapper
        }

        let wrapper = SwiftTagScriptDocument(sessionID: sessionID, fallbackFileURL: fallbackFileURL)
        documentsBySessionID[sessionID] = wrapper
        return wrapper
    }

    func documentSnapshot(
        forSessionID sessionID: UUID,
        fallbackFileURL: URL?
    ) -> SwiftTagAppleScriptDocumentSnapshot {
        if let bridge = sessionBridgesBySessionID[sessionID] {
            return bridge.documentSnapshot()
        }

        let normalizedFallbackURL = fallbackFileURL?.standardizedFileURL
            ?? pendingDocumentURLBySessionID[sessionID]
        let fallbackState = SwiftTagDocumentSaveState(
            destinationURL: normalizedFallbackURL,
            lastKnownDisplayName: normalizedFallbackURL?.lastPathComponent
        )
        return SwiftTagAppleScriptDocumentSnapshot(
            name: normalizedFallbackURL?.lastPathComponent ?? "Untitled",
            modified: false,
            saveState: fallbackState
        )
    }

    func saveDocument(
        forSessionID sessionID: UUID,
        destinationURL: URL?
    ) throws -> SwiftTagScriptDocument {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        let saveState = try bridge.saveDocument(destinationURL)
        pendingDocumentURLBySessionID[sessionID] = saveState.navigationDocumentURL
        return document(forSessionID: sessionID, fallbackFileURL: saveState.navigationDocumentURL)
    }

    func openDocumentWrappers(at urls: [URL]) throws -> [SwiftTagScriptDocument] {
        let documentURLs = normalizedSwiftTagDocumentURLs(from: urls)
        guard !documentURLs.isEmpty else {
            throw SwiftTagAppleScriptCommandError.noSwiftTagDocumentsProvided
        }

        let sessions = EditorWindowCoordinator.shared.openSessionsForSwiftTagDocuments(documentURLs)
        guard !sessions.isEmpty else {
            throw SwiftTagAppleScriptCommandError.noSwiftTagDocumentsProvided
        }

        return zip(sessions, documentURLs).map { sessionValue, documentURL in
            pendingDocumentURLBySessionID[sessionValue.sessionID] = documentURL
            _ = editorWindow(
                forSessionID: sessionValue.sessionID,
                liveWindow: nil,
                markPending: true
            )
            return document(
                forSessionID: sessionValue.sessionID,
                fallbackFileURL: documentURL
            )
        }
    }

    func indexOfEditorWindow(sessionID: UUID) -> Int? {
        orderedEditorWindows().firstIndex { $0.sessionID == sessionID }
    }

    func indexOfDocument(sessionID: UUID) -> Int? {
        orderedDocuments().firstIndex { $0.sessionID == sessionID }
    }

    #if DEBUG
    func resetForTesting() {
        editorWindowsBySessionID.removeAll()
        documentsBySessionID.removeAll()
        sessionBridgesBySessionID.removeAll()
        pendingDocumentURLBySessionID.removeAll()
    }
    #endif

    private func synchronizeWindow(for sessionID: UUID) {
        guard let liveWindow = orderedLiveEditorWindows().first(where: { $0.sessionID == sessionID })?.window else {
            return
        }

        _ = editorWindow(forSessionID: sessionID, liveWindow: liveWindow, markPending: false)
    }

    private func orderedLiveEditorWindows() -> [(sessionID: UUID, window: NSWindow)] {
        NSApplication.shared.orderedWindows.compactMap { window in
            guard let delegate = window.delegate as? EditorWindowSessionIdentifying else {
                return nil
            }

            return (delegate.editorSessionID, window)
        }
    }

    private func normalizedSwiftTagDocumentURLs(from urls: [URL]) -> [URL] {
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

    private func editorWindow(
        forSessionID sessionID: UUID,
        liveWindow: NSWindow?,
        markPending: Bool
    ) -> SwiftTagScriptEditorWindow {
        let wrapper = editorWindowsBySessionID[sessionID]
            ?? SwiftTagScriptEditorWindow(sessionID: sessionID, liveWindow: liveWindow)
        wrapper.updateLiveWindow(liveWindow)
        if markPending {
            wrapper.markAwaitingMaterialization()
        }
        editorWindowsBySessionID[sessionID] = wrapper
        return wrapper
    }

    private func normalizedSessionID(from uniqueID: Any) -> UUID? {
        if let uuid = uniqueID as? UUID {
            return uuid
        }

        if let string = uniqueID as? String {
            return UUID(uuidString: string)
        }

        if let string = uniqueID as? NSString {
            return UUID(uuidString: string as String)
        }

        return nil
    }
}

@MainActor
extension NSApplication {
    @objc(scriptEditorWindows)
    var scriptEditorWindows: [SwiftTagScriptEditorWindow] {
        SwiftTagAppleScriptController.shared.orderedEditorWindows()
    }

    @objc(scriptDocuments)
    var scriptDocuments: [SwiftTagScriptDocument] {
        SwiftTagAppleScriptController.shared.orderedDocuments()
    }

    @objc(insertInScriptEditorWindows:)
    func insertInScriptEditorWindows(_ value: SwiftTagScriptEditorWindow) {
        SwiftTagAppleScriptController.shared.insertEditorWindow(value)
    }

    @objc(valueInScriptEditorWindowsWithUniqueID:)
    func valueInScriptEditorWindows(withUniqueID uniqueID: Any) -> Any? {
        SwiftTagAppleScriptController.shared.editorWindow(withUniqueID: uniqueID)
    }

    @objc(valueInScriptDocumentsWithUniqueID:)
    func valueInScriptDocuments(withUniqueID uniqueID: Any) -> Any? {
        SwiftTagAppleScriptController.shared.document(withUniqueID: uniqueID)
    }

    func openSwiftTagDocuments(_ urls: [URL]) throws -> [SwiftTagScriptDocument] {
        try SwiftTagAppleScriptController.shared.openDocumentWrappers(at: urls)
    }

    @objc(handleOpenScriptCommand:)
    func handleOpenScriptCommand(_ command: NSScriptCommand) -> Any? {
        do {
            let urls = try SwiftTagAppleScriptFileURLResolver.fileURLs(from: command.directParameter)
            let documents = try openSwiftTagDocuments(urls)
            return documents.count == 1 ? documents[0] : documents
        } catch {
            return command.fail(error)
        }
    }

    @objc(handleQuitScriptCommand:)
    func handleQuitScriptCommand(_ command: NSScriptCommand) -> Any? {
        terminate(nil)
        return nil
    }
}
