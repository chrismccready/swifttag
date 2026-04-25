import AppKit
import Foundation

enum SwiftTagAppleScriptCommandError: LocalizedError, Equatable {
    case editorWindowSaveDestinationUnsupported
    case invalidEditorWindowTarget
    case missingOpenTarget
    case missingAddTracksInput
    case noEditorWindowAvailable
    case noFlacFilesProvided
    case noSwiftTagDocumentsProvided
    case invalidFileValue
    case invalidSaveOptionValue(String)
    case invalidSaveScopeOptionValue(String)
    case invalidSavePayloadOptionValue(String)
    case invalidCloseSaveOptionValue(String)
    case invalidSelectedTrack
    case invalidSaveDestination
    case invalidTagKey
    case invalidTagObject
    case invalidTagTrackTarget
    case saveLocationRequired
    case sessionUnavailable
    case saveAlreadyInProgress
    case trackLocked

    var errorDescription: String? {
        switch self {
        case .editorWindowSaveDestinationUnsupported:
            return "Editor window save does not support an explicit destination. Save document instead."
        case .invalidEditorWindowTarget:
            return "Add command target must resolve to a single editor window."
        case .missingOpenTarget:
            return "Open command requires one or more SwiftTag document files."
        case .missingAddTracksInput:
            return "Add command requires one or more FLAC files."
        case .noEditorWindowAvailable:
            return "Add command needs an available editor window target."
        case .noFlacFilesProvided:
            return "Add command only accepts local FLAC files."
        case .noSwiftTagDocumentsProvided:
            return "No .swifttag documents were provided."
        case .invalidFileValue:
            return "AppleScript file argument must resolve to a local file URL."
        case let .invalidSaveOptionValue(optionName):
            return "Save option \(optionName) must be true or false."
        case let .invalidSaveScopeOptionValue(optionName):
            return "Save scope option \(optionName) must be all or selected."
        case let .invalidSavePayloadOptionValue(optionName):
            return "Save payload option \(optionName) must be tags only or pictures only or tags and pictures."
        case let .invalidCloseSaveOptionValue(optionName):
            return "Close save option \(optionName) must be yes, no, or ask."
        case .invalidSelectedTrack:
            return "Selected tracks must belong to target editor window."
        case .invalidSaveDestination:
            return "Save destination must be a single local file URL."
        case .invalidTagKey:
            return "Tag key must resolve to non-empty text without internal whitespace."
        case .invalidTagObject:
            return "Tag mutations require a tag object or record with key and value."
        case .invalidTagTrackTarget:
            return "Tag command target must resolve to a track in the current editor window."
        case .saveLocationRequired:
            return "Save command needs an existing SwiftTag document or an explicit destination file."
        case .sessionUnavailable:
            return "Target editor window is not available for AppleScript save."
        case .saveAlreadyInProgress:
            return "Save command cannot run while another save operation is already running."
        case .trackLocked:
            return "Target track is locked for editing."
        }
    }

    var scriptErrorNumber: Int {
        switch self {
        case .missingOpenTarget, .missingAddTracksInput:
            Int(NSRequiredArgumentsMissingScriptError)
        case .editorWindowSaveDestinationUnsupported,
             .invalidEditorWindowTarget,
             .noFlacFilesProvided,
             .noSwiftTagDocumentsProvided,
             .invalidFileValue,
             .invalidSaveOptionValue,
             .invalidSaveScopeOptionValue,
             .invalidSavePayloadOptionValue,
             .invalidCloseSaveOptionValue,
             .invalidSelectedTrack,
             .invalidSaveDestination,
             .invalidTagKey,
             .invalidTagObject,
             .invalidTagTrackTarget,
             .saveLocationRequired:
            Int(NSArgumentsWrongScriptError)
        case .noEditorWindowAvailable, .sessionUnavailable, .trackLocked:
            Int(NSReceiversCantHandleCommandScriptError)
        case .saveAlreadyInProgress:
            Int(NSInternalScriptError)
        }
    }
}

private enum SwiftTagAppleScriptFileURLResolver {
    nonisolated static func fileURLs(
        from value: Any?,
        missingValueError: SwiftTagAppleScriptCommandError = .missingOpenTarget
    ) throws -> [URL] {
        guard let value else {
            throw missingValueError
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

struct SwiftTagAppleScriptFlacSaveRequest: Equatable {
    let payload: SavePayloadOption?
    let scope: SaveScopeOption?

    static let defaults = Self(payload: nil, scope: nil)

    static func from(arguments: [String: Any]?) throws -> Self {
        let scope = try SaveScopeOption.appleScriptValue(
            from: SwiftTagAppleScriptArgumentValue.value(
                keys: ["SaveScopeOptions", "scope", "with scope", "saving scope"],
                in: arguments
            ),
            optionName: "scope"
        )
        let payload = try SavePayloadOption.appleScriptValue(
            from: SwiftTagAppleScriptArgumentValue.value(
                keys: ["SavePayloadOptions", "payload", "with payload", "saving payload"],
                in: arguments
            ),
            optionName: "payload"
        )

        return Self(payload: payload, scope: scope)
    }
}

enum SwiftTagAppleScriptCloseSaveOption: Equatable {
    case yes
    case no
    case ask

    static func from(_ rawValue: Any?, optionName: String = "saving") throws -> Self? {
        guard let token = SwiftTagAppleScriptEnumerationToken.normalized(from: rawValue) else {
            return nil
        }

        switch token {
        case "yes":
            return .yes
        case "no":
            return .no
        case "ask":
            return .ask
        default:
            throw SwiftTagAppleScriptCommandError.invalidCloseSaveOptionValue(optionName)
        }
    }
}

struct SwiftTagAppleScriptCloseRequest: Equatable {
    let saveOption: SwiftTagAppleScriptCloseSaveOption?
    let destinationURL: URL?
    let flacSaveRequest: SwiftTagAppleScriptFlacSaveRequest

    static let defaults = Self(
        saveOption: nil,
        destinationURL: nil,
        flacSaveRequest: .defaults
    )

    static func from(arguments: [String: Any]?) throws -> Self {
        let saveOption = try SwiftTagAppleScriptCloseSaveOption.from(
            SwiftTagAppleScriptArgumentValue.value(
                keys: ["SaveOptions", "saving"],
                in: arguments
            )
        )
        let destinationURL = try SwiftTagAppleScriptFileURLResolver.singleFileURL(
            from: SwiftTagAppleScriptArgumentValue.value(
                keys: ["File", "file", "saving in", "in"],
                in: arguments
            )
        )
        let flacSaveRequest = try SwiftTagAppleScriptFlacSaveRequest.from(arguments: arguments)

        return Self(
            saveOption: saveOption,
            destinationURL: destinationURL,
            flacSaveRequest: flacSaveRequest
        )
    }
}

private enum SwiftTagAppleScriptArgumentValue {
    static func value(
        keys: [String],
        in arguments: [String: Any]?
    ) -> Any? {
        guard let arguments else {
            return nil
        }

        for key in keys {
            if let value = arguments[key] {
                return value
            }
        }

        let normalizedKeys = Set(keys.map { $0.lowercased() })
        return arguments.first { normalizedKeys.contains($0.key.lowercased()) }?.value
    }
}

private enum SwiftTagAppleScriptEnumerationToken {
    static func normalized(from rawValue: Any?) -> String? {
        guard let rawValue else {
            return nil
        }

        if let descriptor = rawValue as? NSAppleEventDescriptor {
            if descriptor.descriptorType == typeEnumerated {
                return normalized(fourCharCodeString(descriptor.enumCodeValue))
            }
            if let stringValue = descriptor.stringValue {
                return normalized(stringValue)
            }
        }

        if let string = rawValue as? String {
            return normalized(string)
        }

        if let string = rawValue as? NSString {
            return normalized(string as String)
        }

        if let number = rawValue as? NSNumber {
            return normalized(fourCharCodeString(number.uint32Value))
        }

        return normalized(String(describing: rawValue))
    }

    private static func normalized(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private static func fourCharCodeString(_ code: FourCharCode) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        return String(bytes: bytes, encoding: .macOSRoman) ?? ""
    }
}

private extension SaveScopeOption {
    static func appleScriptValue(from rawValue: Any?, optionName: String) throws -> Self? {
        guard let token = SwiftTagAppleScriptEnumerationToken.normalized(from: rawValue) else {
            return nil
        }

        switch token {
        case "altr":
            return .allTracks
        case "sltr":
            return .selectedTracks
        default:
            throw SwiftTagAppleScriptCommandError.invalidSaveScopeOptionValue(optionName)
        }
    }
}

private extension SavePayloadOption {
    static func appleScriptValue(from rawValue: Any?, optionName: String) throws -> Self? {
        guard let token = SwiftTagAppleScriptEnumerationToken.normalized(from: rawValue) else {
            return nil
        }

        switch token {
        case "tgos":
            return .writeTags
        case "pcos":
            return .writePictures
        case "tpos":
            return .writeTagsAndPictures
        default:
            throw SwiftTagAppleScriptCommandError.invalidSavePayloadOptionValue(optionName)
        }
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

struct SwiftTagAppleScriptSessionSnapshot {
    let tracks: [Track]
    let selectedTrackIDs: Set<UUID>
}

struct SwiftTagAppleScriptSessionBridge {
    let documentSnapshot: () -> SwiftTagAppleScriptDocumentSnapshot
    let sessionSnapshot: () -> SwiftTagAppleScriptSessionSnapshot
    let addTracks: ([URL]) throws -> [UUID]
    let selectTracks: (Set<UUID>) throws -> Void
    let saveDocument: (URL?) throws -> SwiftTagDocumentSaveState
    let saveTracks: (SwiftTagAppleScriptFlacSaveRequest) throws -> SaveOperationResult
    let upsertTag: (UUID, String, String) throws -> Void
    let deleteTag: (UUID, String) throws -> Void

    init(
        documentSnapshot: @escaping () -> SwiftTagAppleScriptDocumentSnapshot,
        sessionSnapshot: @escaping () -> SwiftTagAppleScriptSessionSnapshot,
        addTracks: @escaping ([URL]) throws -> [UUID],
        selectTracks: @escaping (Set<UUID>) throws -> Void,
        saveDocument: @escaping (URL?) throws -> SwiftTagDocumentSaveState,
        saveTracks: @escaping (SwiftTagAppleScriptFlacSaveRequest) throws -> SaveOperationResult = { _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        upsertTag: @escaping (UUID, String, String) throws -> Void = { _, _, _ in },
        deleteTag: @escaping (UUID, String) throws -> Void = { _, _ in }
    ) {
        self.documentSnapshot = documentSnapshot
        self.sessionSnapshot = sessionSnapshot
        self.addTracks = addTracks
        self.selectTracks = selectTracks
        self.saveDocument = saveDocument
        self.saveTracks = saveTracks
        self.upsertTag = upsertTag
        self.deleteTag = deleteTag
    }
}

private extension String {
    var appleScriptNonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

private extension Track {
    func appleScriptText(for keys: [String]) -> String? {
        firstTagValue(for: keys)
    }

    func appleScriptInteger(for keys: [String], fallback: String? = nil) -> NSNumber? {
        let rawValue = fallback?.appleScriptNonEmptyValue ?? firstTagValue(for: keys)
        guard let rawValue, let integerValue = Int(rawValue) else {
            return nil
        }

        return NSNumber(value: integerValue)
    }

    func appleScriptBoolean(for keys: [String]) -> NSNumber? {
        guard let rawValue = firstTagValue(for: keys)?.lowercased() else {
            return nil
        }

        switch rawValue {
        case "1", "t", "true", "on", "y", "yes":
            return NSNumber(value: true)
        case "0", "f", "false", "off", "n", "no":
            return NSNumber(value: false)
        default:
            return nil
        }
    }

    func appleScriptDate(for keys: [String]) -> Date? {
        DateTagFormatter.parse(firstTagValue(for: keys))
    }

    func appleScriptReal(for keys: [String], fallback: TimeInterval? = nil) -> NSNumber? {
        if let fallback, fallback.isFinite, fallback >= 0 {
            return NSNumber(value: fallback)
        }

        guard let rawValue = firstTagValue(for: keys), let realValue = Double(rawValue) else {
            return nil
        }

        return NSNumber(value: realValue)
    }

    private func firstTagValue(for keys: [String]) -> String? {
        for key in keys {
            if let value = tags[key]?.appleScriptNonEmptyValue {
                return value
            }
        }

        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}

struct SwiftTagAppleScriptTagSnapshot: Equatable {
    let key: String
    let value: String
}

@MainActor
enum SwiftTagAppleScriptTagKey {
    static let totalDiscs = "TOTALDISCS"
    static let totalTracks = "TOTALTRACKS"

    static func normalizedKey(_ rawKey: String) -> String {
        switch TagNormalization.normalizeTagKey(rawKey) {
        case "DISC":
            TagKey.discNumber
        case "DISCTOTAL":
            totalDiscs
        case "TRACK":
            TagKey.trackNumber
        case "TRACKTOTAL":
            totalTracks
        default:
            TagNormalization.normalizeTagKey(rawKey)
        }
    }

    static func relatedKeys(for rawKey: String) -> [String] {
        switch normalizedKey(rawKey) {
        case TagKey.discNumber:
            [TagKey.discNumber, "DISC"]
        case totalDiscs:
            [totalDiscs, "DISCTOTAL"]
        case TagKey.trackNumber:
            [TagKey.trackNumber, "TRACK"]
        case totalTracks:
            [totalTracks, "TRACKTOTAL"]
        default:
            [normalizedKey(rawKey)]
        }
    }

    static func normalizedValue(_ rawValue: String) -> String {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmedValue).map(String.init) ?? trimmedValue
    }

    static func snapshots(for track: Track) -> [SwiftTagAppleScriptTagSnapshot] {
        var tagsByKey: [String: String] = [:]

        for (rawKey, rawValue) in track.tags {
            let key = normalizedKey(rawKey)
            guard !key.isEmpty, key != TagKey.filename else {
                continue
            }

            let value = normalizedValue(rawValue)
            guard !value.isEmpty else {
                continue
            }

            if key == TagKey.compilation {
                guard let normalizedCompilation = CompilationTag.normalizedValue(value) else {
                    continue
                }
                tagsByKey[key] = normalizedCompilation
                continue
            }

            tagsByKey[key] = value
        }

        if let album = track.album.appleScriptNonEmptyValue {
            tagsByKey[TagKey.album] = album
        } else {
            tagsByKey.removeValue(forKey: TagKey.album)
        }

        if let albumArtist = track.albumArtist.appleScriptNonEmptyValue {
            tagsByKey[TagKey.albumArtist] = albumArtist
        } else {
            tagsByKey.removeValue(forKey: TagKey.albumArtist)
        }

        if let totalTracks = track.totalTracks.appleScriptNonEmptyValue.map(normalizedValue(_:)) {
            tagsByKey[Self.totalTracks] = totalTracks
        } else {
            tagsByKey.removeValue(forKey: Self.totalTracks)
        }

        let totalDiscValue = relatedKeys(for: totalDiscs)
            .compactMap { track.tags[$0]?.appleScriptNonEmptyValue }
            .map(normalizedValue(_:))
            .first
        if let totalDiscValue {
            tagsByKey[totalDiscs] = totalDiscValue
        } else {
            tagsByKey.removeValue(forKey: totalDiscs)
        }

        return tagsByKey.keys
            .sorted()
            .compactMap { key in
                guard let value = tagsByKey[key], !value.isEmpty else {
                    return nil
                }

                return SwiftTagAppleScriptTagSnapshot(key: key, value: value)
            }
    }
}

private struct SwiftTagAppleScriptTagPayload {
    let key: String
    let value: String

    static func from(value rawValue: Any) throws -> Self {
        if let tag = rawValue as? SwiftTagScriptTag {
            return try make(key: tag.key, value: tag.value)
        }

        if let dictionary = rawValue as? [AnyHashable: Any] {
            return try from(dictionary: dictionary)
        }

        if let dictionary = rawValue as? NSDictionary {
            var bridgedDictionary: [AnyHashable: Any] = [:]
            for case let (key as AnyHashable, value) in dictionary {
                bridgedDictionary[key] = value
            }
            return try from(dictionary: bridgedDictionary)
        }

        throw SwiftTagAppleScriptCommandError.invalidTagObject
    }

    static func make(key: String?, value: String?) throws -> Self {
        let normalizedKey = SwiftTagAppleScriptTagKey.normalizedKey(key ?? "")
        guard !normalizedKey.isEmpty else {
            throw SwiftTagAppleScriptCommandError.invalidTagKey
        }

        return Self(
            key: normalizedKey,
            value: SwiftTagAppleScriptTagKey.normalizedValue(value ?? "")
        )
    }

    private static func from(dictionary: [AnyHashable: Any]) throws -> Self {
        let keyValue = dictionary.first { normalizedPropertyName($0.key) == "key" }?.value
        let tagValue = dictionary.first { normalizedPropertyName($0.key) == "value" }?.value
        return try make(
            key: stringValue(from: keyValue),
            value: stringValue(from: tagValue)
        )
    }

    private static func normalizedPropertyName(_ rawKey: AnyHashable) -> String {
        String(describing: rawKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func stringValue(from rawValue: Any?) -> String? {
        switch rawValue {
        case let value as String:
            value
        case let value as NSString:
            value as String
        case let value as NSNumber:
            value.stringValue
        case let value as URL:
            value.absoluteString
        case nil:
            nil
        default:
            String(describing: rawValue!)
        }
    }
}

@MainActor
@objc(SwiftTagScriptTag)
final class SwiftTagScriptTag: NSObject {
    private enum Storage {
        case attached(sessionID: UUID, trackID: UUID, key: String)
        case detached(SwiftTagAppleScriptTagSnapshot)
    }

    private var storage: Storage

    @objc
    override init() {
        storage = .detached(.init(key: "", value: ""))
        super.init()
    }

    init(key: String, value: String) {
        storage = .detached(.init(key: key, value: value))
        super.init()
    }

    init(sessionID: UUID, trackID: UUID, key: String) {
        storage = .attached(
            sessionID: sessionID,
            trackID: trackID,
            key: SwiftTagAppleScriptTagKey.normalizedKey(key)
        )
        super.init()
    }

    @objc(key)
    var key: String? {
        get {
            snapshot?.key.appleScriptNonEmptyValue
        }
        set {
            do {
                try updateKey(newValue)
            } catch {
                _ = NSScriptCommand.current()?.fail(error)
            }
        }
    }

    @objc(value)
    var value: String? {
        get {
            snapshot?.value
        }
        set {
            do {
                try updateValue(newValue)
            } catch {
                _ = NSScriptCommand.current()?.fail(error)
            }
        }
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard case let .attached(sessionID, trackID, key) = storage,
              let track = SwiftTagAppleScriptController.shared.track(
                forSessionID: sessionID,
                trackID: trackID
              ),
              let trackClassDescription = NSScriptClassDescription(for: SwiftTagScriptTrack.self),
              let containerSpecifier = track.objectSpecifier,
              let uniqueID = snapshot(forAttachedKey: key)?.key else {
            return nil
        }

        return NSUniqueIDSpecifier(
            containerClassDescription: trackClassDescription,
            containerSpecifier: containerSpecifier,
            key: "tags",
            uniqueID: uniqueID
        )
    }

    private var snapshot: SwiftTagAppleScriptTagSnapshot? {
        switch storage {
        case .attached(_, _, let key):
            snapshot(forAttachedKey: key)
        case .detached(let snapshot):
            snapshot
        }
    }

    private func snapshot(forAttachedKey key: String) -> SwiftTagAppleScriptTagSnapshot? {
        guard case let .attached(sessionID, trackID, _) = storage else {
            return nil
        }

        return SwiftTagAppleScriptController.shared.tagSnapshot(
            forSessionID: sessionID,
            trackID: trackID,
            key: key
        )
    }

    private func updateKey(_ newValue: String?) throws {
        switch storage {
        case .attached(let sessionID, let trackID, let currentKey):
            let payload = try SwiftTagAppleScriptTagPayload.make(
                key: newValue,
                value: snapshot?.value
            )
            if payload.key == currentKey {
                return
            }

            try SwiftTagAppleScriptController.shared.upsertTag(
                key: payload.key,
                value: payload.value,
                forSessionID: sessionID,
                trackID: trackID
            )
            try SwiftTagAppleScriptController.shared.deleteTag(
                key: currentKey,
                forSessionID: sessionID,
                trackID: trackID
            )
            storage = .attached(sessionID: sessionID, trackID: trackID, key: payload.key)
        case .detached(let snapshot):
            let payload = try SwiftTagAppleScriptTagPayload.make(
                key: newValue,
                value: snapshot.value
            )
            storage = .detached(.init(key: payload.key, value: payload.value))
        }
    }

    private func updateValue(_ newValue: String?) throws {
        switch storage {
        case .attached(let sessionID, let trackID, let currentKey):
            try SwiftTagAppleScriptController.shared.upsertTag(
                key: currentKey,
                value: SwiftTagAppleScriptTagKey.normalizedValue(newValue ?? ""),
                forSessionID: sessionID,
                trackID: trackID
            )
        case .detached(let snapshot):
            storage = .detached(
                .init(
                    key: snapshot.key,
                    value: SwiftTagAppleScriptTagKey.normalizedValue(newValue ?? "")
                )
            )
        }
    }
}

@MainActor
@objc(SwiftTagScriptTrack)
final class SwiftTagScriptTrack: NSObject {
    private let sessionIDValue: UUID
    private let trackIDValue: UUID

    init(sessionID: UUID, trackID: UUID) {
        sessionIDValue = sessionID
        trackIDValue = trackID
        super.init()
    }

    @objc(album)
    var album: String? {
        get {
            currentTextValue(for: [TagKey.album], fallback: \.album)
        }
        set {
            updateTagValue(TagKey.album, to: newValue)
        }
    }

    @objc(albumArtist)
    var albumArtist: String? {
        get {
            currentTextValue(for: [TagKey.albumArtist], fallback: \.albumArtist)
        }
        set {
            updateTagValue(TagKey.albumArtist, to: newValue)
        }
    }

    @objc(artist)
    var artist: String? {
        get {
            currentTextValue(for: [TagKey.artist])
        }
        set {
            updateTagValue(TagKey.artist, to: newValue)
        }
    }

    @objc(bitsPerSample)
    var bitsPerSample: NSNumber? {
        guard let bitsPerSample = trackSnapshot?.bitsPerSample else {
            return nil
        }

        return NSNumber(value: Int(bitsPerSample))
    }

    @objc(channels)
    var channels: NSNumber? {
        guard let channels = trackSnapshot?.channels else {
            return nil
        }

        return NSNumber(value: Int(channels))
    }

    @objc(comment)
    var comment: String? {
        get {
            currentTextValue(for: ["COMMENT"])
        }
        set {
            updateTagValue("COMMENT", to: newValue)
        }
    }

    @objc(compilation)
    var compilation: NSNumber? {
        get {
            currentBooleanValue(for: [TagKey.compilation])
        }
        set {
            updateTagValue(TagKey.compilation, to: newValue)
        }
    }

    @objc(composer)
    var composer: String? {
        get {
            currentTextValue(for: [TagKey.composer])
        }
        set {
            updateTagValue(TagKey.composer, to: newValue)
        }
    }

    @objc(copyright)
    var copyright: String? {
        get {
            currentTextValue(for: ["COPYRIGHT"])
        }
        set {
            updateTagValue("COPYRIGHT", to: newValue)
        }
    }

    @objc(releaseDate)
    var releaseDate: Date? {
        get {
            currentDateValue(for: [TagKey.date])
        }
        set {
            updateTagValue(TagKey.date, to: newValue)
        }
    }

    @objc(trackDescription)
    var trackDescription: String? {
        get {
            currentTextValue(for: [TagKey.description])
        }
        set {
            updateTagValue(TagKey.description, to: newValue)
        }
    }

    @objc(director)
    var director: String? {
        get {
            currentTextValue(for: ["DIRECTOR"])
        }
        set {
            updateTagValue("DIRECTOR", to: newValue)
        }
    }

    @objc(discCount)
    var discCount: NSNumber? {
        get {
            currentIntegerValue(for: ["DISCTOTAL", "TOTALDISCS"])
        }
        set {
            updateTagValue(SwiftTagAppleScriptTagKey.totalDiscs, to: newValue)
        }
    }

    @objc(discNumber)
    var discNumber: NSNumber? {
        get {
            currentIntegerValue(for: [TagKey.discNumber, "DISC"])
        }
        set {
            updateTagValue(TagKey.discNumber, to: newValue)
        }
    }

    @objc(duration)
    var duration: NSNumber? {
        currentRealValue(for: ["DURATION", "LENGTH"], fallback: \.duration)
    }

    @objc(encodedBy)
    var encodedBy: String? {
        get {
            currentTextValue(for: ["ENCODED_BY"])
        }
        set {
            updateTagValue("ENCODED_BY", to: newValue)
        }
    }

    @objc(encodedUsing)
    var encodedUsing: String? {
        get {
            currentTextValue(for: ["ENCODED_USING"])
        }
        set {
            updateTagValue("ENCODED_USING", to: newValue)
        }
    }

    @objc(encoder)
    var encoder: String? {
        get {
            currentTextValue(for: ["ENCODER"])
        }
        set {
            updateTagValue("ENCODER", to: newValue)
        }
    }

    @objc(encoderOptions)
    var encoderOptions: String? {
        get {
            currentTextValue(for: ["ENCODER_OPTIONS"])
        }
        set {
            updateTagValue("ENCODER_OPTIONS", to: newValue)
        }
    }

    @objc(fileURL)
    var fileURL: URL? {
        trackSnapshot?.sourceFileURL?.standardizedFileURL
    }

    @objc(tags)
    var tags: [SwiftTagScriptTag] {
        SwiftTagAppleScriptController.shared.tags(
            forSessionID: sessionIDValue,
            trackID: trackIDValue
        )
    }

    @objc(countOfTags)
    var countOfTags: Int {
        tags.count
    }

    @objc(objectInTagsAtIndex:)
    func objectInTags(at index: Int) -> SwiftTagScriptTag {
        tags[index]
    }

    @objc(valueInTagsWithUniqueID:)
    func valueInTags(withUniqueID uniqueID: Any) -> Any? {
        SwiftTagAppleScriptController.shared.tag(
            forSessionID: sessionIDValue,
            trackID: trackIDValue,
            uniqueID: uniqueID
        )
    }

    @objc(insertObject:inTagsAtIndex:)
    func insertObject(_ value: Any, inTagsAt index: Int) {
        do {
            let payload = try SwiftTagAppleScriptTagPayload.from(value: value)
            try SwiftTagAppleScriptController.shared.upsertTag(
                key: payload.key,
                value: payload.value,
                forSessionID: sessionIDValue,
                trackID: trackIDValue
            )
        } catch {
            _ = NSScriptCommand.current()?.fail(error)
        }
    }

    @objc(removeObjectFromTagsAtIndex:)
    func removeObjectFromTags(at index: Int) {
        guard let tag = tags[safe: index],
              let key = tag.key else {
            return
        }

        do {
            try SwiftTagAppleScriptController.shared.deleteTag(
                key: key,
                forSessionID: sessionIDValue,
                trackID: trackIDValue
            )
        } catch {
            _ = NSScriptCommand.current()?.fail(error)
        }
    }

    @objc(replaceObjectInTagsAtIndex:withObject:)
    func replaceObjectInTags(at index: Int, with value: Any) {
        do {
            let replacement = try SwiftTagAppleScriptTagPayload.from(value: value)
            let existingKey = tags[safe: index]?.key
            if let existingKey,
               existingKey != replacement.key {
                try SwiftTagAppleScriptController.shared.deleteTag(
                    key: existingKey,
                    forSessionID: sessionIDValue,
                    trackID: trackIDValue
                )
            }

            try SwiftTagAppleScriptController.shared.upsertTag(
                key: replacement.key,
                value: replacement.value,
                forSessionID: sessionIDValue,
                trackID: trackIDValue
            )
        } catch {
            _ = NSScriptCommand.current()?.fail(error)
        }
    }

    @objc(fingerprint)
    var fingerprint: String? {
        guard let trackSnapshot else {
            return nil
        }

        return try? SwiftTagDocumentPackageWriter.trackTagsAndPicturesFingerprint(
            tags: trackSnapshot.tags,
            pictures: trackSnapshot.flacPictureRecords
        )
    }

    @objc(flacFingerprint)
    var flacFingerprint: String? {
        trackSnapshot?.fingerprint?.appleScriptNonEmptyValue
    }

    @objc(genre)
    var genre: String? {
        get {
            currentTextValue(for: [TagKey.genre])
        }
        set {
            updateTagValue(TagKey.genre, to: newValue)
        }
    }

    @objc(isrc)
    var isrc: String? {
        get {
            currentTextValue(for: ["ISRC"])
        }
        set {
            updateTagValue("ISRC", to: newValue)
        }
    }

    @objc(license)
    var license: String? {
        get {
            currentTextValue(for: ["LICENSE"])
        }
        set {
            updateTagValue("LICENSE", to: newValue)
        }
    }

    @objc(lineage)
    var lineage: String? {
        get {
            currentTextValue(for: ["LINEAGE"])
        }
        set {
            updateTagValue("LINEAGE", to: newValue)
        }
    }

    @objc(location)
    var location: String? {
        get {
            currentTextValue(for: [TagKey.location])
        }
        set {
            updateTagValue(TagKey.location, to: newValue)
        }
    }

    @objc(narrator)
    var narrator: String? {
        get {
            currentTextValue(for: ["NARRATOR"])
        }
        set {
            updateTagValue("NARRATOR", to: newValue)
        }
    }

    @objc(performer)
    var performer: String? {
        get {
            currentTextValue(for: ["PERFORMER"])
        }
        set {
            updateTagValue("PERFORMER", to: newValue)
        }
    }

    @objc(producer)
    var producer: String? {
        get {
            currentTextValue(for: ["PRODUCER"])
        }
        set {
            updateTagValue("PRODUCER", to: newValue)
        }
    }

    @objc(rating)
    var rating: NSNumber? {
        get {
            currentIntegerValue(for: ["RATING", "RATE"])
        }
        set {
            updateTagValue("RATING", to: newValue)
        }
    }

    @objc(replayAlbumGain)
    var replayAlbumGain: String? {
        get {
            currentTextValue(for: ["REPLAYGAIN_ALBUM_GAIN"])
        }
        set {
            updateTagValue("REPLAYGAIN_ALBUM_GAIN", to: newValue)
        }
    }

    @objc(replayAlbumPeak)
    var replayAlbumPeak: String? {
        get {
            currentTextValue(for: ["REPLAYGAIN_ALBUM_PEAK"])
        }
        set {
            updateTagValue("REPLAYGAIN_ALBUM_PEAK", to: newValue)
        }
    }

    @objc(replayTrackGain)
    var replayTrackGain: String? {
        get {
            currentTextValue(for: ["REPLAYGAIN_TRACK_GAIN"])
        }
        set {
            updateTagValue("REPLAYGAIN_TRACK_GAIN", to: newValue)
        }
    }

    @objc(replayTrackPeak)
    var replayTrackPeak: String? {
        get {
            currentTextValue(for: ["REPLAYGAIN_TRACK_PEAK"])
        }
        set {
            updateTagValue("REPLAYGAIN_TRACK_PEAK", to: newValue)
        }
    }

    @objc(sampleRate)
    var sampleRate: String? {
        guard let sampleRate = trackSnapshot?.sampleRate else {
            return nil
        }

        return TrackSampleRateFormatter.string(from: sampleRate)
    }

    @objc(sortAlbum)
    var sortAlbum: String? {
        get {
            currentTextValue(for: ["ALBUMSORT"])
        }
        set {
            updateTagValue("ALBUMSORT", to: newValue)
        }
    }

    @objc(sortAlbumArtist)
    var sortAlbumArtist: String? {
        get {
            currentTextValue(for: ["ALBUMARTISTSORT"])
        }
        set {
            updateTagValue("ALBUMARTISTSORT", to: newValue)
        }
    }

    @objc(sortArtist)
    var sortArtist: String? {
        get {
            currentTextValue(for: ["ARTISTSORT"])
        }
        set {
            updateTagValue("ARTISTSORT", to: newValue)
        }
    }

    @objc(sortComposer)
    var sortComposer: String? {
        get {
            currentTextValue(for: ["COMPOSERSORT"])
        }
        set {
            updateTagValue("COMPOSERSORT", to: newValue)
        }
    }

    @objc(sortTitle)
    var sortTitle: String? {
        get {
            currentTextValue(for: ["TITLESORT"])
        }
        set {
            updateTagValue("TITLESORT", to: newValue)
        }
    }

    @objc(source)
    var source: String? {
        get {
            currentTextValue(for: ["SOURCE"])
        }
        set {
            updateTagValue("SOURCE", to: newValue)
        }
    }

    @objc(title)
    var title: String? {
        get {
            currentTextValue(for: [TagKey.title])
        }
        set {
            updateTagValue(TagKey.title, to: newValue)
        }
    }

    @objc(totalSamples)
    var totalSamples: NSNumber? {
        guard let totalSamples = trackSnapshot?.totalSamples else {
            return nil
        }

        let realValue = Double(totalSamples)
        guard realValue.isFinite else {
            return nil
        }

        return NSNumber(value: realValue)
    }

    @objc(trackCount)
    var trackCount: NSNumber? {
        get {
            currentIntegerValue(for: ["TOTALTRACKS", "TRACKTOTAL"], fallback: \.totalTracks)
        }
        set {
            updateTagValue(SwiftTagAppleScriptTagKey.totalTracks, to: newValue)
        }
    }

    @objc(trackNumber)
    var trackNumber: NSNumber? {
        get {
            currentIntegerValue(for: [TagKey.trackNumber, "TRACK"])
        }
        set {
            updateTagValue(TagKey.trackNumber, to: newValue)
        }
    }

    @objc(vendor)
    var vendor: String? {
        get {
            currentTextValue(for: ["VENDOR"])
        }
        set {
            updateTagValue("VENDOR", to: newValue)
        }
    }

    @objc(trackVersion)
    var trackVersion: String? {
        get {
            currentTextValue(for: ["VERSION"])
        }
        set {
            updateTagValue("VERSION", to: newValue)
        }
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let editorWindow = SwiftTagAppleScriptController.shared.editorWindow(forSessionID: sessionIDValue),
              let editorWindowClassDescription = NSScriptClassDescription(for: SwiftTagScriptEditorWindow.self),
              let containerSpecifier = editorWindow.objectSpecifier,
              let index = SwiftTagAppleScriptController.shared.indexOfTrack(
                trackID: trackIDValue,
                forSessionID: sessionIDValue
              ) else {
            return nil
        }

        return NSIndexSpecifier(
            containerClassDescription: editorWindowClassDescription,
            containerSpecifier: containerSpecifier,
            key: "tracks",
            index: index
        )
    }

    fileprivate var sessionID: UUID {
        sessionIDValue
    }

    fileprivate var trackID: UUID {
        trackIDValue
    }

    private var trackSnapshot: Track? {
        SwiftTagAppleScriptController.shared.trackSnapshot(
            forSessionID: sessionIDValue,
            trackID: trackIDValue
        )
    }

    private func currentTextValue(
        for keys: [String],
        fallback: KeyPath<Track, String>? = nil
    ) -> String? {
        guard let trackSnapshot else {
            return nil
        }

        if let fallback, let fallbackValue = trackSnapshot[keyPath: fallback].appleScriptNonEmptyValue {
            return fallbackValue
        }

        return trackSnapshot.appleScriptText(for: keys)
    }

    private func currentIntegerValue(
        for keys: [String],
        fallback: KeyPath<Track, String>? = nil
    ) -> NSNumber? {
        guard let trackSnapshot else {
            return nil
        }

        let fallbackValue = fallback.map { trackSnapshot[keyPath: $0] }
        return trackSnapshot.appleScriptInteger(for: keys, fallback: fallbackValue)
    }

    private func currentBooleanValue(for keys: [String]) -> NSNumber? {
        trackSnapshot?.appleScriptBoolean(for: keys)
    }

    private func currentDateValue(for keys: [String]) -> Date? {
        trackSnapshot?.appleScriptDate(for: keys)
    }

    private func currentRealValue(
        for keys: [String],
        fallback: KeyPath<Track, TimeInterval?>? = nil
    ) -> NSNumber? {
        guard let trackSnapshot else {
            return nil
        }

        let fallbackValue = fallback.map { trackSnapshot[keyPath: $0] } ?? nil
        return trackSnapshot.appleScriptReal(for: keys, fallback: fallbackValue)
    }

    private func updateTagValue(_ key: String, to rawValue: Any?) {
        do {
            try SwiftTagAppleScriptController.shared.upsertTag(
                key: key,
                value: scriptTagString(from: rawValue),
                forSessionID: sessionIDValue,
                trackID: trackIDValue
            )
        } catch {
            _ = NSScriptCommand.current()?.fail(error)
        }
    }

    private func scriptTagString(from rawValue: Any?) -> String {
        switch rawValue {
        case let value as String:
            value
        case let value as NSString:
            value as String
        case let value as NSNumber:
            value.stringValue
        case let value as Date:
            DateTagFormatter.format(value)
        case let value as NSDate:
            DateTagFormatter.format(value as Date)
        case nil:
            ""
        default:
            String(describing: rawValue!)
        }
    }
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

    @objc(selectedTracks)
    var selectedTracks: [SwiftTagScriptTrack] {
        get {
            SwiftTagAppleScriptController.shared.selectedTrackObjects(forSessionID: sessionIDValue)
        }
        set {
            do {
                try SwiftTagAppleScriptController.shared.setSelectedTracks(
                    newValue,
                    forSessionID: sessionIDValue
                )
            } catch {
                _ = NSScriptCommand.current()?.fail(error)
            }
        }
    }

    @objc(countOfSelectedTracks)
    var countOfSelectedTracks: Int {
        SwiftTagAppleScriptController.shared.selectedTrackObjects(forSessionID: sessionIDValue).count
    }

    @objc(objectInSelectedTracksAtIndex:)
    func objectInSelectedTracks(at index: Int) -> SwiftTagScriptTrack {
        SwiftTagAppleScriptController.shared.selectedTrackObjects(forSessionID: sessionIDValue)[index]
    }

    override func setValue(_ value: Any?, forKey key: String) {
        guard key == "selectedTracks" else {
            super.setValue(value, forKey: key)
            return
        }

        do {
            try SwiftTagAppleScriptController.shared.setSelectedTracks(
                normalizedScriptTracks(from: value),
                forSessionID: sessionIDValue
            )
        } catch {
            _ = NSScriptCommand.current()?.fail(error)
        }
    }

    @objc(tracks)
    var tracks: [SwiftTagScriptTrack] {
        SwiftTagAppleScriptController.shared.tracks(forSessionID: sessionIDValue)
    }

    @objc(countOfTracks)
    var countOfTracks: Int {
        tracks.count
    }

    @objc(objectInTracksAtIndex:)
    func objectInTracks(at index: Int) -> SwiftTagScriptTrack {
        tracks[index]
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

    func saveFlacFiles(
        using request: SwiftTagAppleScriptFlacSaveRequest = .init(payload: nil, scope: nil)
    ) throws -> SaveOperationResult {
        try SwiftTagAppleScriptController.shared.saveTracks(
            forSessionID: sessionIDValue,
            request: request
        )
    }

    func close(
        using request: SwiftTagAppleScriptCloseRequest = .init(
            saveOption: nil,
            destinationURL: nil,
            flacSaveRequest: .init(payload: nil, scope: nil)
        )
    ) throws {
        let saveOption = request.saveOption ?? .ask
        if request.destinationURL != nil, saveOption != .no {
            throw SwiftTagAppleScriptCommandError.editorWindowSaveDestinationUnsupported
        }

        switch saveOption {
        case .yes:
            if document.modified {
                _ = try saveFlacFiles(using: request.flacSaveRequest)
            }
            try SwiftTagAppleScriptController.shared.closeEditorWindow(
                forSessionID: sessionIDValue,
                bypassUnsavedConfirmation: true
            )
        case .no:
            try SwiftTagAppleScriptController.shared.closeEditorWindow(
                forSessionID: sessionIDValue,
                bypassUnsavedConfirmation: true
            )
        case .ask:
            try SwiftTagAppleScriptController.shared.closeEditorWindow(
                forSessionID: sessionIDValue,
                bypassUnsavedConfirmation: false
            )
        }
    }

    func addTracks(at urls: [URL]) throws -> [SwiftTagScriptTrack] {
        try SwiftTagAppleScriptController.shared.addTracks(urls, toSessionID: sessionIDValue)
    }

    @objc(handleAddTracksScriptCommand:)
    func handleAddTracksScriptCommand(_ command: NSScriptCommand) -> Any? {
        do {
            let urls = try SwiftTagAppleScriptFileURLResolver.fileURLs(
                from: command.directParameter,
                missingValueError: .missingAddTracksInput
            )
            let tracks = try addTracks(at: urls)
            return tracks.count == 1 ? tracks[0] : tracks
        } catch {
            return command.fail(error)
        }
    }

    @objc(handleSaveScriptCommand:)
    func handleSaveScriptCommand(_ command: NSScriptCommand) -> Any? {
        do {
            let arguments = command.evaluatedArguments
            if arguments?["File"] != nil ||
                arguments?["file"] != nil ||
                arguments?["in"] != nil {
                throw SwiftTagAppleScriptCommandError.editorWindowSaveDestinationUnsupported
            }

            let request = try SwiftTagAppleScriptFlacSaveRequest.from(arguments: arguments)
            _ = try saveFlacFiles(using: request)
            return self
        } catch {
            return command.fail(error)
        }
    }

    @objc(handleCloseScriptCommand:)
    func handleCloseScriptCommand(_ command: NSScriptCommand) -> Any? {
        do {
            let request = try SwiftTagAppleScriptCloseRequest.from(arguments: command.evaluatedArguments)
            try close(using: request)
            return nil
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

    private func normalizedScriptTracks(from rawValue: Any?) throws -> [SwiftTagScriptTrack] {
        switch rawValue {
        case nil:
            return []
        case let track as SwiftTagScriptTrack:
            return [track]
        case let tracks as [SwiftTagScriptTrack]:
            return tracks
        case let tracks as [Any]:
            return try tracks.flatMap { value in
                try normalizedScriptTracks(from: value)
            }
        case let tracks as NSArray:
            return try tracks.flatMap { value in
                try normalizedScriptTracks(from: value)
            }
        case let specifier as NSScriptObjectSpecifier:
            return try normalizedScriptTracks(from: specifier.objectsByEvaluatingSpecifier)
        default:
            throw SwiftTagAppleScriptCommandError.invalidSelectedTrack
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

    func close(
        using request: SwiftTagAppleScriptCloseRequest = .init(
            saveOption: nil,
            destinationURL: nil,
            flacSaveRequest: .init(payload: nil, scope: nil)
        )
    ) throws {
        switch request.saveOption ?? .ask {
        case .yes:
            if modified {
                _ = try saveSwiftTagDocument(to: request.destinationURL)
            }
            try SwiftTagAppleScriptController.shared.closeEditorWindow(
                forSessionID: sessionIDValue,
                bypassUnsavedConfirmation: true
            )
        case .no:
            try SwiftTagAppleScriptController.shared.closeEditorWindow(
                forSessionID: sessionIDValue,
                bypassUnsavedConfirmation: true
            )
        case .ask:
            try SwiftTagAppleScriptController.shared.closeEditorWindow(
                forSessionID: sessionIDValue,
                bypassUnsavedConfirmation: false
            )
        }
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

    @objc(handleCloseScriptCommand:)
    func handleCloseScriptCommand(_ command: NSScriptCommand) -> Any? {
        do {
            let request = try SwiftTagAppleScriptCloseRequest.from(arguments: command.evaluatedArguments)
            try close(using: request)
            return nil
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

    private struct TrackCacheKey: Hashable {
        let sessionID: UUID
        let trackID: UUID
    }

    private var editorWindowsBySessionID: [UUID: SwiftTagScriptEditorWindow] = [:]
    private var documentsBySessionID: [UUID: SwiftTagScriptDocument] = [:]
    private var trackWrappersByKey: [TrackCacheKey: SwiftTagScriptTrack] = [:]
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

    func orderedTracks() -> [SwiftTagScriptTrack] {
        orderedDocuments().flatMap { document in
            tracks(forSessionID: document.sessionID)
        }
    }

    func frontmostEditorWindow() -> SwiftTagScriptEditorWindow? {
        orderedEditorWindows().first
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
        trackWrappersByKey = trackWrappersByKey.filter { $0.key.sessionID != sessionID }
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

    func editorWindow(forSessionID sessionID: UUID) -> SwiftTagScriptEditorWindow? {
        if let wrapper = editorWindowsBySessionID[sessionID] {
            return wrapper
        }

        let liveWindow = orderedLiveEditorWindows().first(where: { $0.sessionID == sessionID })?.window
        if liveWindow != nil
            || sessionBridgesBySessionID[sessionID] != nil
            || pendingDocumentURLBySessionID[sessionID] != nil {
            return editorWindow(forSessionID: sessionID, liveWindow: liveWindow, markPending: liveWindow == nil)
        }

        return nil
    }

    func tracks(forSessionID sessionID: UUID) -> [SwiftTagScriptTrack] {
        guard let snapshot = sessionSnapshot(forSessionID: sessionID) else {
            return []
        }

        let orderedTracks = snapshot.tracks.sortedForTrackTableDisplay()
        let validTrackIDs = Set(snapshot.tracks.map(\.id))
        pruneTrackWrappers(forSessionID: sessionID, validTrackIDs: validTrackIDs)
        return orderedTracks.compactMap { track(forSessionID: sessionID, trackID: $0.id) }
    }

    func selectedTrackObjects(forSessionID sessionID: UUID) -> [SwiftTagScriptTrack] {
        guard let snapshot = sessionSnapshot(forSessionID: sessionID) else {
            return []
        }

        let orderedTracks = snapshot.tracks.sortedForTrackTableDisplay()
        let validTrackIDs = Set(snapshot.tracks.map(\.id))
        pruneTrackWrappers(forSessionID: sessionID, validTrackIDs: validTrackIDs)
        return orderedTracks
            .filter { snapshot.selectedTrackIDs.contains($0.id) }
            .compactMap { track(forSessionID: sessionID, trackID: $0.id) }
    }

    func setSelectedTracks(
        _ scriptTracks: [SwiftTagScriptTrack],
        forSessionID sessionID: UUID
    ) throws {
        if scriptTracks.contains(where: { $0.sessionID != sessionID }) {
            throw SwiftTagAppleScriptCommandError.invalidSelectedTrack
        }

        let requestedTrackIDs = Set(scriptTracks.map(\.trackID))
        try selectTrackIDs(requestedTrackIDs, forSessionID: sessionID)
    }

    func selectTrackIDs(
        _ trackIDs: Set<UUID>,
        forSessionID sessionID: UUID
    ) throws {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        let availableTrackIDs = Set(sessionSnapshot(forSessionID: sessionID)?.tracks.map(\.id) ?? [])
        guard trackIDs.isSubset(of: availableTrackIDs) else {
            throw SwiftTagAppleScriptCommandError.invalidSelectedTrack
        }

        try bridge.selectTracks(trackIDs)
    }

    func trackSnapshot(forSessionID sessionID: UUID, trackID: UUID) -> Track? {
        sessionSnapshot(forSessionID: sessionID)?.tracks.first(where: { $0.id == trackID })
    }

    func addTracks(_ urls: [URL], toSessionID sessionID: UUID) throws -> [SwiftTagScriptTrack] {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        let trackIDs = try bridge.addTracks(urls)
        return trackIDs.compactMap { track(forSessionID: sessionID, trackID: $0) }
    }

    func tags(forSessionID sessionID: UUID, trackID: UUID) -> [SwiftTagScriptTag] {
        tagSnapshots(forSessionID: sessionID, trackID: trackID).map { snapshot in
            SwiftTagScriptTag(
                sessionID: sessionID,
                trackID: trackID,
                key: snapshot.key
            )
        }
    }

    func tagSnapshot(
        forSessionID sessionID: UUID,
        trackID: UUID,
        key: String
    ) -> SwiftTagAppleScriptTagSnapshot? {
        let normalizedKey = SwiftTagAppleScriptTagKey.normalizedKey(key)
        return tagSnapshots(forSessionID: sessionID, trackID: trackID)
            .first { $0.key == normalizedKey }
    }

    func tag(
        forSessionID sessionID: UUID,
        trackID: UUID,
        uniqueID: Any
    ) -> SwiftTagScriptTag? {
        guard let key = normalizedTagUniqueID(uniqueID),
              tagSnapshot(forSessionID: sessionID, trackID: trackID, key: key) != nil else {
            return nil
        }

        return SwiftTagScriptTag(
            sessionID: sessionID,
            trackID: trackID,
            key: key
        )
    }

    func upsertTag(
        key: String,
        value: String,
        forSessionID sessionID: UUID,
        trackID: UUID
    ) throws {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        try bridge.upsertTag(trackID, key, value)
    }

    func deleteTag(
        key: String,
        forSessionID sessionID: UUID,
        trackID: UUID
    ) throws {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        try bridge.deleteTag(trackID, key)
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

    func saveTracks(
        forSessionID sessionID: UUID,
        request: SwiftTagAppleScriptFlacSaveRequest
    ) throws -> SaveOperationResult {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        return try bridge.saveTracks(request)
    }

    func closeEditorWindow(
        forSessionID sessionID: UUID,
        bypassUnsavedConfirmation: Bool
    ) throws {
        if let window = orderedLiveEditorWindows().first(where: { $0.sessionID == sessionID })?.window {
            if bypassUnsavedConfirmation {
                UnsavedChangesCoordinator.shared.allowNextClose(for: sessionID)
                window.close()
                unregisterClosedEditorSession(sessionID)
                return
            }
            window.performClose(nil)
            return
        }

        guard editorWindowsBySessionID[sessionID] != nil
            || documentsBySessionID[sessionID] != nil
            || sessionBridgesBySessionID[sessionID] != nil
            || pendingDocumentURLBySessionID[sessionID] != nil else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        unregisterClosedEditorSession(sessionID)
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

    func indexOfTrack(trackID: UUID, forSessionID sessionID: UUID) -> Int? {
        sessionSnapshot(forSessionID: sessionID)?
            .tracks
            .sortedForTrackTableDisplay()
            .firstIndex(where: { $0.id == trackID })
    }

    #if DEBUG
    func resetForTesting() {
        editorWindowsBySessionID.removeAll()
        documentsBySessionID.removeAll()
        trackWrappersByKey.removeAll()
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
            guard window.isVisible || window.isMiniaturized else {
                return nil
            }
            guard let delegate = window.delegate as? EditorWindowSessionIdentifying else {
                return nil
            }

            return (delegate.editorSessionID, window)
        }
    }

    private func unregisterClosedEditorSession(_ sessionID: UUID) {
        unregister(sessionID: sessionID)
        EditorWindowCoordinator.shared.unregister(sessionID: sessionID)
        UnsavedChangesCoordinator.shared.unregister(sessionID: sessionID)
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

    private func sessionSnapshot(forSessionID sessionID: UUID) -> SwiftTagAppleScriptSessionSnapshot? {
        sessionBridgesBySessionID[sessionID]?.sessionSnapshot()
    }

    fileprivate func track(forSessionID sessionID: UUID, trackID: UUID) -> SwiftTagScriptTrack? {
        guard trackSnapshot(forSessionID: sessionID, trackID: trackID) != nil else {
            return nil
        }

        let key = TrackCacheKey(sessionID: sessionID, trackID: trackID)
        if let wrapper = trackWrappersByKey[key] {
            return wrapper
        }

        let wrapper = SwiftTagScriptTrack(sessionID: sessionID, trackID: trackID)
        trackWrappersByKey[key] = wrapper
        return wrapper
    }

    private func pruneTrackWrappers(forSessionID sessionID: UUID, validTrackIDs: Set<UUID>) {
        trackWrappersByKey = trackWrappersByKey.filter { key, _ in
            key.sessionID != sessionID || validTrackIDs.contains(key.trackID)
        }
    }

    private func tagSnapshots(forSessionID sessionID: UUID, trackID: UUID) -> [SwiftTagAppleScriptTagSnapshot] {
        guard let track = trackSnapshot(forSessionID: sessionID, trackID: trackID) else {
            return []
        }

        return SwiftTagAppleScriptTagKey.snapshots(for: track)
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

    private func normalizedTagUniqueID(_ uniqueID: Any) -> String? {
        if let string = uniqueID as? String {
            let normalizedKey = SwiftTagAppleScriptTagKey.normalizedKey(string)
            return normalizedKey.isEmpty ? nil : normalizedKey
        }

        if let string = uniqueID as? NSString {
            let normalizedKey = SwiftTagAppleScriptTagKey.normalizedKey(string as String)
            return normalizedKey.isEmpty ? nil : normalizedKey
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

    @objc(scriptTracks)
    var scriptTracks: [SwiftTagScriptTrack] {
        SwiftTagAppleScriptController.shared.orderedTracks()
    }

    @objc(countOfScriptTracks)
    var countOfScriptTracks: Int {
        scriptTracks.count
    }

    @objc(objectInScriptTracksAtIndex:)
    func objectInScriptTracks(at index: Int) -> SwiftTagScriptTrack {
        scriptTracks[index]
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

    @objc(handleAddTracksScriptCommand:)
    func handleAddTracksScriptCommand(_ command: NSScriptCommand) -> Any? {
        do {
            let urls = try SwiftTagAppleScriptFileURLResolver.fileURLs(
                from: command.directParameter,
                missingValueError: .missingAddTracksInput
            )
            let targetWindow = try scriptEditorWindowTarget(from: command)
            let tracks = try targetWindow.addTracks(at: urls)
            return tracks.count == 1 ? tracks[0] : tracks
        } catch {
            return command.fail(error)
        }
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

    private func scriptEditorWindowTarget(from command: NSScriptCommand) throws -> SwiftTagScriptEditorWindow {
        let targetValue = command.evaluatedArguments?["Target"] ?? command.evaluatedArguments?["to"]
        if let targetValue {
            if let targetWindow = targetValue as? SwiftTagScriptEditorWindow {
                return targetWindow
            }

            if let targetWindows = targetValue as? [Any],
               targetWindows.count == 1,
               let targetWindow = targetWindows.first as? SwiftTagScriptEditorWindow {
                return targetWindow
            }

            if let targetWindows = targetValue as? NSArray,
               targetWindows.count == 1,
               let targetWindow = targetWindows.firstObject as? SwiftTagScriptEditorWindow {
                return targetWindow
            }

            throw SwiftTagAppleScriptCommandError.invalidEditorWindowTarget
        }

        guard let targetWindow = SwiftTagAppleScriptController.shared.frontmostEditorWindow() else {
            throw SwiftTagAppleScriptCommandError.noEditorWindowAvailable
        }

        return targetWindow
    }
}
