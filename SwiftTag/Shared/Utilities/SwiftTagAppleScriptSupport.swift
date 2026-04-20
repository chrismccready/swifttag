import AppKit
import Foundation

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

final class SwiftTagAppleScriptController {
    static let shared = SwiftTagAppleScriptController()

    private var editorWindowsBySessionID: [UUID: SwiftTagScriptEditorWindow] = [:]

    private init() {}

    func orderedEditorWindows() -> [SwiftTagScriptEditorWindow] {
        let liveWindows = orderedLiveEditorWindows()
        let now = Date()
        var orderedWrappers: [SwiftTagScriptEditorWindow] = []
        var liveSessionIDs: Set<UUID> = []

        for (sessionID, window) in liveWindows {
            liveSessionIDs.insert(sessionID)

            let wrapper = editorWindowsBySessionID[sessionID]
                ?? SwiftTagScriptEditorWindow(sessionID: sessionID, liveWindow: window)
            wrapper.updateLiveWindow(window)
            editorWindowsBySessionID[sessionID] = wrapper
            orderedWrappers.append(wrapper)
        }

        var pendingWrappers: [SwiftTagScriptEditorWindow] = []
        for (sessionID, wrapper) in editorWindowsBySessionID where !liveSessionIDs.contains(sessionID) {
            wrapper.updateLiveWindow(nil)
            wrapper.clearExpiredPendingState(referenceDate: now)
            if wrapper.awaitsMaterialization {
                pendingWrappers.append(wrapper)
            } else {
                editorWindowsBySessionID.removeValue(forKey: sessionID)
            }
        }

        pendingWrappers.sort { $0.windowID < $1.windowID }
        return orderedWrappers + pendingWrappers
    }

    func insertEditorWindow(_ scriptWindow: SwiftTagScriptEditorWindow) {
        editorWindowsBySessionID[scriptWindow.sessionID] = scriptWindow
        scriptWindow.markAwaitingMaterialization()
        EditorWindowCoordinator.shared.openEditorWindow(
            for: EditorSessionValue(sessionID: scriptWindow.sessionID)
        )
        synchronizeWindow(for: scriptWindow.sessionID)
    }

    func editorWindow(withUniqueID uniqueID: Any) -> SwiftTagScriptEditorWindow? {
        guard let sessionID = normalizedSessionID(from: uniqueID) else {
            return nil
        }

        _ = orderedEditorWindows()
        return editorWindowsBySessionID[sessionID]
    }

    func indexOfEditorWindow(sessionID: UUID) -> Int? {
        orderedEditorWindows().firstIndex { $0.sessionID == sessionID }
    }

    #if DEBUG
    func resetForTesting() {
        editorWindowsBySessionID.removeAll()
    }
    #endif

    private func synchronizeWindow(for sessionID: UUID) {
        guard let liveWindow = orderedLiveEditorWindows().first(where: { $0.sessionID == sessionID })?.window else {
            return
        }

        let wrapper = editorWindowsBySessionID[sessionID]
            ?? SwiftTagScriptEditorWindow(sessionID: sessionID, liveWindow: liveWindow)
        wrapper.updateLiveWindow(liveWindow)
        editorWindowsBySessionID[sessionID] = wrapper
    }

    private func orderedLiveEditorWindows() -> [(sessionID: UUID, window: NSWindow)] {
        NSApplication.shared.orderedWindows.compactMap { window in
            guard let delegate = window.delegate as? EditorWindowSessionIdentifying else {
                return nil
            }

            return (delegate.editorSessionID, window)
        }
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

extension NSApplication {
    @objc(scriptEditorWindows)
    var scriptEditorWindows: [SwiftTagScriptEditorWindow] {
        SwiftTagAppleScriptController.shared.orderedEditorWindows()
    }

    @objc(insertInScriptEditorWindows:)
    func insertInScriptEditorWindows(_ value: SwiftTagScriptEditorWindow) {
        SwiftTagAppleScriptController.shared.insertEditorWindow(value)
    }

    @objc(valueInScriptEditorWindowsWithUniqueID:)
    func valueInScriptEditorWindows(withUniqueID uniqueID: Any) -> Any? {
        SwiftTagAppleScriptController.shared.editorWindow(withUniqueID: uniqueID)
    }

    @objc(handleQuitScriptCommand:)
    func handleQuitScriptCommand(_ command: NSScriptCommand) -> Any? {
        terminate(nil)
        return nil
    }
}
