import AppKit
import Foundation

@objc(SwiftTagCreateCommand)
final class SwiftTagCreateCommand: NSCreateCommand {
    private static let directObjectKeyword = fourCharCode("----")
    private static let subjectAttribute = fourCharCode("subj")

    override var isWellFormed: Bool {
        true
    }

    override func execute() -> Any? {
        MainActor.assumeIsolated {
            performSwiftTagDefaultImplementation()
        }
    }

    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated {
            performSwiftTagDefaultImplementation()
        }
    }

    @MainActor
    private func performSwiftTagDefaultImplementation() -> Any? {
        do {
            switch createClassDescription.className {
            case "picture":
                let track = try scriptTrackInsertionContainer(
                    key: "pictures",
                    error: .invalidPictureTrackTarget
                )
                return try track.makePicture(using: self)
            case "tag":
                let track = try scriptTrackInsertionContainer(
                    key: "tags",
                    error: .invalidTagTrackTarget
                )
                return try track.makeTag(using: self)
            default:
                return super.performDefaultImplementation()
            }
        } catch {
            return fail(error)
        }
    }

    @MainActor
    private func scriptTrackInsertionContainer(
        key expectedKey: String,
        error: SwiftTagAppleScriptCommandError
    ) throws -> SwiftTagScriptTrack {
        if let location = positionalSpecifier() {
            location.setInsertionClassDescription(createClassDescription)
            location.evaluate()
            guard location.insertionKey == expectedKey,
                  let track = location.insertionContainer as? SwiftTagScriptTrack else {
                throw error
            }
            return track
        }

        if let track = targetTrack() {
            return track
        }

        throw error
    }

    private func positionalSpecifier() -> NSPositionalSpecifier? {
        arguments?["Location"] as? NSPositionalSpecifier
            ?? arguments?["at"] as? NSPositionalSpecifier
            ?? evaluatedArguments?["Location"] as? NSPositionalSpecifier
            ?? evaluatedArguments?["at"] as? NSPositionalSpecifier
    }

    @MainActor
    private func targetTrack() -> SwiftTagScriptTrack? {
        if let track = Self.track(from: directParameter) {
            return track
        }

        if let track = Self.track(from: evaluatedReceivers) {
            return track
        }

        if let track = Self.track(from: receiversSpecifier?.objectsByEvaluatingSpecifier) {
            return track
        }

        if let subjectDescriptor = appleEvent?.attributeDescriptor(forKeyword: Self.subjectAttribute),
           let subjectSpecifier = NSScriptObjectSpecifier(descriptor: subjectDescriptor),
           let track = Self.track(from: subjectSpecifier.objectsByEvaluatingSpecifier) {
            return track
        }

        if let directObjectDescriptor = appleEvent?.paramDescriptor(forKeyword: Self.directObjectKeyword),
           let directObjectSpecifier = NSScriptObjectSpecifier(descriptor: directObjectDescriptor),
           let track = Self.track(from: directObjectSpecifier.objectsByEvaluatingSpecifier) {
            return track
        }

        return nil
    }

    @MainActor
    private static func track(from value: Any?) -> SwiftTagScriptTrack? {
        switch value {
        case let track as SwiftTagScriptTrack:
            return track
        case let tracks as [SwiftTagScriptTrack] where tracks.count == 1:
            return tracks[0]
        case let tracks as NSArray where tracks.count == 1:
            return tracks.firstObject as? SwiftTagScriptTrack
        case let specifier as NSScriptObjectSpecifier:
            return track(from: specifier.objectsByEvaluatingSpecifier)
        default:
            return nil
        }
    }

    nonisolated private static func fourCharCode(_ value: String) -> AEKeyword {
        let bytes = Array(value.utf8.prefix(4))
        let paddedBytes = bytes + Array(repeating: UInt8(32), count: max(0, 4 - bytes.count))
        return paddedBytes.prefix(4).reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
    }
}

@objc(SwiftTagDeleteCommand)
final class SwiftTagDeleteCommand: NSDeleteCommand {
    private static let directObjectKeyword = fourCharCode("----")
    private static let subjectAttribute = fourCharCode("subj")

    private struct ResolvedPictureExtraction {
        let pictures: [SwiftTagScriptPicture]
        let handlesValue: Bool
    }

    private struct ResolvedTrackExtraction {
        let tracks: [SwiftTagScriptTrack]
        let handlesValue: Bool
    }

    override var isWellFormed: Bool {
        true
    }

    override func execute() -> Any? {
        MainActor.assumeIsolated {
            performSwiftTagDefaultImplementation()
        }
    }

    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated {
            performSwiftTagDefaultImplementation()
        }
    }

    @MainActor
    private func performSwiftTagDefaultImplementation() -> Any? {
        do {
            if try deleteSwiftTagTargetIfNeeded() {
                return nil
            }

            return super.performDefaultImplementation()
        } catch {
            return fail(error)
        }
    }

    @MainActor
    private func deleteSwiftTagTargetIfNeeded() throws -> Bool {
        let directObjectSpecifier = directObjectSpecifier()

        if let directObjectSpecifier,
           try deleteTrackPropertyIfNeeded(directObjectSpecifier, receiverSpecifier: receiversSpecifier) {
            return true
        }

        if let directObjectSpecifier,
           try deleteTagSpecifierIfNeeded(directObjectSpecifier, receiverSpecifier: receiversSpecifier) {
            return true
        }

        if let directObjectSpecifier,
           try deletePictureSpecifierIfNeeded(directObjectSpecifier, receiverSpecifier: receiversSpecifier) {
            return true
        }

        if let directObjectSpecifier,
           try deleteTrackSpecifierIfNeeded(directObjectSpecifier) {
            return true
        }

        if let directObjectSpecifier, try deleteResolvedValue(directObjectSpecifier) {
            return true
        }

        if try deleteTrackPropertyIfNeeded(keySpecifier, receiverSpecifier: receiversSpecifier) {
            return true
        }

        if try deleteTagSpecifierIfNeeded(keySpecifier, receiverSpecifier: receiversSpecifier) {
            return true
        }

        if try deletePictureSpecifierIfNeeded(keySpecifier, receiverSpecifier: receiversSpecifier) {
            return true
        }

        if try deleteTrackSpecifierIfNeeded(keySpecifier) {
            return true
        }

        if try deleteResolvedValue(directParameter) {
            return true
        }

        if directObjectSpecifier == nil,
           let track = unevaluatedTargetTrack() {
            try track.delete()
            return true
        }

        if try deleteResolvedValue(evaluatedReceivers) {
            return true
        }

        if try deleteResolvedValue(keySpecifier) {
            return true
        }

        return false
    }

    @MainActor
    private func deleteTrackSpecifierIfNeeded(_ specifier: NSScriptObjectSpecifier?) throws -> Bool {
        guard let specifier, Self.isTrackCollectionKey(specifier.key) else {
            return false
        }

        let trackExtraction = try resolvedTracksIfPossible(from: specifier)
        guard trackExtraction.handlesValue else {
            return false
        }

        try SwiftTagScriptTrack.delete(trackExtraction.tracks)
        return true
    }

    @MainActor
    private func deleteTrackPropertyIfNeeded(
        _ specifier: NSScriptObjectSpecifier?,
        receiverSpecifier: NSScriptObjectSpecifier?
    ) throws -> Bool {
        guard let specifier,
              SwiftTagScriptTrack.tagKey(forScriptPropertyKey: specifier.key) != nil else {
            return false
        }

        guard let track = Self.track(from: specifier.container?.objectsByEvaluatingSpecifier)
                ?? Self.track(from: receiverSpecifier?.objectsByEvaluatingSpecifier) else {
            throw SwiftTagAppleScriptCommandError.invalidTagTrackTarget
        }

        try track.deleteTagValue(forScriptPropertyKey: specifier.key)
        return true
    }

    @MainActor
    private func deleteTagSpecifierIfNeeded(
        _ specifier: NSScriptObjectSpecifier?,
        receiverSpecifier: NSScriptObjectSpecifier?
    ) throws -> Bool {
        guard let specifier, specifier.key == "tags" else {
            return false
        }

        guard let track = Self.track(from: specifier.container?.objectsByEvaluatingSpecifier)
                ?? Self.track(from: receiverSpecifier?.objectsByEvaluatingSpecifier) else {
            throw SwiftTagAppleScriptCommandError.invalidTagTrackTarget
        }

        if let uniqueIDSpecifier = specifier as? NSUniqueIDSpecifier {
            let key = try tagKey(fromUniqueID: uniqueIDSpecifier.uniqueID)
            try SwiftTagAppleScriptController.shared.deleteTag(
                key: key,
                forSessionID: track.sessionID,
                trackID: track.trackID
            )
            return true
        }

        if let indexSpecifier = specifier as? NSIndexSpecifier,
           let tag = track.tags[safe: indexSpecifier.index] {
            try tag.delete()
            return true
        }

        return false
    }

    @MainActor
    private func deletePictureSpecifierIfNeeded(
        _ specifier: NSScriptObjectSpecifier?,
        receiverSpecifier: NSScriptObjectSpecifier?
    ) throws -> Bool {
        guard let specifier, specifier.key == "pictures" else {
            return false
        }

        let containingTrack = Self.track(from: specifier.container?.objectsByEvaluatingSpecifier)
            ?? Self.track(from: receiverSpecifier?.objectsByEvaluatingSpecifier)
            ?? targetTrack()

        if let indexSpecifier = specifier as? NSIndexSpecifier {
            guard let containingTrack else {
                throw SwiftTagAppleScriptCommandError.invalidPictureTrackTarget
            }

            try SwiftTagAppleScriptController.shared.deletePicture(
                forSessionID: containingTrack.sessionID,
                trackID: containingTrack.trackID,
                pictureIndex: indexSpecifier.index
            )
            return true
        }

        let pictureExtraction = try resolvedPicturesIfPossible(
            from: specifier,
            container: containingTrack
        )
        guard pictureExtraction.handlesValue, !pictureExtraction.pictures.isEmpty else {
            return false
        }

        try SwiftTagScriptPicture.delete(pictureExtraction.pictures)
        return true
    }

    @MainActor
    private func deleteResolvedValue(_ value: Any?) throws -> Bool {
        switch value {
        case nil:
            return false
        case let tag as SwiftTagScriptTag:
            try tag.delete()
            return true
        case let track as SwiftTagScriptTrack:
            try track.delete()
            return true
        case let picture as SwiftTagScriptPicture:
            try picture.delete()
            return true
        case let specifier as NSScriptObjectSpecifier:
            if try deleteTrackPropertyIfNeeded(specifier, receiverSpecifier: receiversSpecifier) {
                return true
            }
            let trackExtraction = try resolvedTracksIfPossible(from: specifier)
            if trackExtraction.handlesValue {
                try SwiftTagScriptTrack.delete(trackExtraction.tracks)
                return true
            }
            let pictureExtraction = try resolvedPicturesIfPossible(from: specifier)
            if pictureExtraction.handlesValue {
                guard !pictureExtraction.pictures.isEmpty else {
                    return false
                }
                try SwiftTagScriptPicture.delete(pictureExtraction.pictures)
                return true
            }
            return try deleteResolvedValue(specifier.objectsByEvaluatingSpecifier)
        case let values as [Any]:
            return try deleteResolvedValues(values)
        case let values as NSArray:
            return try deleteResolvedValues(values.map { $0 })
        default:
            return false
        }
    }

    @MainActor
    private func deleteResolvedValues(_ values: [Any]) throws -> Bool {
        let trackExtraction = try resolvedTracksIfPossible(from: values)
        if trackExtraction.handlesValue {
            try SwiftTagScriptTrack.delete(trackExtraction.tracks)
            return true
        }

        let pictureExtraction = try resolvedPicturesIfPossible(from: values)
        if pictureExtraction.handlesValue {
            try SwiftTagScriptPicture.delete(pictureExtraction.pictures)
            return true
        }

        var deletedAny = false
        let pictures = values.compactMap { $0 as? SwiftTagScriptPicture }
        if !pictures.isEmpty {
            try SwiftTagScriptPicture.delete(pictures)
            deletedAny = true
        }

        for value in values {
            if value is SwiftTagScriptPicture {
                continue
            }
            if try deleteResolvedValue(value) {
                deletedAny = true
            }
        }
        return deletedAny
    }

    @MainActor
    private func resolvedTracksIfPossible(
        from value: Any?,
        container: Any? = nil
    ) throws -> ResolvedTrackExtraction {
        switch value {
        case nil:
            return ResolvedTrackExtraction(tracks: [], handlesValue: false)
        case let track as SwiftTagScriptTrack:
            return ResolvedTrackExtraction(tracks: [track], handlesValue: true)
        case let specifier as NSScriptObjectSpecifier:
            guard Self.isTrackCollectionKey(specifier.key) else {
                return ResolvedTrackExtraction(tracks: [], handlesValue: false)
            }

            let evaluatedValue: Any?
            if let container {
                evaluatedValue = specifier.objectsByEvaluating(withContainers: container)
            } else {
                evaluatedValue = specifier.objectsByEvaluatingSpecifier
            }
            return try resolvedTracksIfPossible(from: evaluatedValue)
        case let values as [Any]:
            return try resolvedTracksIfPossible(fromArray: values, container: container)
        case let values as NSArray:
            return try resolvedTracksIfPossible(fromArray: values.map { $0 }, container: container)
        default:
            return ResolvedTrackExtraction(tracks: [], handlesValue: false)
        }
    }

    @MainActor
    private func resolvedTracksIfPossible(
        fromArray values: [Any],
        container: Any? = nil
    ) throws -> ResolvedTrackExtraction {
        guard !values.isEmpty else {
            return ResolvedTrackExtraction(tracks: [], handlesValue: true)
        }

        var tracks: [SwiftTagScriptTrack] = []
        for value in values {
            let extraction = try resolvedTracksIfPossible(from: value, container: container)
            guard extraction.handlesValue else {
                return ResolvedTrackExtraction(tracks: [], handlesValue: false)
            }
            tracks.append(contentsOf: extraction.tracks)
        }

        return ResolvedTrackExtraction(tracks: tracks, handlesValue: true)
    }

    @MainActor
    private func resolvedPicturesIfPossible(
        from value: Any?,
        container: Any? = nil
    ) throws -> ResolvedPictureExtraction {
        switch value {
        case nil:
            return ResolvedPictureExtraction(pictures: [], handlesValue: false)
        case let picture as SwiftTagScriptPicture:
            return ResolvedPictureExtraction(pictures: [picture], handlesValue: true)
        case let specifier as NSScriptObjectSpecifier:
            if SwiftTagScriptTrack.tagKey(forScriptPropertyKey: specifier.key) != nil
                || specifier.key == "tags" {
                return ResolvedPictureExtraction(pictures: [], handlesValue: false)
            }

            let evaluatedValue: Any?
            if let container {
                evaluatedValue = specifier.objectsByEvaluating(withContainers: container)
            } else {
                evaluatedValue = specifier.objectsByEvaluatingSpecifier
            }
            return try resolvedPicturesIfPossible(from: evaluatedValue)
        case let values as [Any]:
            return try resolvedPicturesIfPossible(fromArray: values, container: container)
        case let values as NSArray:
            return try resolvedPicturesIfPossible(fromArray: values.map { $0 }, container: container)
        default:
            return ResolvedPictureExtraction(pictures: [], handlesValue: false)
        }
    }

    @MainActor
    private func resolvedPicturesIfPossible(
        fromArray values: [Any],
        container: Any? = nil
    ) throws -> ResolvedPictureExtraction {
        guard !values.isEmpty else {
            return ResolvedPictureExtraction(pictures: [], handlesValue: true)
        }

        var pictures: [SwiftTagScriptPicture] = []
        for value in values {
            let extraction = try resolvedPicturesIfPossible(from: value, container: container)
            guard extraction.handlesValue else {
                return ResolvedPictureExtraction(pictures: [], handlesValue: false)
            }
            pictures.append(contentsOf: extraction.pictures)
        }

        return ResolvedPictureExtraction(pictures: pictures, handlesValue: true)
    }

    private static func isTrackCollectionKey(_ key: String) -> Bool {
        key == "tracks" || key == "scriptTracks"
    }

    private func directObjectSpecifier() -> NSScriptObjectSpecifier? {
        guard let descriptor = appleEvent?.paramDescriptor(forKeyword: Self.directObjectKeyword) else {
            return nil
        }

        return NSScriptObjectSpecifier(descriptor: descriptor)
    }

    @MainActor
    private func targetTrack() -> SwiftTagScriptTrack? {
        if let track = Self.track(from: evaluatedReceivers) {
            return track
        }

        if let track = Self.track(from: receiversSpecifier?.objectsByEvaluatingSpecifier) {
            return track
        }

        if let subjectDescriptor = appleEvent?.attributeDescriptor(forKeyword: Self.subjectAttribute),
           let subjectSpecifier = NSScriptObjectSpecifier(descriptor: subjectDescriptor),
           let track = Self.track(from: subjectSpecifier.objectsByEvaluatingSpecifier) {
            return track
        }

        if let directObjectDescriptor = appleEvent?.paramDescriptor(forKeyword: Self.directObjectKeyword),
           let directObjectSpecifier = NSScriptObjectSpecifier(descriptor: directObjectDescriptor),
           let track = Self.track(from: directObjectSpecifier.container?.objectsByEvaluatingSpecifier) {
            return track
        }

        return nil
    }

    @MainActor
    private func unevaluatedTargetTrack() -> SwiftTagScriptTrack? {
        if let subjectDescriptor = appleEvent?.attributeDescriptor(forKeyword: Self.subjectAttribute),
           let subjectSpecifier = NSScriptObjectSpecifier(descriptor: subjectDescriptor),
           let track = Self.track(from: subjectSpecifier.objectsByEvaluatingSpecifier) {
            return track
        }

        if let track = Self.track(from: receiversSpecifier?.objectsByEvaluatingSpecifier) {
            return track
        }

        if let directObjectDescriptor = appleEvent?.paramDescriptor(forKeyword: Self.directObjectKeyword),
           let directObjectSpecifier = NSScriptObjectSpecifier(descriptor: directObjectDescriptor),
           let track = Self.track(from: directObjectSpecifier.container?.objectsByEvaluatingSpecifier) {
            return track
        }

        return nil
    }

    private func tagKey(fromUniqueID uniqueID: Any) throws -> String {
        let rawKey: String?
        switch uniqueID {
        case let string as String:
            rawKey = string
        case let string as NSString:
            rawKey = string as String
        case let number as NSNumber:
            rawKey = number.stringValue
        default:
            rawKey = String(describing: uniqueID)
        }

        let normalizedKey = SwiftTagAppleScriptTagKey.normalizedKey(rawKey ?? "")
        guard !normalizedKey.isEmpty else {
            throw SwiftTagAppleScriptCommandError.invalidTagKey
        }
        return normalizedKey
    }

    @MainActor
    private static func track(from value: Any?) -> SwiftTagScriptTrack? {
        switch value {
        case let track as SwiftTagScriptTrack:
            return track
        case let tracks as [SwiftTagScriptTrack] where tracks.count == 1:
            return tracks[0]
        case let tracks as NSArray where tracks.count == 1:
            return tracks.firstObject as? SwiftTagScriptTrack
        case let specifier as NSScriptObjectSpecifier:
            return track(from: specifier.objectsByEvaluatingSpecifier)
        default:
            return nil
        }
    }

    nonisolated private static func fourCharCode(_ value: String) -> AEKeyword {
        let bytes = Array(value.utf8.prefix(4))
        let paddedBytes = bytes + Array(repeating: UInt8(32), count: max(0, 4 - bytes.count))
        return paddedBytes.prefix(4).reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
    }
}

enum SwiftTagAppleScriptCommandError: LocalizedError, Equatable {
    case editorWindowSaveDestinationUnsupported
    case invalidEditorWindowTarget
    case missingOpenTarget
    case missingAddTracksInput
    case noEditorWindowAvailable
    case noFlacFilesProvided
    case noSwiftTagDocumentsProvided
    case invalidFileValue
    case invalidAddLockOptionValue(String)
    case invalidSaveOptionValue(String)
    case invalidSaveScopeOptionValue(String)
    case invalidSavePayloadOptionValue(String)
    case invalidTrackSortOptionValue(String)
    case invalidCloseSaveOptionValue(String)
    case invalidSelectedTrack
    case invalidTrackTarget
    case invalidSaveDestination
    case invalidTagKey
    case invalidTagObject
    case invalidTagTrackTarget
    case invalidPictureObject
    case invalidPictureTrackTarget
    case invalidPictureType
    case missingPictureData
    case invalidPictureData
    case pictureDataTooLarge
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
        case let .invalidAddLockOptionValue(optionName):
            return "Add option \(optionName) must be true or false."
        case let .invalidSaveOptionValue(optionName):
            return "Save option \(optionName) must be true or false."
        case let .invalidSaveScopeOptionValue(optionName):
            return "Save scope option \(optionName) must be all or selected."
        case let .invalidSavePayloadOptionValue(optionName):
            return "Save payload option \(optionName) must be tags only or pictures only or tags and pictures."
        case let .invalidTrackSortOptionValue(optionName):
            return "Track sort option \(optionName) must be track number order or filename order."
        case let .invalidCloseSaveOptionValue(optionName):
            return "Close save option \(optionName) must be yes, no, or ask."
        case .invalidSelectedTrack:
            return "Selected tracks must belong to target editor window."
        case .invalidTrackTarget:
            return "Track command target must resolve to a track in the current editor window."
        case .invalidSaveDestination:
            return "Save destination must be a single local file URL."
        case .invalidTagKey:
            return "Tag key must resolve to non-empty text without internal whitespace."
        case .invalidTagObject:
            return "Tag mutations require a tag object or record with key and value."
        case .invalidTagTrackTarget:
            return "Tag command target must resolve to a track in the current editor window."
        case .invalidPictureObject:
            return "Picture command target must resolve to a picture in the current editor window."
        case .invalidPictureTrackTarget:
            return "Picture creation target must resolve to a track pictures collection."
        case .invalidPictureType:
            return "Picture type must resolve to a FLAC picture type."
        case .missingPictureData:
            return "Picture creation requires image data."
        case .invalidPictureData:
            return "Picture data must contain a readable image."
        case .pictureDataTooLarge:
            return "Picture data and description exceed the FLAC metadata block size limit."
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
             .invalidAddLockOptionValue,
             .invalidSaveOptionValue,
             .invalidSaveScopeOptionValue,
             .invalidSavePayloadOptionValue,
             .invalidTrackSortOptionValue,
             .invalidCloseSaveOptionValue,
             .invalidSelectedTrack,
             .invalidTrackTarget,
             .invalidSaveDestination,
             .invalidTagKey,
             .invalidTagObject,
             .invalidTagTrackTarget,
             .invalidPictureObject,
             .invalidPictureTrackTarget,
             .invalidPictureType,
             .invalidPictureData,
             .pictureDataTooLarge,
             .saveLocationRequired:
            Int(NSArgumentsWrongScriptError)
        case .missingPictureData:
            Int(NSRequiredArgumentsMissingScriptError)
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

struct SwiftTagAppleScriptAddTracksRequest: Equatable {
    let locked: Bool

    static let defaults = Self(locked: false)

    static func from(arguments: [String: Any]?) throws -> Self {
        let locked = try SwiftTagAppleScriptBooleanOption.boolValue(
            from: SwiftTagAppleScriptArgumentValue.value(
                key: "WithLock",
                in: arguments
            ),
            optionName: "with lock"
        )

        return Self(locked: locked)
    }
}

struct SwiftTagAppleScriptFlacSaveRequest: Equatable {
    let payload: SavePayloadOption?
    let scope: SaveScopeOption?

    static let defaults = Self(payload: nil, scope: nil)

    static func from(arguments: [String: Any]?) throws -> Self {
        let scope = try SaveScopeOption.appleScriptValue(
            from: SwiftTagAppleScriptArgumentValue.value(
                key: "SaveScopeOptions",
                in: arguments
            ),
            optionName: "scope"
        )
        let payload = try SavePayloadOption.appleScriptValue(
            from: SwiftTagAppleScriptArgumentValue.value(
                key: "SavePayloadOptions",
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
                key: "SaveOptions",
                in: arguments
            )
        )
        let destinationURL = try SwiftTagAppleScriptFileURLResolver.singleFileURL(
            from: SwiftTagAppleScriptArgumentValue.value(
                key: "File",
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

enum SwiftTagAppleScriptTrackSortOption {
    static func sortMode(from rawValue: Any?, optionName: String = "track sort order") throws -> TrackTableSortMode? {
        guard let token = SwiftTagAppleScriptEnumerationToken.normalized(from: rawValue) else {
            return nil
        }

        switch token {
        case "tnum", "track number order", "tracknumber", "number", "nmbr":
            return .number
        case "tfil", "filename order", "filename":
            return .filename
        default:
            throw SwiftTagAppleScriptCommandError.invalidTrackSortOptionValue(optionName)
        }
    }
}

private enum SwiftTagAppleScriptArgumentValue {
    static func value(
        key: String,
        in arguments: [String: Any]?
    ) -> Any? {
        guard let arguments else {
            return nil
        }

        if let value = arguments[key] {
            return value
        }
        
        return nil
    }
}

private enum SwiftTagAppleScriptBooleanOption {
    static func boolValue(
        from rawValue: Any?,
        optionName: String
    ) throws -> Bool {
        guard let rawValue else {
            return false
        }

        switch rawValue {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as NSString:
            if let parsedValue = boolValue(from: value as String) {
                return parsedValue
            }
        case let value as String:
            if let parsedValue = boolValue(from: value) {
                return parsedValue
            }
        case let descriptor as NSAppleEventDescriptor:
            if descriptor.descriptorType == typeBoolean {
                return descriptor.booleanValue
            }
            if let stringValue = descriptor.stringValue,
               let parsedValue = boolValue(from: stringValue) {
                return parsedValue
            }
        default:
            break
        }

        throw SwiftTagAppleScriptCommandError.invalidAddLockOptionValue(optionName)
    }

    private static func boolValue(from rawValue: String) -> Bool? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return nil
        }
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
        
        if let number = rawValue as? NSNumber {
            return normalized(fourCharCodeString(number.uint32Value))
        }

        if let code = rawValue as? FourCharCode {
            return normalized(fourCharCodeString(code))
        }
        
        if let string = rawValue as? NSString {
            return normalized(string as String)
        }
        
        if let string = rawValue as? String {
            return normalized(string)
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

private enum SwiftTagAppleScriptCode {
    static func fourCharCode(_ value: String) -> FourCharCode {
        let bytes = Array(value.utf8.prefix(4))
        let paddedBytes = bytes + Array(repeating: UInt8(32), count: max(0, 4 - bytes.count))
        return paddedBytes.prefix(4).reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
    }
}

private extension TrackTableSortMode {
    var appleScriptCode: FourCharCode {
        switch self {
        case .number:
            SwiftTagAppleScriptCode.fourCharCode("tnum")
        case .filename:
            SwiftTagAppleScriptCode.fourCharCode("tfil")
        }
    }
}

private enum SwiftTagAppleScriptMissingValue {
    static func descriptor() -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(typeCode: SwiftTagAppleScriptCode.fourCharCode("msng"))
    }

    static func isMissing(_ rawValue: Any?) -> Bool {
        guard let rawValue else {
            return true
        }

        if rawValue is NSNull {
            return true
        }

        if let descriptor = rawValue as? NSAppleEventDescriptor {
            return descriptor.descriptorType == typeNull
                || (
                    descriptor.descriptorType == typeType
                    && descriptor.typeCodeValue == SwiftTagAppleScriptCode.fourCharCode("msng")
                )
        }

        return false
    }
}

private extension SaveScopeOption {
    var appleScriptCode: FourCharCode {
        switch self {
        case .allTracks:
            SwiftTagAppleScriptCode.fourCharCode("altr")
        case .selectedTracks:
            SwiftTagAppleScriptCode.fourCharCode("sltr")
        }
    }

    static func appleScriptValue(from rawValue: Any?, optionName: String) throws -> Self? {
        guard let token = SwiftTagAppleScriptEnumerationToken.normalized(from: rawValue) else {
            return nil
        }

        switch token {
        case "altr", "all":
            return .allTracks
        case "sltr", "selected":
            return .selectedTracks
        default:
            throw SwiftTagAppleScriptCommandError.invalidSaveScopeOptionValue(optionName)
        }
    }
}

private extension SavePayloadOption {
    var appleScriptCode: FourCharCode {
        switch self {
        case .writeTags:
            SwiftTagAppleScriptCode.fourCharCode("tgos")
        case .writePictures:
            SwiftTagAppleScriptCode.fourCharCode("pcos")
        case .writeTagsAndPictures:
            SwiftTagAppleScriptCode.fourCharCode("tpos")
        }
    }

    static func appleScriptValue(from rawValue: Any?, optionName: String) throws -> Self? {
        guard let token = SwiftTagAppleScriptEnumerationToken.normalized(from: rawValue) else {
            return nil
        }

        switch token {
        case "tgos", "tags only":
            return .writeTags
        case "pcos", "pictures only":
            return .writePictures
        case "tpos", "tags and pictures":
            return .writeTagsAndPictures
        default:
            throw SwiftTagAppleScriptCommandError.invalidSavePayloadOptionValue(optionName)
        }
    }
}

private extension TrackCountKeyStrategy {
    var appleScriptCode: FourCharCode? {
        switch self {
        case .totalTracks:
            SwiftTagAppleScriptCode.fourCharCode("tott")
        case .trackTotal:
            SwiftTagAppleScriptCode.fourCharCode("ttot")
        case .both:
            SwiftTagAppleScriptCode.fourCharCode("tatt")
        case .none:
            Optional<FourCharCode>.none
        }
    }

    static func appleScriptValue(from rawValue: Any?) -> Self? {
        if SwiftTagAppleScriptMissingValue.isMissing(rawValue) {
            return Self.none
        }

        guard let token = SwiftTagAppleScriptEnumerationToken.normalized(from: rawValue) else {
            return nil
        }

        switch token {
        case "tott", "totaltracks":
            return .totalTracks
        case "ttot", "tracktotal":
            return .trackTotal
        case "tatt", "totaltracks and tracktotal", "both":
            return .both
        case "none", "missing value":
            return Self.none
        default:
            return nil
        }
    }
}

private extension DiscCountKeyStrategy {
    var appleScriptCode: FourCharCode? {
        switch self {
        case .totalDiscs:
            SwiftTagAppleScriptCode.fourCharCode("dott")
        case .discTotal:
            SwiftTagAppleScriptCode.fourCharCode("dtot")
        case .both:
            SwiftTagAppleScriptCode.fourCharCode("datt")
        case .none:
            Optional<FourCharCode>.none
        }
    }

    static func appleScriptValue(from rawValue: Any?) -> Self? {
        if SwiftTagAppleScriptMissingValue.isMissing(rawValue) {
            return Self.none
        }

        guard let token = SwiftTagAppleScriptEnumerationToken.normalized(from: rawValue) else {
            return nil
        }

        switch token {
        case "dott", "totaldiscs":
            return .totalDiscs
        case "dtot", "disctotal":
            return .discTotal
        case "datt", "totaldiscs and disctotal", "both":
            return .both
        case "none", "missing value":
            return Self.none
        default:
            return nil
        }
    }
}

private extension SaveNotificationMode {
    var appleScriptCode: FourCharCode {
        switch self {
        case .always:
            SwiftTagAppleScriptCode.fourCharCode("snda")
        case .whenNotFrontmost:
            SwiftTagAppleScriptCode.fourCharCode("sndn")
        case .never:
            SwiftTagAppleScriptCode.fourCharCode("sndv")
        }
    }

    static func appleScriptValue(from rawValue: Any?) -> Self? {
        guard let token = SwiftTagAppleScriptEnumerationToken.normalized(from: rawValue) else {
            return nil
        }

        switch token {
        case "snda", "always":
            return .always
        case "sndn", "when not frontmost", "whennotfrontmost":
            return .whenNotFrontmost
        case "sndv", "never":
            return .never
        default:
            return nil
        }
    }
}

private extension AppThemePreference {
    var appleScriptCode: FourCharCode {
        switch self {
        case .light:
            SwiftTagAppleScriptCode.fourCharCode("lght")
        case .dark:
            SwiftTagAppleScriptCode.fourCharCode("dark")
        case .system:
            SwiftTagAppleScriptCode.fourCharCode("sysp")
        }
    }

    static func appleScriptValue(from rawValue: Any?) -> Self? {
        guard let token = SwiftTagAppleScriptEnumerationToken.normalized(from: rawValue) else {
            return nil
        }

        switch token {
        case "lght", "light":
            return .light
        case "dark":
            return .dark
        case "sysp", "system":
            return .system
        default:
            return nil
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
    let sortMode: TrackTableSortMode

    init(
        tracks: [Track],
        selectedTrackIDs: Set<UUID>,
        sortMode: TrackTableSortMode = .number
    ) {
        self.tracks = tracks
        self.selectedTrackIDs = selectedTrackIDs
        self.sortMode = sortMode
    }
}

struct SwiftTagAppleScriptPictureIdentity: Equatable {
    let id: UUID
    let poolId: UUID
}

struct SwiftTagAppleScriptSessionBridge {
    let documentSnapshot: () -> SwiftTagAppleScriptDocumentSnapshot
    let sessionSnapshot: () -> SwiftTagAppleScriptSessionSnapshot
    let editorWindowModified: () -> Bool
    let trackModified: (UUID) -> Bool
    let addTracks: ([URL], Bool) throws -> [UUID]
    let deleteTracks: (Set<UUID>) throws -> Void
    let selectTracks: (Set<UUID>) throws -> Void
    let setTrackLocked: (UUID, Bool) throws -> Void
    let saveDocument: (URL?) throws -> SwiftTagDocumentSaveState
    let saveTracks: (SwiftTagAppleScriptFlacSaveRequest) throws -> SaveOperationResult
    let sortTracks: (TrackTableSortMode) throws -> Void
    let upsertTag: (UUID, String, String) throws -> Void
    let deleteTag: (UUID, String) throws -> Void
    let upsertPicture: (UUID, SwiftTagAppleScriptPicturePayload) throws -> Int
    let replacePicture: (UUID, Int, SwiftTagAppleScriptPicturePayload) throws -> Int
    let updatePictureDescription: (UUID, Int, String) throws -> Void
    let deletePicture: (UUID, Int) throws -> Void
    let pictureIdentity: (UUID, Int) -> SwiftTagAppleScriptPictureIdentity?

    init(
        documentSnapshot: @escaping () -> SwiftTagAppleScriptDocumentSnapshot,
        sessionSnapshot: @escaping () -> SwiftTagAppleScriptSessionSnapshot,
        editorWindowModified: (() -> Bool)? = nil,
        trackModified: ((UUID) -> Bool)? = nil,
        addTracks: @escaping ([URL]) throws -> [UUID],
        deleteTracks: @escaping (Set<UUID>) throws -> Void = { _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        selectTracks: @escaping (Set<UUID>) throws -> Void,
        setTrackLocked: @escaping (UUID, Bool) throws -> Void = { _, _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        saveDocument: @escaping (URL?) throws -> SwiftTagDocumentSaveState,
        saveTracks: @escaping (SwiftTagAppleScriptFlacSaveRequest) throws -> SaveOperationResult = { _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        sortTracks: @escaping (TrackTableSortMode) throws -> Void = { _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        upsertTag: @escaping (UUID, String, String) throws -> Void = { _, _, _ in },
        deleteTag: @escaping (UUID, String) throws -> Void = { _, _ in },
        upsertPicture: @escaping (UUID, SwiftTagAppleScriptPicturePayload) throws -> Int = { _, _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        replacePicture: @escaping (UUID, Int, SwiftTagAppleScriptPicturePayload) throws -> Int = { _, _, _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        updatePictureDescription: @escaping (UUID, Int, String) throws -> Void = { _, _, _ in },
        deletePicture: @escaping (UUID, Int) throws -> Void = { _, _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        pictureIdentity: @escaping (UUID, Int) -> SwiftTagAppleScriptPictureIdentity? = { _, _ in nil }
    ) {
        self.init(
            documentSnapshot: documentSnapshot,
            sessionSnapshot: sessionSnapshot,
            editorWindowModified: editorWindowModified,
            trackModified: trackModified,
            addTracksWithLock: { urls, _ in
                try addTracks(urls)
            },
            deleteTracks: deleteTracks,
            selectTracks: selectTracks,
            setTrackLocked: setTrackLocked,
            saveDocument: saveDocument,
            saveTracks: saveTracks,
            sortTracks: sortTracks,
            upsertTag: upsertTag,
            deleteTag: deleteTag,
            upsertPicture: upsertPicture,
            replacePicture: replacePicture,
            updatePictureDescription: updatePictureDescription,
            deletePicture: deletePicture,
            pictureIdentity: pictureIdentity
        )
    }

    init(
        documentSnapshot: @escaping () -> SwiftTagAppleScriptDocumentSnapshot,
        sessionSnapshot: @escaping () -> SwiftTagAppleScriptSessionSnapshot,
        editorWindowModified: (() -> Bool)? = nil,
        trackModified: ((UUID) -> Bool)? = nil,
        addTracksWithLock: @escaping ([URL], Bool) throws -> [UUID],
        deleteTracks: @escaping (Set<UUID>) throws -> Void = { _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        selectTracks: @escaping (Set<UUID>) throws -> Void,
        setTrackLocked: @escaping (UUID, Bool) throws -> Void = { _, _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        saveDocument: @escaping (URL?) throws -> SwiftTagDocumentSaveState,
        saveTracks: @escaping (SwiftTagAppleScriptFlacSaveRequest) throws -> SaveOperationResult = { _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        sortTracks: @escaping (TrackTableSortMode) throws -> Void = { _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        upsertTag: @escaping (UUID, String, String) throws -> Void = { _, _, _ in },
        deleteTag: @escaping (UUID, String) throws -> Void = { _, _ in },
        upsertPicture: @escaping (UUID, SwiftTagAppleScriptPicturePayload) throws -> Int = { _, _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        replacePicture: @escaping (UUID, Int, SwiftTagAppleScriptPicturePayload) throws -> Int = { _, _, _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        updatePictureDescription: @escaping (UUID, Int, String) throws -> Void = { _, _, _ in },
        deletePicture: @escaping (UUID, Int) throws -> Void = { _, _ in
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        },
        pictureIdentity: @escaping (UUID, Int) -> SwiftTagAppleScriptPictureIdentity? = { _, _ in nil }
    ) {
        self.documentSnapshot = documentSnapshot
        self.sessionSnapshot = sessionSnapshot
        self.editorWindowModified = editorWindowModified ?? {
            documentSnapshot().modified
        }
        self.trackModified = trackModified ?? { _ in false }
        self.addTracks = addTracksWithLock
        self.deleteTracks = deleteTracks
        self.selectTracks = selectTracks
        self.setTrackLocked = setTrackLocked
        self.saveDocument = saveDocument
        self.saveTracks = saveTracks
        self.sortTracks = sortTracks
        self.upsertTag = upsertTag
        self.deleteTag = deleteTag
        self.upsertPicture = upsertPicture
        self.replacePicture = replacePicture
        self.updatePictureDescription = updatePictureDescription
        self.deletePicture = deletePicture
        self.pictureIdentity = pictureIdentity
    }
}

private extension String {
    var appleScriptNonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

private extension FlacWritablePictureRecord {
    var hasAvailableImageMetadata: Bool {
        width > 0 || height > 0 || depth > 0
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
            if key == TagKey.compilation {
                guard !value.isEmpty else {
                    tagsByKey[key] = ""
                    continue
                }
                guard let normalizedCompilation = CompilationTag.normalizedValue(value) else {
                    continue
                }
                tagsByKey[key] = normalizedCompilation
                continue
            }

            tagsByKey[key] = value
        }

        let totalDiscValue = relatedKeys(for: totalDiscs)
            .compactMap { track.tags[$0]?.appleScriptNonEmptyValue }
            .map(normalizedValue(_:))
            .first
        if let totalDiscValue {
            tagsByKey[totalDiscs] = totalDiscValue
        } else if tagsByKey[totalDiscs] != nil {
            tagsByKey[totalDiscs] = ""
        } else {
            tagsByKey.removeValue(forKey: totalDiscs)
        }

        return tagsByKey.keys
            .sorted()
            .compactMap { key in
                guard let value = tagsByKey[key] else {
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

private enum SwiftTagAppleScriptPictureType {
    static let frontCover = 3

    static func appleEventCode(for flacType: Int) -> FourCharCode {
        switch flacType {
        case 0:
            fourCharCode("othe")
        case 1:
            fourCharCode("pngi")
        case 2:
            fourCharCode("othi")
        case 3:
            fourCharCode("frcv")
        case 4:
            fourCharCode("bckc")
        case 5:
            fourCharCode("leaf")
        case 6:
            fourCharCode("medi")
        case 7:
            fourCharCode("lead")
        case 8:
            fourCharCode("arti")
        case 9:
            fourCharCode("cond")
        case 10:
            fourCharCode("band")
        case 11:
            fourCharCode("comp")
        case 12:
            fourCharCode("lyri")
        case 13:
            fourCharCode("locn")
        case 14:
            fourCharCode("sess")
        case 15:
            fourCharCode("perf")
        case 16:
            fourCharCode("capt")
        case 17:
            fourCharCode("fish")
        case 18:
            fourCharCode("illu")
        case 19:
            fourCharCode("logo")
        case 20:
            fourCharCode("pubo")
        default:
            fourCharCode("othe")
        }
    }

    static func flacType(from rawValue: Any?) throws -> Int {
        guard let rawValue else {
            return frontCover
        }

        if let descriptor = rawValue as? NSAppleEventDescriptor {
            let enumCode = descriptor.enumCodeValue
            if enumCode != 0 {
                return try flacType(fromAppleEventCode: UInt32(enumCode))
            }

            let typeCode = descriptor.typeCodeValue
            if typeCode != 0 {
                return try flacType(fromAppleEventCode: UInt32(typeCode))
            }

            if let stringValue = descriptor.stringValue {
                return try flacType(from: stringValue)
            }
        }

        if let number = rawValue as? NSNumber {
            let integerValue = number.intValue
            if (0...20).contains(integerValue) {
                return integerValue
            }

            return try flacType(fromAppleEventCode: number.uint32Value)
        }

        if let string = rawValue as? String {
            return try flacType(from: string)
        }

        if let string = rawValue as? NSString {
            return try flacType(from: string as String)
        }

        throw SwiftTagAppleScriptCommandError.invalidPictureType
    }

    static func defaultDescription(for flacType: Int) -> String {
        switch flacType {
        case 1:
            "32x32 pixels file icon (PNG only)"
        case 2:
            "Other file icon"
        case 3:
            "Cover (front)"
        case 4:
            "Cover (back)"
        case 5:
            "Leaflet page"
        case 6:
            "Media"
        case 7:
            "Lead artist/lead performer/soloist"
        case 8:
            "Artist/performer"
        case 9:
            "Conductor"
        case 10:
            "Band/Orchestra"
        case 11:
            "Composer"
        case 12:
            "Lyricist/text writer"
        case 13:
            "Recording location"
        case 14:
            "During recording"
        case 15:
            "During performance"
        case 16:
            "Movie/video capture"
        case 17:
            "Bright coloured fish"
        case 18:
            "Illustration"
        case 19:
            "Band/artist logotype"
        case 20:
            "Publisher/studio logotype"
        default:
            "Other"
        }
    }

    nonisolated private static func fourCharCode(_ value: String) -> FourCharCode {
        let bytes = Array(value.utf8.prefix(4))
        let paddedBytes = bytes + Array(repeating: UInt8(32), count: max(0, 4 - bytes.count))
        return paddedBytes.prefix(4).reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
    }

    private static func flacType(fromAppleEventCode code: UInt32) throws -> Int {
        for type in 0...20 where appleEventCode(for: type) == code {
            return type
        }

        throw SwiftTagAppleScriptCommandError.invalidPictureType
    }

    private static func flacType(from string: String) throws -> Int {
        let trimmedValue = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let integerValue = Int(trimmedValue), (0...20).contains(integerValue) {
            return integerValue
        }

        let normalizedValue = trimmedValue
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }

        let namesByType: [Int: [String]] = [
            0: ["other", "othe"],
            1: ["pngicon", "pngi"],
            2: ["othericon", "othi"],
            3: ["frontcover", "frcv"],
            4: ["backcover", "bckc"],
            5: ["leaflet", "leaf"],
            6: ["media", "medi"],
            7: ["leadartist", "leadperformer", "soloist", "lead"],
            8: ["artist", "performer", "arti"],
            9: ["conductor", "cond"],
            10: ["band", "orchestra", "bandorchestra"],
            11: ["composer", "comp"],
            12: ["lyricist", "textwriter", "lyri"],
            13: ["location", "recordinglocation", "recordingstudio", "locn"],
            14: ["session", "recordingsession", "sess"],
            15: ["performance", "perf"],
            16: ["capture", "moviecapture", "videocapture", "capt"],
            17: ["brightlycoloredfish", "brightcolouredfish", "fish"],
            18: ["illustration", "illu"],
            19: ["bandlogo", "artistlogo", "logo"],
            20: ["publisherlogo", "studiologo", "pubo"]
        ]

        for (type, names) in namesByType where names.contains(normalizedValue) {
            return type
        }

        throw SwiftTagAppleScriptCommandError.invalidPictureType
    }
}

private enum SwiftTagAppleScriptDescriptorType {
    static let data = fourCharCode("tdta")

    nonisolated private static func fourCharCode(_ value: String) -> DescType {
        let bytes = Array(value.utf8.prefix(4))
        let paddedBytes = bytes + Array(repeating: UInt8(32), count: max(0, 4 - bytes.count))
        return paddedBytes.prefix(4).reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
    }
}

@objc(SwiftTagAppleScriptDataCoercions)
final class SwiftTagAppleScriptDataCoercions: NSObject {
    private static var didRegister = false

    static func register() {
        guard !didRegister else {
            return
        }
        didRegister = true

        NSScriptCoercionHandler.shared().registerCoercer(
            self,
            selector: #selector(coerceAppleEventDescriptor(_:toClass:)),
            toConvertFrom: NSAppleEventDescriptor.self,
            to: NSData.self
        )
        NSScriptCoercionHandler.shared().registerCoercer(
            self,
            selector: #selector(coerceString(_:toClass:)),
            toConvertFrom: NSString.self,
            to: NSData.self
        )
    }

    @objc(coerceAppleEventDescriptor:toClass:)
    static func coerceAppleEventDescriptor(_ value: Any, toClass: AnyClass) -> Any? {
        guard let descriptor = value as? NSAppleEventDescriptor else {
            return nil
        }

        if let stringValue = descriptor.stringValue,
           let decodedData = base64DecodedData(from: stringValue) {
            return decodedData as NSData
        }

        if let stringValue = String(data: descriptor.data, encoding: .utf8),
           let decodedData = base64DecodedData(from: stringValue) {
            return decodedData as NSData
        }

        return descriptor.data as NSData
    }

    @objc(coerceString:toClass:)
    static func coerceString(_ value: Any, toClass: AnyClass) -> Any? {
        guard let string = value as? NSString,
              let data = base64DecodedData(from: string as String) else {
            return nil
        }

        return data as NSData
    }

    private static func base64DecodedData(from rawValue: String) -> Data? {
        let compactValue = rawValue
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        guard !compactValue.isEmpty,
              compactValue.count.isMultiple(of: 4) else {
            return nil
        }

        let allowedCharacters = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
        )
        guard compactValue.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return nil
        }

        return Data(base64Encoded: compactValue)
    }
}

struct SwiftTagAppleScriptPicturePayload: Equatable {
    let type: Int
    let mimeType: String
    let description: String?
    let data: Data
    let specifications: PictureDataSpecifications

    var hasExplicitDescription: Bool {
        description != nil
    }

    static func from(value rawValue: Any) throws -> Self {
        if let picture = rawValue as? SwiftTagScriptPicture,
           let payload = picture.insertionPayload {
            return payload
        }

        if let record = rawValue as? FlacWritablePictureRecord {
            return try make(
                pictureType: record.type,
                mimeType: record.mimeType,
                description: record.description,
                data: record.data
            )
        }

        if let dictionary = rawValue as? [AnyHashable: Any] {
            return try from(dictionary: dictionary, contentsValue: nil)
        }

        if let dictionary = rawValue as? NSDictionary {
            return try from(dictionary: dictionary, contentsValue: nil)
        }

        throw SwiftTagAppleScriptCommandError.invalidPictureObject
    }

    static func from(properties: NSDictionary?, contentsValue: Any?) throws -> Self {
        try from(dictionary: properties ?? [:], contentsValue: contentsValue)
    }

    func record(defaultDescription: String? = nil) -> FlacWritablePictureRecord {
        FlacWritablePictureRecord(
            type: type,
            mimeType: mimeType,
            description: description ?? defaultDescription ?? SwiftTagAppleScriptPictureType.defaultDescription(for: type),
            data: data,
            width: specifications.width,
            height: specifications.height,
            depth: specifications.depth,
            colors: specifications.colors
        )
    }

    private static func from(dictionary: NSDictionary, contentsValue: Any?) throws -> Self {
        var bridgedDictionary: [AnyHashable: Any] = [:]
        for case let (key as AnyHashable, value) in dictionary {
            bridgedDictionary[key] = value
        }
        return try from(dictionary: bridgedDictionary, contentsValue: contentsValue)
    }

    private static func from(dictionary: [AnyHashable: Any], contentsValue: Any?) throws -> Self {
        let pictureTypeValue = value(
            in: dictionary,
            matching: ["picturetype", "pcty", "type"]
        )
        let rawDataValue = value(
            in: dictionary,
            matching: ["data", "picturedata", "contents", "objectdata", "pdat", "pcda", "tdta"]
        ) ?? contentsValue
        let mimeTypeValue = value(
            in: dictionary,
            matching: ["mimetype", "mime"]
        )
        let descriptionEntry = entry(
            in: dictionary,
            matching: ["description", "picturedescription", "objectdescription", "tdsc"]
        )

        return try make(
            pictureType: SwiftTagAppleScriptPictureType.flacType(from: pictureTypeValue),
            mimeType: stringValue(from: mimeTypeValue),
            description: descriptionEntry.map { stringValue(from: $0.value) ?? "" },
            data: coercedDataValue(from: rawDataValue)
        )
    }

    private static func make(
        pictureType: Int,
        mimeType: String?,
        description: String?,
        data: Data?
    ) throws -> Self {
        guard let data, !data.isEmpty else {
            throw SwiftTagAppleScriptCommandError.missingPictureData
        }

        let specifications = PictureDataUtilities.computedSpecifications(from: data)
        guard specifications.width > 0, specifications.height > 0 else {
            throw SwiftTagAppleScriptCommandError.invalidPictureData
        }

        let dataDerivedMimeType = PictureDataUtilities.normalizedMimeType(mimeType: "", data: data)
        let normalizedMimeType = dataDerivedMimeType == "application/octet-stream"
            ? PictureDataUtilities.normalizedMimeType(mimeType: mimeType ?? "", data: data)
            : dataDerivedMimeType
        let normalizedDescription = description ?? nil

        let pictureDataValidation = FlacPictureDataBudget.validation(
            mimeType: normalizedMimeType,
            currentDescription: normalizedDescription ?? SwiftTagAppleScriptPictureType.defaultDescription(for: pictureType),
            proposedPictureData: data
        )
        let descriptionValidation = FlacPictureDescriptionBudget.validation(
            mimeType: normalizedMimeType,
            pictureData: data,
            proposedDescription: normalizedDescription ?? SwiftTagAppleScriptPictureType.defaultDescription(for: pictureType)
        )
        guard pictureDataValidation.isValid, descriptionValidation.isValid else {
            throw SwiftTagAppleScriptCommandError.pictureDataTooLarge
        }

        return Self(
            type: pictureType,
            mimeType: normalizedMimeType,
            description: normalizedDescription,
            data: data,
            specifications: specifications
        )
    }

    private static func entry(
        in dictionary: [AnyHashable: Any],
        matching names: Set<String>
    ) -> (key: AnyHashable, value: Any)? {
        dictionary.first { names.contains(normalizedPropertyName($0.key)) }
    }

    private static func value(in dictionary: [AnyHashable: Any], matching names: Set<String>) -> Any? {
        entry(in: dictionary, matching: names)?.value
    }

    private static func firstCoercibleDataValue(in values: [Any?]) -> Any? {
        values.first { coercedDataValue(from: $0) != nil } ?? nil
    }

    private static func firstCoercibleDataValue(in dictionary: [AnyHashable: Any]) -> Any? {
        dictionary.values.first { coercedDataValue(from: $0) != nil }
    }

    private static func normalizedPropertyName(_ rawKey: AnyHashable) -> String {
        if let string = rawKey as? String {
            return normalizePropertyString(string)
        }

        if let string = rawKey as? NSString {
            return normalizePropertyString(string as String)
        }

        if let number = rawKey as? NSNumber {
            let code = number.uint32Value
            if let codeString = fourCharString(from: code) {
                return normalizePropertyString(codeString)
            }
        }

        return normalizePropertyString(String(describing: rawKey))
    }

    private static func normalizePropertyString(_ string: String) -> String {
        string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func fourCharString(from code: UInt32) -> String? {
        let bytes = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        guard bytes.allSatisfy({ $0 == 32 || (33...126).contains($0) }) else {
            return nil
        }

        return String(bytes: bytes, encoding: .ascii)
    }

    private static func stringValue(from rawValue: Any?) -> String? {
        switch rawValue {
        case let value as String:
            return value
        case let value as NSString:
            return value as String
        case let value as NSNumber:
            return value.stringValue
        case let descriptor as NSAppleEventDescriptor:
            return descriptor.stringValue
        case nil:
            return nil
        default:
            return String(describing: rawValue!)
        }
    }

    fileprivate static func coercedDataValue(from rawValue: Any?) -> Data? {
        switch rawValue {
        case let value as Data:
            return imageDataOrDecodedBase64Data(from: value)
        case let value as NSData:
            return imageDataOrDecodedBase64Data(from: value as Data)
        case let value as String:
            return base64DecodedData(from: value)
        case let value as NSString:
            return base64DecodedData(from: value as String)
        case let descriptor as NSAppleEventDescriptor:
            let descriptorData = descriptor.data as Data
            if descriptor.descriptorType == SwiftTagAppleScriptDescriptorType.data {
                return imageDataOrDecodedBase64Data(from: descriptorData)
            }
            if let stringValue = descriptor.stringValue,
               let data = base64DecodedData(from: stringValue) {
                return data
            }
            if let imageData = imageData(from: descriptorData) {
                return imageData
            }
            guard let coercedData = descriptor
                .coerce(toDescriptorType: SwiftTagAppleScriptDescriptorType.data)?
                .data as Data? else {
                return nil
            }
            return imageDataOrDecodedBase64Data(from: coercedData)
        case nil:
            return nil
        default:
            return nil
        }
    }

    private static func imageDataOrDecodedBase64Data(from data: Data) -> Data {
        if let imageData = imageData(from: data) {
            return imageData
        }

        guard let stringValue = String(data: data, encoding: .utf8),
              let decodedData = base64DecodedData(from: stringValue) else {
            return data
        }

        return decodedData
    }

    private static func imageData(from data: Data) -> Data? {
        let specifications = PictureDataUtilities.computedSpecifications(from: data)
        guard specifications.width > 0, specifications.height > 0 else {
            return nil
        }

        return data
    }

    private static func base64DecodedData(from rawValue: String) -> Data? {
        let compactValue = rawValue
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        guard !compactValue.isEmpty,
              compactValue.count.isMultiple(of: 4) else {
            return nil
        }

        let allowedCharacters = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
        )
        guard compactValue.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return nil
        }

        return Data(base64Encoded: compactValue)
    }
}

extension NSData {
    @objc(scriptingDataDescriptor)
    var swiftTagScriptingDataDescriptor: NSAppleEventDescriptor? {
        NSAppleEventDescriptor(
            descriptorType: SwiftTagAppleScriptDescriptorType.data,
            data: self as Data
        )
    }

    @objc(scriptingPictureDataDescriptor)
    var swiftTagScriptingPictureDataDescriptor: NSAppleEventDescriptor? {
        swiftTagScriptingDataDescriptor
    }

    @objc(scriptingAnyDescriptor)
    var swiftTagScriptingAnyDescriptor: NSAppleEventDescriptor? {
        swiftTagScriptingDataDescriptor
    }
}

@objc(SwiftTagScriptFileURL)
final class SwiftTagScriptFileURL: NSObject {
    fileprivate let url: URL

    init(_ url: URL) {
        self.url = url.standardizedFileURL
        super.init()
    }

    @objc(path)
    var path: String {
        url.path
    }

    @objc(fileURLValue)
    var fileURLValue: NSURL {
        url as NSURL
    }

    @objc(scriptingAnyDescriptor)
    var scriptingAnyDescriptor: NSAppleEventDescriptor? {
        scriptingFileDescriptor
    }

    @objc(scriptingFileDescriptor)
    var scriptingFileDescriptor: NSAppleEventDescriptor? {
        NSAppleEventDescriptor(fileURL: url)
    }

    override var description: String {
        url.path
    }

    override var hash: Int {
        SwiftTagAppleScriptFileValue.normalizedPath(from: url).hashValue
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let otherPath = SwiftTagAppleScriptFileValue.normalizedPath(from: object) else {
            return false
        }

        return SwiftTagAppleScriptFileValue.normalizedPath(from: url) == otherPath
    }

    @objc(scriptingIsEqualTo:)
    override func scriptingIsEqual(to object: Any?) -> Bool {
        isEqual(object)
    }
}

private enum SwiftTagAppleScriptFileValue {
    static func normalizedPath(from value: Any?) -> String? {
        switch value {
        case let fileURL as SwiftTagScriptFileURL:
            return normalizedPath(from: fileURL.url)
        case let url as URL where url.isFileURL:
            return normalizedPath(from: url)
        case let url as NSURL where url.isFileURL:
            return normalizedPath(from: url as URL)
        case let descriptor as NSAppleEventDescriptor:
            if let fileURL = descriptor.fileURLValue {
                return normalizedPath(from: fileURL as URL)
            }
            if let stringValue = descriptor.stringValue {
                return normalizedPath(fromPathString: stringValue)
            }
            return nil
        case let string as String:
            return normalizedPath(fromPathString: string)
        case let string as NSString:
            return normalizedPath(fromPathString: string as String)
        default:
            return nil
        }
    }

    private static func normalizedPath(fromPathString rawValue: String) -> String? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmedValue), url.isFileURL {
            return normalizedPath(from: url)
        }

        return normalizedPath(from: URL(fileURLWithPath: trimmedValue))
    }

    private static func normalizedPath(from url: URL) -> String {
        url
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }
}

@objc(SwiftTagScriptColor)
final class SwiftTagScriptColor: NSObject {
    private var redComponent: Double
    private var greenComponent: Double
    private var blueComponent: Double
    private var alphaComponent: Double

    @objc
    override init() {
        redComponent = 0
        greenComponent = 0
        blueComponent = 0
        alphaComponent = 1
        super.init()
    }

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        redComponent = Self.clamped(red)
        greenComponent = Self.clamped(green)
        blueComponent = Self.clamped(blue)
        alphaComponent = Self.clamped(alpha)
        super.init()
    }

    convenience init(nsColor: NSColor, fallback: NSColor) {
        let resolvedColor = Self.resolvedColor(nsColor, fallback: fallback)
        self.init(
            red: Double(resolvedColor.redComponent),
            green: Double(resolvedColor.greenComponent),
            blue: Double(resolvedColor.blueComponent),
            alpha: Double(resolvedColor.alphaComponent)
        )
    }

    @objc(red)
    var red: Double {
        get { redComponent }
        set {
            redComponent = Self.clamped(newValue)
        }
    }

    @objc(green)
    var green: Double {
        get { greenComponent }
        set {
            greenComponent = Self.clamped(newValue)
        }
    }

    @objc(blue)
    var blue: Double {
        get { blueComponent }
        set {
            blueComponent = Self.clamped(newValue)
        }
    }

    @objc(alpha)
    var alpha: Double {
        get { alphaComponent }
        set {
            alphaComponent = Self.clamped(newValue)
        }
    }

    var nsColor: NSColor {
        NSColor(
            deviceRed: CGFloat(redComponent),
            green: CGFloat(greenComponent),
            blue: CGFloat(blueComponent),
            alpha: CGFloat(alphaComponent)
        )
    }

    var scriptRecord: NSDictionary {
        [
            "red": NSNumber(value: redComponent),
            "green": NSNumber(value: greenComponent),
            "blue": NSNumber(value: blueComponent),
            "alpha": NSNumber(value: alphaComponent)
        ] as NSDictionary
    }

    var archivedRawValue: String {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: nsColor,
            requiringSecureCoding: true
        ) else {
            return ""
        }

        return data.base64EncodedString()
    }

    static func from(rawValue: String?, fallback: NSColor) -> SwiftTagScriptColor {
        let color = nsColor(from: rawValue, fallback: fallback)
        return SwiftTagScriptColor(nsColor: color, fallback: fallback)
    }

    static func from(scriptValue rawValue: Any?, fallback: NSColor) -> SwiftTagScriptColor? {
        switch rawValue {
        case let color as SwiftTagScriptColor:
            return color
        case let color as NSColor:
            return SwiftTagScriptColor(nsColor: color, fallback: fallback)
        case let dictionary as [AnyHashable: Any]:
            return from(dictionary: dictionary, fallback: fallback)
        case let dictionary as NSDictionary:
            var bridgedDictionary: [AnyHashable: Any] = [:]
            for case let (key as AnyHashable, value) in dictionary {
                bridgedDictionary[key] = value
            }
            return from(dictionary: bridgedDictionary, fallback: fallback)
        case let descriptor as NSAppleEventDescriptor where descriptor.isRecordDescriptor:
            return from(dictionary: dictionary(from: descriptor), fallback: fallback)
        default:
            return nil
        }
    }

    static func nsColor(from rawValue: String?, fallback: NSColor) -> NSColor {
        guard
            let rawValue,
            let data = Data(base64Encoded: rawValue),
            let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        else {
            return resolvedColor(fallback, fallback: fallback)
        }

        return resolvedColor(color, fallback: fallback)
    }

    private static func from(
        dictionary: [AnyHashable: Any],
        fallback: NSColor
    ) -> SwiftTagScriptColor {
        let fallbackColor = SwiftTagScriptColor(nsColor: fallback, fallback: fallback)
        return SwiftTagScriptColor(
            red: doubleValue(in: dictionary, matching: ["red", "redc"]) ?? fallbackColor.red,
            green: doubleValue(in: dictionary, matching: ["green", "grec"]) ?? fallbackColor.green,
            blue: doubleValue(in: dictionary, matching: ["blue", "bluc"]) ?? fallbackColor.blue,
            alpha: doubleValue(in: dictionary, matching: ["alpha", "alph"]) ?? fallbackColor.alpha
        )
    }

    private static func dictionary(from descriptor: NSAppleEventDescriptor) -> [AnyHashable: Any] {
        guard descriptor.numberOfItems > 0 else {
            return [:]
        }

        var dictionary: [AnyHashable: Any] = [:]
        for index in 1...descriptor.numberOfItems {
            let keyword = descriptor.keywordForDescriptor(at: index)
            guard keyword != 0,
                  let value = descriptor.atIndex(index) else {
                continue
            }
            dictionary[NSNumber(value: keyword)] = value
        }
        return dictionary
    }

    private static func doubleValue(
        in dictionary: [AnyHashable: Any],
        matching names: Set<String>
    ) -> Double? {
        dictionary
            .first { names.contains(normalizedPropertyName($0.key)) }
            .flatMap { doubleValue(from: $0.value) }
    }

    private static func doubleValue(from rawValue: Any?) -> Double? {
        switch rawValue {
        case let value as Double:
            return value
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value)
        case let value as NSString:
            return Double(value as String)
        case let descriptor as NSAppleEventDescriptor:
            if let stringValue = descriptor.stringValue,
               let value = Double(stringValue) {
                return value
            }
            if let coerced = descriptor.coerce(toDescriptorType: typeIEEE64BitFloatingPoint) {
                return coerced.doubleValue
            }
            if descriptor.descriptorType == typeSInt32 {
                return Double(descriptor.int32Value)
            }
            return nil
        default:
            return nil
        }
    }

    private static func normalizedPropertyName(_ rawKey: AnyHashable) -> String {
        if let string = rawKey as? String {
            return normalizePropertyString(string)
        }

        if let string = rawKey as? NSString {
            return normalizePropertyString(string as String)
        }

        if let number = rawKey as? NSNumber,
           let codeString = fourCharString(from: number.uint32Value) {
            return normalizePropertyString(codeString)
        }

        return normalizePropertyString(String(describing: rawKey))
    }

    private static func normalizePropertyString(_ string: String) -> String {
        string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func fourCharString(from code: UInt32) -> String? {
        let bytes = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        guard bytes.allSatisfy({ $0 == 32 || (33...126).contains($0) }) else {
            return nil
        }

        return String(bytes: bytes, encoding: .ascii)
    }

    private static func resolvedColor(_ color: NSColor, fallback: NSColor) -> NSColor {
        color.usingColorSpace(.deviceRGB)
            ?? fallback.usingColorSpace(.deviceRGB)
            ?? NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 1)
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

@MainActor
@objc(SwiftTagScriptPicture)
final class SwiftTagScriptPicture: NSObject {
    private struct AttachedReference: Hashable {
        let sessionID: UUID
        let trackID: UUID
        let pictureIndex: Int
    }

    private struct AttachedContainer: Hashable {
        let sessionID: UUID
        let trackID: UUID
    }

    private enum Storage {
        case attached(sessionID: UUID, trackID: UUID, pictureIndex: Int)
        case detached(SwiftTagAppleScriptPicturePayload?)
    }

    private var storage: Storage
    private var detachedPictureType: Int?
    private var detachedMimeType: String?
    private var detachedDescription: String?
    private var detachedData: Data?
    private var stablePictureIdentity: SwiftTagAppleScriptPictureIdentity?

    @objc
    override init() {
        storage = .detached(nil)
        stablePictureIdentity = nil
        super.init()
    }

    init(payload: SwiftTagAppleScriptPicturePayload) {
        storage = .detached(payload)
        detachedPictureType = payload.type
        detachedMimeType = payload.mimeType
        detachedDescription = payload.description
        detachedData = payload.data
        stablePictureIdentity = nil
        super.init()
    }

    init(sessionID: UUID, trackID: UUID, pictureIndex: Int) {
        storage = .attached(sessionID: sessionID, trackID: trackID, pictureIndex: pictureIndex)
        stablePictureIdentity = SwiftTagAppleScriptController.shared.pictureIdentity(
            forSessionID: sessionID,
            trackID: trackID,
            pictureIndex: pictureIndex
        )
        super.init()
    }

    @objc(id)
    var id: String? {
        pictureIdentity?.id.uuidString ?? stablePictureIdentity?.id.uuidString
    }

    @objc(poolId)
    var poolId: String? {
        pictureIdentity?.poolId.uuidString
    }

    @objc(pictureType)
    var pictureType: NSNumber? {
        guard let pictureSnapshot else {
            guard let detachedPictureType else {
                return nil
            }
            return NSNumber(value: SwiftTagAppleScriptPictureType.appleEventCode(for: detachedPictureType))
        }

        return NSNumber(value: SwiftTagAppleScriptPictureType.appleEventCode(for: pictureSnapshot.type))
    }

    @objc(mimeType)
    var mimeType: String? {
        if let mimeType = pictureSnapshot?.mimeType.appleScriptNonEmptyValue {
            return mimeType
        }
        return detachedMimeType?.appleScriptNonEmptyValue
    }

    @objc(pictureDescription)
    var pictureDescription: String? {
        get {
            if let description = pictureSnapshot?.description {
                return description
            }
            return detachedDescription
        }
        set {
            do {
                try updateDescription(newValue ?? "")
            } catch {
                _ = NSScriptCommand.current()?.fail(error)
            }
        }
    }

    override func setValue(_ value: Any?, forKey key: String) {
        do {
            switch key {
            case "pictureType":
                try setDetachedPictureType(value)
            case "mimeType":
                try setDetachedMimeType(value)
            case "pictureDescription", "objectDescription", "description":
                try updateDescription(scriptString(from: value) ?? "")
            case "data", "contents":
                try updateData(value)
            case "width", "height", "colorDepth", "colors":
                return
            default:
                super.setValue(value, forKey: key)
            }
        } catch {
            _ = NSScriptCommand.current()?.fail(error)
        }
    }

    private func setDetachedPictureType(_ value: Any?) throws {
        guard case .detached = storage else {
            throw SwiftTagAppleScriptCommandError.invalidPictureObject
        }

        detachedPictureType = try SwiftTagAppleScriptPictureType.flacType(from: value)
        try rebuildDetachedPayloadIfPossible()
    }

    private func setDetachedMimeType(_ value: Any?) throws {
        guard case .detached = storage else {
            throw SwiftTagAppleScriptCommandError.invalidPictureObject
        }

        detachedMimeType = scriptString(from: value)
        try rebuildDetachedPayloadIfPossible()
    }

    private func setDetachedData(_ value: Any?) throws {
        guard case .detached = storage else {
            throw SwiftTagAppleScriptCommandError.invalidPictureObject
        }

        detachedData = scriptData(from: value)
        try rebuildDetachedPayloadIfPossible()
    }

    private func rebuildDetachedPayloadIfPossible() throws {
        guard let detachedData else {
            storage = .detached(nil)
            return
        }

        let type = detachedPictureType ?? SwiftTagAppleScriptPictureType.frontCover
        let specifications = PictureDataUtilities.computedSpecifications(from: detachedData)
        let record = FlacWritablePictureRecord(
            type: type,
            mimeType: detachedMimeType ?? "",
            description: detachedDescription ?? SwiftTagAppleScriptPictureType.defaultDescription(for: type),
            data: detachedData,
            width: specifications.width,
            height: specifications.height,
            depth: specifications.depth,
            colors: specifications.colors
        )
        let payload = try SwiftTagAppleScriptPicturePayload.from(value: record)
        storage = .detached(payload)
        detachedPictureType = payload.type
        detachedMimeType = payload.mimeType
        detachedDescription = payload.description
        self.detachedData = payload.data
    }

    private func scriptString(from rawValue: Any?) -> String? {
        switch rawValue {
        case let value as String:
            return value
        case let value as NSString:
            return value as String
        case let value as NSNumber:
            return value.stringValue
        case let descriptor as NSAppleEventDescriptor:
            return descriptor.stringValue
        case nil:
            return nil
        default:
            return String(describing: rawValue!)
        }
    }

    private func scriptData(from rawValue: Any?) -> Data? {
        SwiftTagAppleScriptPicturePayload.coercedDataValue(from: rawValue)
    }

    @objc(width)
    var width: NSNumber? {
        availableIntegerValue(\.width)
    }

    @objc(height)
    var height: NSNumber? {
        availableIntegerValue(\.height)
    }

    @objc(colorDepth)
    var colorDepth: NSNumber? {
        availableIntegerValue(\.depth)
    }

    @objc(colors)
    var colors: NSNumber? {
        guard let pictureSnapshot else {
            return nil
        }

        guard pictureSnapshot.colors > 0 || pictureSnapshot.hasAvailableImageMetadata else {
            return nil
        }

        return NSNumber(value: pictureSnapshot.colors)
    }

    @objc(data)
    var data: NSData? {
        get {
            guard let data = pictureSnapshot?.data else {
                return nil
            }

            guard !data.isEmpty else {
                return NSData()
            }

            return data.withUnsafeBytes { bytes in
                NSData(bytes: bytes.baseAddress, length: data.count)
            }
        }
        set {
            do {
                try updateData(newValue)
            } catch {
                _ = NSScriptCommand.current()?.fail(error)
            }
        }
    }

    @objc(scriptingSpecifierDescriptor)
    var scriptingSpecifierDescriptor: NSAppleEventDescriptor? {
        objectSpecifier?.descriptor
    }

    override func scriptingValue(for objectSpecifier: NSScriptObjectSpecifier) -> Any? {
        switch objectSpecifier.key {
        case "width":
            return appleScriptMetricValue(width)
        case "height":
            return appleScriptMetricValue(height)
        case "colorDepth":
            return appleScriptMetricValue(colorDepth)
        case "colors":
            return appleScriptMetricValue(colors)
        default:
            return super.scriptingValue(for: objectSpecifier)
        }
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard case let .attached(sessionID, trackID, pictureIndex) = storage else {
            return nil
        }

        guard let track = SwiftTagAppleScriptController.shared.track(
                forSessionID: sessionID,
                trackID: trackID
              ),
              let trackClassDescription = NSScriptClassDescription(for: SwiftTagScriptTrack.self),
              let containerSpecifier = track.objectSpecifier else {
            return nil
        }

        if let id {
            return NSUniqueIDSpecifier(
                containerClassDescription: trackClassDescription,
                containerSpecifier: containerSpecifier,
                key: "pictures",
                uniqueID: id
            )
        }

        return NSIndexSpecifier(
            containerClassDescription: trackClassDescription,
            containerSpecifier: containerSpecifier,
            key: "pictures",
            index: pictureIndex
        )
    }

    var insertionPayload: SwiftTagAppleScriptPicturePayload? {
        switch storage {
        case .attached:
            guard let pictureSnapshot else {
                return nil
            }

            return try? SwiftTagAppleScriptPicturePayload.from(value: pictureSnapshot)
        case .detached(let payload):
            return payload
        }
    }

    func attach(sessionID: UUID, trackID: UUID, pictureIndex: Int) {
        storage = .attached(sessionID: sessionID, trackID: trackID, pictureIndex: pictureIndex)
        stablePictureIdentity = SwiftTagAppleScriptController.shared.pictureIdentity(
            forSessionID: sessionID,
            trackID: trackID,
            pictureIndex: pictureIndex
        )
    }

    func delete() throws {
        try Self.delete([self])
    }

    static func delete(_ pictures: [SwiftTagScriptPicture]) throws {
        var pictureIndexesByContainer: [AttachedContainer: Set<Int>] = [:]
        for picture in pictures {
            guard let reference = picture.attachedReference else {
                continue
            }

            let container = AttachedContainer(
                sessionID: reference.sessionID,
                trackID: reference.trackID
            )
            pictureIndexesByContainer[container, default: []].insert(reference.pictureIndex)
        }

        let orderedContainers = pictureIndexesByContainer.keys.sorted {
            if $0.sessionID.uuidString == $1.sessionID.uuidString {
                return $0.trackID.uuidString < $1.trackID.uuidString
            }
            return $0.sessionID.uuidString < $1.sessionID.uuidString
        }

        for container in orderedContainers {
            let indexes = pictureIndexesByContainer[container, default: []].sorted(by: >)
            for index in indexes {
                try SwiftTagAppleScriptController.shared.deletePicture(
                    forSessionID: container.sessionID,
                    trackID: container.trackID,
                    pictureIndex: index
                )
            }
        }
    }

    private var pictureSnapshot: FlacWritablePictureRecord? {
        switch storage {
        case .attached(let sessionID, let trackID, let pictureIndex):
            let currentIndex = currentPictureIndex(
                sessionID: sessionID,
                trackID: trackID,
                fallback: pictureIndex
            )
            return SwiftTagAppleScriptController.shared.pictureSnapshot(
                forSessionID: sessionID,
                trackID: trackID,
                pictureIndex: currentIndex
            )
        case .detached(let payload):
            return payload?.record()
        }
    }

    private var pictureIdentity: SwiftTagAppleScriptPictureIdentity? {
        switch storage {
        case .attached(let sessionID, let trackID, let pictureIndex):
            let currentIndex = currentPictureIndex(
                sessionID: sessionID,
                trackID: trackID,
                fallback: pictureIndex
            )
            return SwiftTagAppleScriptController.shared.pictureIdentity(
                forSessionID: sessionID,
                trackID: trackID,
                pictureIndex: currentIndex
            )
        case .detached:
            return nil
        }
    }

    private var attachedReference: AttachedReference? {
        guard case let .attached(sessionID, trackID, pictureIndex) = storage else {
            return nil
        }

        let currentIndex = currentPictureIndex(
            sessionID: sessionID,
            trackID: trackID,
            fallback: pictureIndex
        )
        return AttachedReference(
            sessionID: sessionID,
            trackID: trackID,
            pictureIndex: currentIndex
        )
    }

    private func currentPictureIndex(
        sessionID: UUID,
        trackID: UUID,
        fallback pictureIndex: Int
    ) -> Int {
        guard let stablePictureID = stablePictureIdentity?.id,
              let resolvedIndex = SwiftTagAppleScriptController.shared.pictureIndex(
                forSessionID: sessionID,
                trackID: trackID,
                uniqueID: stablePictureID
              ) else {
            return pictureIndex
        }

        return resolvedIndex
    }

    private func availableIntegerValue(_ keyPath: KeyPath<FlacWritablePictureRecord, Int>) -> NSNumber? {
        guard let value = pictureSnapshot?[keyPath: keyPath] else {
            return nil
        }

        guard value > 0 else {
            return nil
        }

        return NSNumber(value: value)
    }

    private func appleScriptMetricValue(_ value: NSNumber?) -> Any {
        value ?? SwiftTagAppleScriptMissingValue.descriptor()
    }

    private func updateDescription(_ description: String) throws {
        switch storage {
        case .attached(let sessionID, let trackID, let pictureIndex):
            try SwiftTagAppleScriptController.shared.updatePictureDescription(
                description,
                forSessionID: sessionID,
                trackID: trackID,
                pictureIndex: pictureIndex
            )
        case .detached(let payload):
            detachedDescription = description
            guard let payload else {
                try rebuildDetachedPayloadIfPossible()
                return
            }

            storage = .detached(
                try SwiftTagAppleScriptPicturePayload.from(
                    value: FlacWritablePictureRecord(
                        type: payload.type,
                        mimeType: payload.mimeType,
                        description: description,
                        data: payload.data,
                        width: payload.specifications.width,
                        height: payload.specifications.height,
                        depth: payload.specifications.depth,
                        colors: payload.specifications.colors
                    )
                )
            )
            if let updatedPayload = insertionPayload {
                detachedPictureType = updatedPayload.type
                detachedMimeType = updatedPayload.mimeType
                detachedDescription = updatedPayload.description
                detachedData = updatedPayload.data
            }
        }
    }

    private func updateData(_ rawValue: Any?) throws {
        switch storage {
        case .attached(let sessionID, let trackID, let pictureIndex):
            let payload = try replacementPayload(data: scriptData(from: rawValue))
            let updatedIndex = try SwiftTagAppleScriptController.shared.replacePicture(
                payload,
                forSessionID: sessionID,
                trackID: trackID,
                pictureIndex: pictureIndex
            )
            storage = .attached(sessionID: sessionID, trackID: trackID, pictureIndex: updatedIndex)
        case .detached:
            try setDetachedData(rawValue)
        }
    }

    private func replacementPayload(data: Data?) throws -> SwiftTagAppleScriptPicturePayload {
        guard let currentRecord = pictureSnapshot else {
            throw SwiftTagAppleScriptCommandError.invalidPictureObject
        }

        return try SwiftTagAppleScriptPicturePayload.from(
            value: FlacWritablePictureRecord(
                type: currentRecord.type,
                mimeType: currentRecord.mimeType,
                description: currentRecord.description,
                data: data ?? Data(),
                width: currentRecord.width,
                height: currentRecord.height,
                depth: currentRecord.depth,
                colors: currentRecord.colors
            )
        )
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

    @objc(id)
    var id: String? {
        key
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
            snapshot?.value.appleScriptNonEmptyValue
        }
        set {
            do {
                try updateValue(newValue)
            } catch {
                _ = NSScriptCommand.current()?.fail(error)
            }
        }
    }

    @objc(scriptingSpecifierDescriptor)
    var scriptingSpecifierDescriptor: NSAppleEventDescriptor? {
        objectSpecifier?.descriptor
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

    func delete() throws {
        guard case let .attached(sessionID, trackID, key) = storage else {
            return
        }

        try SwiftTagAppleScriptController.shared.deleteTag(
            key: key,
            forSessionID: sessionID,
            trackID: trackID
        )
    }

    func attach(sessionID: UUID, trackID: UUID, key: String) {
        storage = .attached(
            sessionID: sessionID,
            trackID: trackID,
            key: SwiftTagAppleScriptTagKey.normalizedKey(key)
        )
    }
}

@MainActor
@objc(SwiftTagScriptTrack)
final class SwiftTagScriptTrack: NSObject {
    private static let scriptPropertyTagKeys: [String: String] = [
        "album": TagKey.album,
        "albumArtist": TagKey.albumArtist,
        "artist": TagKey.artist,
        "comment": TagKey.comment,
        "compilation": TagKey.compilation,
        "composer": TagKey.composer,
        "conductor": "CONDUCTOR",
        "copyright": "COPYRIGHT",
        "releaseDate": TagKey.date,
        "trackDescription": TagKey.description,
        "director": "DIRECTOR",
        "discCount": SwiftTagAppleScriptTagKey.totalDiscs,
        "discNumber": TagKey.discNumber,
        "encodedBy": "ENCODED_BY",
        "encodedUsing": "ENCODED_USING",
        "encoder": "ENCODER",
        "encoderOptions": "ENCODER_OPTIONS",
        "genre": TagKey.genre,
        "isrc": "ISRC",
        "license": "LICENSE",
        "lineage": "LINEAGE",
        "location": TagKey.location,
        "narrator": "NARRATOR",
        "performer": "PERFORMER",
        "producer": "PRODUCER",
        "rating": "RATING",
        "replayAlbumGain": "REPLAYGAIN_ALBUM_GAIN",
        "replayAlbumPeak": "REPLAYGAIN_ALBUM_PEAK",
        "replayTrackGain": "REPLAYGAIN_TRACK_GAIN",
        "replayTrackPeak": "REPLAYGAIN_TRACK_PEAK",
        "sortAlbum": "ALBUMSORT",
        "sortAlbumArtist": "ALBUMARTISTSORT",
        "sortArtist": "ARTISTSORT",
        "sortComposer": "COMPOSERSORT",
        "sortTitle": "TITLESORT",
        "source": "SOURCE",
        "title": TagKey.title,
        "trackCount": SwiftTagAppleScriptTagKey.totalTracks,
        "trackNumber": TagKey.trackNumber,
        "vendor": "VENDOR",
        "trackVersion": "VERSION"
    ]

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
            currentTextValue(for: [TagKey.album])
        }
        set {
            updateTagValue(TagKey.album, to: newValue)
        }
    }

    @objc(albumArtist)
    var albumArtist: String? {
        get {
            currentTextValue(for: [TagKey.albumArtist])
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
            currentTextValue(for: [TagKey.comment])
        }
        set {
            updateTagValue(TagKey.comment, to: newValue)
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
    
    @objc(conductor)
    var conductor: String? {
        get {
            currentTextValue(for: ["CONDUCTOR"])
        }
        set {
            updateTagValue("CONDUCTOR", to: newValue)
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
            currentIntegerValue(for: ["TOTALTRACKS", "TRACKTOTAL"])
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

    @nonobjc
    var fileURL: URL? {
        trackSnapshot?.sourceFileURL?.standardizedFileURL
    }

    @objc(fileURL)
    var scriptingFileURL: SwiftTagScriptFileURL? {
        fileURL.map(SwiftTagScriptFileURL.init)
    }

    @objc(trackLocked)
    var trackLocked: Bool {
        get {
            trackSnapshot?.isLocked == true
        }
        set {
            do {
                try SwiftTagAppleScriptController.shared.setTrackLocked(
                    newValue,
                    forSessionID: sessionIDValue,
                    trackID: trackIDValue
                )
            } catch {
                _ = NSScriptCommand.current()?.fail(error)
            }
        }
    }

    @objc(modified)
    var modified: Bool {
        SwiftTagAppleScriptController.shared.trackIsModified(
            forSessionID: sessionIDValue,
            trackID: trackIDValue
        )
    }

    @objc(tags)
    var tags: [SwiftTagScriptTag] {
        SwiftTagAppleScriptController.shared.tags(
            forSessionID: sessionIDValue,
            trackID: trackIDValue
        )
    }

    @objc(pictures)
    var pictures: [SwiftTagScriptPicture] {
        SwiftTagAppleScriptController.shared.pictures(
            forSessionID: sessionIDValue,
            trackID: trackIDValue
        )
    }

    @objc(countOfTags)
    var countOfTags: Int {
        tags.count
    }

    @objc(countOfPictures)
    var countOfPictures: Int {
        pictures.count
    }

    @objc(objectInTagsAtIndex:)
    func objectInTags(at index: Int) -> SwiftTagScriptTag {
        tags[index]
    }

    @objc(objectInPicturesAtIndex:)
    func objectInPictures(at index: Int) -> SwiftTagScriptPicture {
        pictures[index]
    }

    override func newScriptingObject(
        of objectClass: AnyClass,
        forValueForKey key: String,
        withContentsValue contentsValue: Any?,
        properties: [String: Any]
    ) -> Any? {
        do {
            if key == "tags", objectClass == SwiftTagScriptTag.self {
                let payload = try SwiftTagAppleScriptTagPayload.from(value: properties as NSDictionary)
                return SwiftTagScriptTag(key: payload.key, value: payload.value)
            }

            if key == "pictures", objectClass == SwiftTagScriptPicture.self {
                let payload = try SwiftTagAppleScriptPicturePayload.from(
                    properties: properties as NSDictionary,
                    contentsValue: contentsValue
                )
                return SwiftTagScriptPicture(payload: payload)
            }

            return nil
        } catch {
            _ = NSScriptCommand.current()?.fail(error)
            return nil
        }
    }

    @objc(valueInTagsWithUniqueID:)
    func valueInTags(withUniqueID uniqueID: Any) -> Any? {
        SwiftTagAppleScriptController.shared.tag(
            forSessionID: sessionIDValue,
            trackID: trackIDValue,
            uniqueID: uniqueID
        )
    }

    @objc(valueInPicturesWithUniqueID:)
    func valueInPictures(withUniqueID uniqueID: Any) -> Any? {
        SwiftTagAppleScriptController.shared.picture(
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
            if let tag = value as? SwiftTagScriptTag {
                tag.attach(sessionID: sessionIDValue, trackID: trackIDValue, key: payload.key)
            }
        } catch {
            _ = NSScriptCommand.current()?.fail(error)
        }
    }

    @objc(insertInTags:atIndex:)
    func insertInTags(_ value: Any, at index: Int) {
        insertObject(value, inTagsAt: index)
    }

    @objc(insertInTags:)
    func insertInTags(_ value: Any) {
        insertObject(value, inTagsAt: tags.count)
    }

    @objc(insertObject:inPicturesAtIndex:)
    func insertObject(_ value: Any, inPicturesAt index: Int) {
        do {
            let payload = try SwiftTagAppleScriptPicturePayload.from(value: value)
            let pictureIndex = try SwiftTagAppleScriptController.shared.upsertPicture(
                payload,
                forSessionID: sessionIDValue,
                trackID: trackIDValue
            )

            if let picture = value as? SwiftTagScriptPicture {
                picture.attach(sessionID: sessionIDValue, trackID: trackIDValue, pictureIndex: pictureIndex)
            }
        } catch {
            _ = NSScriptCommand.current()?.fail(error)
        }
    }

    @objc(insertInPictures:atIndex:)
    func insertInPictures(_ value: Any, at index: Int) {
        insertObject(value, inPicturesAt: index)
    }

    @objc(insertInPictures:)
    func insertInPictures(_ value: Any) {
        insertObject(value, inPicturesAt: pictures.count)
    }

    @objc(handleMakeScriptCommand:)
    func handleMakeScriptCommand(_ command: NSScriptCommand) -> Any? {
        do {
            guard let createCommand = command as? NSCreateCommand else {
                throw SwiftTagAppleScriptCommandError.invalidPictureObject
            }

            switch createCommand.createClassDescription.className {
            case "picture":
                return try makePicture(using: createCommand)
            case "tag":
                return try makeTag(using: createCommand)
            default:
                throw SwiftTagAppleScriptCommandError.invalidPictureObject
            }
        } catch {
            _ = command.fail(error)
            return nil
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

    @objc(removeObjectFromPicturesAtIndex:)
    func removeObjectFromPictures(at index: Int) {
        do {
            try SwiftTagAppleScriptController.shared.deletePicture(
                forSessionID: sessionIDValue,
                trackID: trackIDValue,
                pictureIndex: index
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

    fileprivate func makePicture(using command: NSCreateCommand) throws -> SwiftTagScriptPicture? {
        let payload = try SwiftTagAppleScriptPicturePayload.from(
            properties: creationProperties(from: command),
            contentsValue: command.arguments?["ObjectData"] ?? command.evaluatedArguments?["ObjectData"]
        )
        let pictureIndex = try SwiftTagAppleScriptController.shared.upsertPicture(
            payload,
            forSessionID: sessionIDValue,
            trackID: trackIDValue
        )
        return SwiftTagScriptPicture(sessionID: sessionIDValue, trackID: trackIDValue, pictureIndex: pictureIndex)
    }

    fileprivate func makeTag(using command: NSCreateCommand) throws -> SwiftTagScriptTag? {
        let payload = try SwiftTagAppleScriptTagPayload.from(value: creationProperties(from: command))
        try SwiftTagAppleScriptController.shared.upsertTag(
            key: payload.key,
            value: payload.value,
            forSessionID: sessionIDValue,
            trackID: trackIDValue
        )
        return SwiftTagAppleScriptController.shared.tag(
            forSessionID: sessionIDValue,
            trackID: trackIDValue,
            uniqueID: payload.key
        )
    }

    private func creationProperties(from command: NSCreateCommand) -> NSDictionary {
        if let rawDictionary = command.arguments?["KeyDictionary"] as? NSDictionary {
            return rawDictionary
        }

        if let rawDictionary = command.evaluatedArguments?["KeyDictionary"] as? NSDictionary {
            return rawDictionary
        }

        if let descriptor = command.arguments?["KeyDictionary"] as? NSAppleEventDescriptor,
           descriptor.isRecordDescriptor {
            return creationProperties(from: descriptor)
        }

        if let descriptor = command.evaluatedArguments?["KeyDictionary"] as? NSAppleEventDescriptor,
           descriptor.isRecordDescriptor {
            return creationProperties(from: descriptor)
        }

        return command.resolvedKeyDictionary as NSDictionary
    }

    private func creationProperties(from descriptor: NSAppleEventDescriptor) -> NSDictionary {
        var dictionary: [AnyHashable: Any] = [:]
        for index in 1...descriptor.numberOfItems {
            let keyword = descriptor.keywordForDescriptor(at: index)
            guard keyword != 0,
                  let value = descriptor.atIndex(index) else {
                continue
            }
            dictionary[NSNumber(value: keyword)] = value
        }
        return dictionary as NSDictionary
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

    static func tagKey(forScriptPropertyKey key: String) -> String? {
        scriptPropertyTagKeys[key]
    }

    func deleteTagValue(forScriptPropertyKey key: String) throws {
        guard let tagKey = Self.tagKey(forScriptPropertyKey: key) else {
            throw SwiftTagAppleScriptCommandError.invalidTagKey
        }

        try SwiftTagAppleScriptController.shared.deleteTag(
            key: tagKey,
            forSessionID: sessionIDValue,
            trackID: trackIDValue
        )
    }

    func delete() throws {
        try Self.delete([self])
    }

    static func delete(_ tracks: [SwiftTagScriptTrack]) throws {
        let tracksBySessionID = Dictionary(grouping: tracks, by: \.sessionID)
        for (sessionID, tracks) in tracksBySessionID {
            let trackIDs = Set(tracks.map(\.trackID))
            try SwiftTagAppleScriptController.shared.deleteTracks(trackIDs, forSessionID: sessionID)
        }
    }

    @objc(handleDeleteScriptCommand:)
    func handleDeleteScriptCommand(_ command: NSScriptCommand) -> Any? {
        do {
            try delete()
            return nil
        } catch {
            return command.fail(error)
        }
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

        if let fallback {
            return trackSnapshot[keyPath: fallback].appleScriptNonEmptyValue
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

    @objc(title)
    var title: String {
        resolvedTitle
    }

    @objc(uniqueID)
    var uniqueID: Int {
        liveWindow?.windowNumber ?? 0
    }

    @objc(orderedIndex)
    var orderedIndex: Int {
        liveWindow?.orderedIndex
            ?? SwiftTagAppleScriptController.shared.indexOfEditorWindow(sessionID: sessionIDValue)
            ?? 0
    }

    @objc(bounds)
    var bounds: NSDictionary {
        scriptRectangle(from: currentWindowFrame)
    }

    @objc(hasCloseBox)
    var hasCloseBox: Bool {
        liveWindowBoolean(forKey: "hasCloseBox")
    }

    @objc(isCollapseable)
    var isCollapseable: Bool {
        liveWindowBoolean(forKey: "isMiniaturizable")
    }

    @objc(isCollapsed)
    var isCollapsed: Bool {
        liveWindow?.isMiniaturized ?? false
    }

    @objc(isFullScreen)
    var isFullScreen: Bool {
        liveWindow?.styleMask.contains(.fullScreen) ?? false
    }

    @objc(position)
    var position: NSDictionary {
        scriptPoint(from: currentWindowFrame)
    }

    @objc(isResizable)
    var isResizable: Bool {
        liveWindowBoolean(forKey: "isResizable")
    }

    @objc(isVisible)
    var isVisible: Bool {
        liveWindow?.isVisible ?? false
    }

    @objc(isZoomable)
    var isZoomable: Bool {
        liveWindowBoolean(forKey: "isZoomable")
    }

    @objc(isZoomed)
    var isZoomed: Bool {
        liveWindow?.isZoomed ?? false
    }

    @objc(name)
    var name: String {
        resolvedTitle
    }

    private var resolvedTitle: String {
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

    @objc(modified)
    var modified: Bool {
        SwiftTagAppleScriptController.shared.editorWindowIsModified(forSessionID: sessionIDValue)
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

    @objc(TrackSortOrder)
    var trackSortOrder: Any {
        get {
            NSNumber(
                value: SwiftTagAppleScriptController.shared
                    .trackSortOrder(forSessionID: sessionIDValue)
                    .appleScriptCode
            )
        }
        set {
            do {
                guard let sortMode = try SwiftTagAppleScriptTrackSortOption.sortMode(
                    from: newValue,
                    optionName: "track sort order"
                ) else {
                    return
                }
                try sortTracks(by: sortMode)
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
        switch key {
        case "bounds":
            setBounds(from: value)
            return
        case "position":
            setPosition(from: value)
            return
        case "orderedIndex":
            if let index = scriptInteger(from: value) {
                liveWindow?.orderedIndex = index
            }
            return
        case "isCollapsed":
            if let collapsed = scriptBoolean(from: value) {
                setCollapsed(collapsed)
            }
            return
        case "isFullScreen":
            if let fullScreen = scriptBoolean(from: value) {
                setFullScreen(fullScreen)
            }
            return
        case "isVisible":
            if let visible = scriptBoolean(from: value) {
                setVisible(visible)
            }
            return
        case "isZoomed":
            if let zoomed = scriptBoolean(from: value) {
                setZoomed(zoomed)
            }
            return
        case "selectedTracks":
            break
        default:
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

    @objc(removeObjectFromTracksAtIndex:)
    func removeObjectFromTracks(at index: Int) {
        removeTrack(at: index)
    }

    @objc(removeFromTracksAtIndex:)
    func removeFromTracks(at index: Int) {
        removeTrack(at: index)
    }

    private func removeTrack(at index: Int) {
        do {
            try tracks[index].delete()
        } catch {
            _ = NSScriptCommand.current()?.fail(error)
        }
    }

    override func removeValue(at index: Int, fromPropertyWithKey key: String) {
        guard key == "tracks" else {
            super.removeValue(at: index, fromPropertyWithKey: key)
            return
        }

        removeTrack(at: index)
    }

    @objc(removeTracksAtIndexes:)
    func removeTracks(at indexes: NSIndexSet) {
        do {
            let indexedTracks = tracks.enumerated()
                .filter { indexes.contains($0.offset) }
                .map(\.element)
            try SwiftTagScriptTrack.delete(indexedTracks)
        } catch {
            _ = NSScriptCommand.current()?.fail(error)
        }
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
            if modified {
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

    func addTracks(at urls: [URL], locked: Bool = false) throws -> [SwiftTagScriptTrack] {
        try SwiftTagAppleScriptController.shared.addTracks(
            urls,
            locked: locked,
            toSessionID: sessionIDValue
        )
    }

    @discardableResult
    func sortTracks(by sortMode: TrackTableSortMode) throws -> SwiftTagScriptEditorWindow {
        try SwiftTagAppleScriptController.shared.sortTracks(
            forSessionID: sessionIDValue,
            by: sortMode
        )
        return self
    }

    @objc(handleAddTracksScriptCommand:)
    func handleAddTracksScriptCommand(_ command: NSScriptCommand) -> Any? {
        do {
            let urls = try SwiftTagAppleScriptFileURLResolver.fileURLs(
                from: command.directParameter,
                missingValueError: .missingAddTracksInput
            )
            let request = try SwiftTagAppleScriptAddTracksRequest.from(arguments: command.evaluatedArguments)
            let tracks = try addTracks(at: urls, locked: request.locked)
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

    private var currentWindowFrame: NSRect {
        liveWindow?.frame ?? .zero
    }

    private func setBounds(from rawValue: Any?) {
        guard let window = liveWindow else {
            return
        }

        if let rectangle = scriptRectangle(from: rawValue) {
            window.setFrame(
                NSRect(
                    x: rectangle.x,
                    y: rectangle.y - rectangle.height,
                    width: max(1, rectangle.width),
                    height: max(1, rectangle.height)
                ),
                display: true
            )
            return
        }

        if let values = scriptNumbers(from: rawValue, expectedCount: 4) {
            let left = values[0]
            let top = values[1]
            let right = values[2]
            let bottom = values[3]
            let width = max(1, right - left)
            let height = max(1, top - bottom)
            window.setFrame(
                NSRect(x: left, y: bottom, width: width, height: height),
                display: true
            )
        }
    }

    private func setPosition(from rawValue: Any?) {
        guard let window = liveWindow else {
            return
        }

        if let point = scriptPoint(from: rawValue) {
            window.setFrameTopLeftPoint(NSPoint(x: point.x, y: point.y))
            return
        }

        if let values = scriptNumbers(from: rawValue, expectedCount: 2) {
            window.setFrameTopLeftPoint(NSPoint(x: values[0], y: values[1]))
        }
    }

    private func setCollapsed(_ collapsed: Bool) {
        guard let window = liveWindow,
              window.isMiniaturized != collapsed else {
            return
        }

        if collapsed {
            window.miniaturize(nil)
        } else {
            window.deminiaturize(nil)
        }
    }

    private func setFullScreen(_ fullScreen: Bool) {
        guard let window = liveWindow,
              window.styleMask.contains(.fullScreen) != fullScreen else {
            return
        }

        window.toggleFullScreen(nil)
    }

    private func setVisible(_ visible: Bool) {
        guard let window = liveWindow,
              window.isVisible != visible else {
            return
        }

        if visible {
            window.orderFront(nil)
        } else {
            window.orderOut(nil)
        }
    }

    private func setZoomed(_ zoomed: Bool) {
        guard let window = liveWindow,
              window.isZoomed != zoomed,
              isZoomable else {
            return
        }

        window.zoom(nil)
    }

    private func liveWindowBoolean(forKey key: String) -> Bool {
        guard let value = liveWindow?.value(forKey: key) else {
            return false
        }

        return scriptBoolean(from: value) ?? false
    }

    private func scriptNumbers(from rawValue: Any?, expectedCount: Int) -> [CGFloat]? {
        let values: [CGFloat]
        switch rawValue {
        case let numbers as [NSNumber]:
            values = numbers.map { CGFloat(truncating: $0) }
        case let array as NSArray:
            values = array.compactMap { value in
                switch value {
                case let number as NSNumber:
                    return CGFloat(truncating: number)
                case let string as NSString:
                    return Double(string as String).map { CGFloat($0) }
                case let string as String:
                    return Double(string).map { CGFloat($0) }
                default:
                    return nil
                }
            }
        case let descriptor as NSAppleEventDescriptor where descriptor.numberOfItems >= expectedCount:
            values = (1...descriptor.numberOfItems).compactMap { index in
                descriptor.atIndex(index).map { CGFloat($0.doubleValue) }
            }
        default:
            return nil
        }

        guard values.count >= expectedCount else {
            return nil
        }

        return Array(values.prefix(expectedCount))
    }

    private func scriptBoolean(from rawValue: Any?) -> Bool? {
        switch rawValue {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as NSString:
            return Bool(value as String)
        case let value as String:
            return Bool(value)
        case let descriptor as NSAppleEventDescriptor:
            return descriptor.booleanValue
        default:
            return nil
        }
    }

    private func scriptInteger(from rawValue: Any?) -> Int? {
        switch rawValue {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as NSString:
            return Int(value as String)
        case let value as String:
            return Int(value)
        case let descriptor as NSAppleEventDescriptor:
            return Int(descriptor.int32Value)
        default:
            return nil
        }
    }

    private struct ScriptPoint {
        let x: CGFloat
        let y: CGFloat
    }

    private struct ScriptRectangle {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    private func scriptPoint(from frame: NSRect) -> NSDictionary {
        [
            "x": NSNumber(value: Int(frame.minX.rounded())),
            "y": NSNumber(value: Int(frame.maxY.rounded()))
        ] as NSDictionary
    }

    private func scriptRectangle(from frame: NSRect) -> NSDictionary {
        [
            "x": NSNumber(value: Int(frame.minX.rounded())),
            "y": NSNumber(value: Int(frame.maxY.rounded())),
            "width": NSNumber(value: Int(frame.width.rounded())),
            "height": NSNumber(value: Int(frame.height.rounded()))
        ] as NSDictionary
    }

    private func scriptPoint(from rawValue: Any?) -> ScriptPoint? {
        guard let dictionary = scriptRecordDictionary(from: rawValue),
              let x = scriptNumber(in: dictionary, matching: ["x", "xpos"]),
              let y = scriptNumber(in: dictionary, matching: ["y", "ypos"]) else {
            return nil
        }

        return ScriptPoint(x: x, y: y)
    }

    private func scriptRectangle(from rawValue: Any?) -> ScriptRectangle? {
        guard let dictionary = scriptRecordDictionary(from: rawValue),
              let x = scriptNumber(in: dictionary, matching: ["x", "xpos"]),
              let y = scriptNumber(in: dictionary, matching: ["y", "ypos"]),
              let width = scriptNumber(in: dictionary, matching: ["width", "widt"]),
              let height = scriptNumber(in: dictionary, matching: ["height", "heig"]) else {
            return nil
        }

        return ScriptRectangle(x: x, y: y, width: width, height: height)
    }

    private func scriptRecordDictionary(from rawValue: Any?) -> [AnyHashable: Any]? {
        switch rawValue {
        case let dictionary as [AnyHashable: Any]:
            return dictionary
        case let dictionary as NSDictionary:
            var bridgedDictionary: [AnyHashable: Any] = [:]
            for case let (key as AnyHashable, value) in dictionary {
                bridgedDictionary[key] = value
            }
            return bridgedDictionary
        case let descriptor as NSAppleEventDescriptor where descriptor.isRecordDescriptor:
            return scriptRecordDictionary(from: descriptor)
        default:
            return nil
        }
    }

    private func scriptRecordDictionary(from descriptor: NSAppleEventDescriptor) -> [AnyHashable: Any] {
        guard descriptor.numberOfItems > 0 else {
            return [:]
        }

        var dictionary: [AnyHashable: Any] = [:]
        for index in 1...descriptor.numberOfItems {
            let keyword = descriptor.keywordForDescriptor(at: index)
            guard keyword != 0,
                  let value = descriptor.atIndex(index) else {
                continue
            }
            dictionary[NSNumber(value: keyword)] = value
        }
        return dictionary
    }

    private func scriptNumber(in dictionary: [AnyHashable: Any], matching names: Set<String>) -> CGFloat? {
        dictionary
            .first { names.contains(normalizedScriptRecordKey($0.key)) }
            .flatMap { scriptNumber(from: $0.value) }
    }

    private func scriptNumber(from rawValue: Any?) -> CGFloat? {
        switch rawValue {
        case let value as CGFloat:
            return value
        case let value as Double:
            return CGFloat(value)
        case let value as NSNumber:
            return CGFloat(truncating: value)
        case let value as NSString:
            return Double(value as String).map { CGFloat($0) }
        case let value as String:
            return Double(value).map { CGFloat($0) }
        case let descriptor as NSAppleEventDescriptor:
            if let stringValue = descriptor.stringValue,
               let value = Double(stringValue) {
                return CGFloat(value)
            }
            if let coerced = descriptor.coerce(toDescriptorType: typeIEEE64BitFloatingPoint) {
                return CGFloat(coerced.doubleValue)
            }
            if descriptor.descriptorType == typeSInt32 {
                return CGFloat(descriptor.int32Value)
            }
            return nil
        default:
            return nil
        }
    }

    private func normalizedScriptRecordKey(_ rawKey: AnyHashable) -> String {
        if let string = rawKey as? String {
            return normalizeScriptRecordString(string)
        }

        if let string = rawKey as? NSString {
            return normalizeScriptRecordString(string as String)
        }

        if let number = rawKey as? NSNumber,
           let codeString = fourCharString(from: number.uint32Value) {
            return normalizeScriptRecordString(codeString)
        }

        return normalizeScriptRecordString(String(describing: rawKey))
    }

    private func normalizeScriptRecordString(_ string: String) -> String {
        string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func fourCharString(from code: UInt32) -> String? {
        let bytes = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        guard bytes.allSatisfy({ $0 == 32 || (33...126).contains($0) }) else {
            return nil
        }

        return String(bytes: bytes, encoding: .ascii)
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
final class SettingsWindowCoordinator {
    static let shared = SettingsWindowCoordinator()

    private weak var registeredWindow: NSWindow?
    private var openSettingsWindowAction: (() -> Void)?
    private let settingsWindowIdentifier = NSUserInterfaceItemIdentifier("SwiftTag.settingsWindow")

    private init() {}

    func setOpenSettingsWindowAction(_ action: @escaping () -> Void) {
        openSettingsWindowAction = action
    }

    func registerSettingsWindow(_ window: NSWindow?) {
        registeredWindow = window
        window?.identifier = settingsWindowIdentifier
    }

    var currentSettingsWindow: NSWindow? {
        if let registeredWindow {
            return registeredWindow
        }

        return NSApp.orderedWindows.first { window in
            window.identifier == settingsWindowIdentifier
        }
    }

    @discardableResult
    func openSettingsWindow() -> NSWindow? {
        if let window = currentSettingsWindow {
            orderSettingsWindowInFront(window)
            return window
        }

        presentSettingsWindow()
        return currentSettingsWindow
    }

    @discardableResult
    func closeSettingsWindow() -> NSWindow? {
        guard let window = currentSettingsWindow else {
            return nil
        }

        window.performClose(nil)
        return window
    }

    private func presentSettingsWindow() {
        if let window = currentSettingsWindow {
            orderSettingsWindowInFront(window)
            return
        }

        if let openSettingsWindowAction {
            openSettingsWindowAction()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        currentSettingsWindow.map(orderSettingsWindowInFront)
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.currentSettingsWindow else {
                return
            }

            self.orderSettingsWindowInFront(window)
        }
    }

    private func orderSettingsWindowInFront(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
    }

    #if DEBUG
    func resetForTesting() {
        registeredWindow = nil
        openSettingsWindowAction = nil
    }
    #endif
}

@MainActor
@objc(SwiftTagScriptSettingsWindow)
final class SwiftTagScriptSettingsWindow: NSObject {
    @objc
    override init() {
        super.init()
    }

    @objc(title)
    var title: String {
        resolvedTitle
    }

    @objc(name)
    var name: String {
        resolvedTitle
    }

    @objc(uniqueID)
    var uniqueID: Int {
        liveWindow?.windowNumber ?? 0
    }

    @objc(orderedIndex)
    var orderedIndex: Int {
        liveWindow?.orderedIndex ?? 0
    }

    @objc(bounds)
    var bounds: NSDictionary {
        scriptRectangle(from: liveWindow?.frame ?? .zero)
    }

    @objc(hasCloseBox)
    var hasCloseBox: Bool {
        liveWindowBoolean(forKey: "hasCloseBox")
    }

    @objc(isCollapseable)
    var isCollapseable: Bool {
        false
    }

    @objc(isCollapsed)
    var isCollapsed: Bool {
        false
    }

    @objc(isFullScreen)
    var isFullScreen: Bool {
        false
    }

    @objc(position)
    var position: NSDictionary {
        scriptPoint(from: liveWindow?.frame ?? .zero)
    }

    @objc(isResizable)
    var isResizable: Bool {
        false
    }

    @objc(isVisible)
    var isVisible: Bool {
        liveWindow?.isVisible ?? false
    }

    @objc(isZoomable)
    var isZoomable: Bool {
        false
    }

    @objc(isZoomed)
    var isZoomed: Bool {
        false
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let classDescription = NSScriptClassDescription(for: NSApplication.self) else {
            return nil
        }

        return NSIndexSpecifier(
            containerClassDescription: classDescription,
            containerSpecifier: nil,
            key: "scriptSettingsWindows",
            index: 0
        )
    }

    @discardableResult
    func openSettingsWindow() -> SwiftTagScriptSettingsWindow {
        SettingsWindowCoordinator.shared.openSettingsWindow()
        return self
    }

    func closeSettingsWindow() {
        SettingsWindowCoordinator.shared.closeSettingsWindow()
    }

    @objc(handleCloseScriptCommand:)
    func handleCloseScriptCommand(_ command: NSScriptCommand) -> Any? {
        closeSettingsWindow()
        return nil
    }

    override func setValue(_ value: Any?, forKey key: String) {
        switch key {
        case "bounds":
            setBounds(from: value)
        case "position":
            setPosition(from: value)
        case "orderedIndex":
            if let index = scriptInteger(from: value) {
                liveWindow?.orderedIndex = index
            }
        case "isCollapsed":
            if let collapsed = scriptBoolean(from: value) {
                setCollapsed(collapsed)
            }
        case "isFullScreen":
            if let fullScreen = scriptBoolean(from: value) {
                setFullScreen(fullScreen)
            }
        case "isVisible":
            if let visible = scriptBoolean(from: value) {
                setVisible(visible)
            }
        case "isZoomed":
            if let zoomed = scriptBoolean(from: value) {
                setZoomed(zoomed)
            }
        default:
            super.setValue(value, forKey: key)
        }
    }

    private var liveWindow: NSWindow? {
        SettingsWindowCoordinator.shared.currentSettingsWindow
    }

    private var resolvedTitle: String {
        let windowTitle = liveWindow?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return windowTitle.isEmpty ? "Settings" : windowTitle
    }

    private func setBounds(from rawValue: Any?) {
        // Settings window does not support resize.
    }

    private func setPosition(from rawValue: Any?) {
        guard let window = liveWindow else {
            return
        }

        if let point = scriptPoint(from: rawValue) {
            window.setFrameTopLeftPoint(NSPoint(x: point.x, y: point.y))
            return
        }

        if let values = scriptNumbers(from: rawValue, expectedCount: 2) {
            window.setFrameTopLeftPoint(NSPoint(x: values[0], y: values[1]))
        }
    }

    private func setCollapsed(_ collapsed: Bool) {
        // Settings window does not support collaspse.
    }

    private func setFullScreen(_ fullScreen: Bool) {
        // Settings window does not support full screen.
    }

    private func setVisible(_ visible: Bool) {
        guard let window = liveWindow,
              window.isVisible != visible else {
            return
        }

        if visible {
            window.orderFront(nil)
        } else {
            window.orderOut(nil)
        }
    }

    private func setZoomed(_ zoomed: Bool) {
        // Settings window does not support full zoom.
    }

    private func liveWindowBoolean(forKey key: String) -> Bool {
        guard let value = liveWindow?.value(forKey: key) else {
            return false
        }

        return scriptBoolean(from: value) ?? false
    }

    private struct ScriptPoint {
        let x: CGFloat
        let y: CGFloat
    }

    private struct ScriptRectangle {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    private func scriptPoint(from frame: NSRect) -> NSDictionary {
        [
            "x": NSNumber(value: Int(frame.minX.rounded())),
            "y": NSNumber(value: Int(frame.maxY.rounded()))
        ] as NSDictionary
    }

    private func scriptRectangle(from frame: NSRect) -> NSDictionary {
        [
            "x": NSNumber(value: Int(frame.minX.rounded())),
            "y": NSNumber(value: Int(frame.maxY.rounded())),
            "width": NSNumber(value: Int(frame.width.rounded())),
            "height": NSNumber(value: Int(frame.height.rounded()))
        ] as NSDictionary
    }

    private func scriptPoint(from rawValue: Any?) -> ScriptPoint? {
        guard let dictionary = scriptRecordDictionary(from: rawValue),
              let x = scriptNumber(in: dictionary, matching: ["x", "xpos"]),
              let y = scriptNumber(in: dictionary, matching: ["y", "ypos"]) else {
            return nil
        }

        return ScriptPoint(x: x, y: y)
    }

    private func scriptRectangle(from rawValue: Any?) -> ScriptRectangle? {
        guard let dictionary = scriptRecordDictionary(from: rawValue),
              let x = scriptNumber(in: dictionary, matching: ["x", "xpos"]),
              let y = scriptNumber(in: dictionary, matching: ["y", "ypos"]),
              let width = scriptNumber(in: dictionary, matching: ["width", "widt"]),
              let height = scriptNumber(in: dictionary, matching: ["height", "heig"]) else {
            return nil
        }

        return ScriptRectangle(x: x, y: y, width: width, height: height)
    }

    private func scriptNumbers(from rawValue: Any?, expectedCount: Int) -> [CGFloat]? {
        let values: [CGFloat]
        switch rawValue {
        case let numbers as [NSNumber]:
            values = numbers.map { CGFloat(truncating: $0) }
        case let array as NSArray:
            values = array.compactMap { value in
                switch value {
                case let number as NSNumber:
                    return CGFloat(truncating: number)
                case let string as NSString:
                    return Double(string as String).map { CGFloat($0) }
                case let string as String:
                    return Double(string).map { CGFloat($0) }
                default:
                    return nil
                }
            }
        case let descriptor as NSAppleEventDescriptor where descriptor.numberOfItems >= expectedCount:
            values = (1...descriptor.numberOfItems).compactMap { index in
                descriptor.atIndex(index).map { CGFloat($0.doubleValue) }
            }
        default:
            return nil
        }

        guard values.count >= expectedCount else {
            return nil
        }

        return Array(values.prefix(expectedCount))
    }

    private func scriptBoolean(from rawValue: Any?) -> Bool? {
        switch rawValue {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as NSString:
            return Bool(value as String)
        case let value as String:
            return Bool(value)
        case let descriptor as NSAppleEventDescriptor:
            return descriptor.booleanValue
        default:
            return nil
        }
    }

    private func scriptInteger(from rawValue: Any?) -> Int? {
        switch rawValue {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as NSString:
            return Int(value as String)
        case let value as String:
            return Int(value)
        case let descriptor as NSAppleEventDescriptor:
            return Int(descriptor.int32Value)
        default:
            return nil
        }
    }

    private func scriptRecordDictionary(from rawValue: Any?) -> [String: Any]? {
        switch rawValue {
        case let dictionary as [String: Any]:
            return dictionary
        case let dictionary as NSDictionary:
            var result: [String: Any] = [:]
            for (key, value) in dictionary {
                result[String(describing: key)] = value
            }
            return result
        case let descriptor as NSAppleEventDescriptor:
            var result: [String: Any] = [:]
            for (name, code) in [
                ("x", "xpos"), ("y", "ypos"), ("width", "widt"), ("height", "heig")
            ] {
                if let value = descriptor.forKeyword(fourCharCode(code)) {
                    result[name] = NSNumber(value: value.doubleValue)
                }
            }
            return result
        default:
            return nil
        }
    }

    private func scriptNumber(in dictionary: [String: Any], matching keys: [String]) -> CGFloat? {
        for key in keys {
            guard let value = dictionary[key] else {
                continue
            }

            switch value {
            case let number as NSNumber:
                return CGFloat(truncating: number)
            case let string as NSString:
                return Double(string as String).map { CGFloat($0) }
            case let string as String:
                return Double(string).map { CGFloat($0) }
            default:
                continue
            }
        }

        return nil
    }

    private static func fourCharCode(_ value: String) -> AEKeyword {
        let bytes = Array(value.utf8.prefix(4))
        let paddedBytes = bytes + Array(repeating: UInt8(32), count: max(0, 4 - bytes.count))
        return paddedBytes.prefix(4).reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
    }

    private func fourCharCode(_ value: String) -> AEKeyword {
        Self.fourCharCode(value)
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
    private let settingsWindow = SwiftTagScriptSettingsWindow()
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

    func settingsWindows() -> [SwiftTagScriptSettingsWindow] {
        [settingsWindow]
    }

    func openSettingsWindow() -> SwiftTagScriptSettingsWindow {
        settingsWindow.openSettingsWindow()
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
            for: EditorSessionValue(sessionID: scriptWindow.sessionID),
            activateApp: false
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
        if let sessionID = normalizedSessionID(from: uniqueID) {
            _ = orderedEditorWindows()
            return editorWindowsBySessionID[sessionID]
        }

        guard let windowUniqueID = normalizedWindowUniqueID(from: uniqueID) else {
            return nil
        }

        return orderedEditorWindows().first { $0.uniqueID == windowUniqueID }
    }

    func settingsWindow(withUniqueID uniqueID: Any) -> SwiftTagScriptSettingsWindow? {
        guard let windowUniqueID = normalizedWindowUniqueID(from: uniqueID),
              windowUniqueID == settingsWindow.uniqueID else {
            return nil
        }

        return settingsWindow
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

        let orderedTracks = snapshot.tracks.sortedForTrackTableDisplay(sortMode: snapshot.sortMode)
        let validTrackIDs = Set(snapshot.tracks.map(\.id))
        pruneTrackWrappers(forSessionID: sessionID, validTrackIDs: validTrackIDs)
        return orderedTracks.compactMap { track(forSessionID: sessionID, trackID: $0.id) }
    }

    func selectedTrackObjects(forSessionID sessionID: UUID) -> [SwiftTagScriptTrack] {
        guard let snapshot = sessionSnapshot(forSessionID: sessionID) else {
            return []
        }

        let orderedTracks = snapshot.tracks.sortedForTrackTableDisplay(sortMode: snapshot.sortMode)
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

    func setTrackLocked(
        _ locked: Bool,
        forSessionID sessionID: UUID,
        trackID: UUID
    ) throws {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        guard sessionSnapshot(forSessionID: sessionID)?.tracks.contains(where: { $0.id == trackID }) == true else {
            throw SwiftTagAppleScriptCommandError.invalidTrackTarget
        }

        try bridge.setTrackLocked(trackID, locked)
    }

    func addTracks(
        _ urls: [URL],
        locked: Bool = false,
        toSessionID sessionID: UUID
    ) throws -> [SwiftTagScriptTrack] {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        let trackIDs = try bridge.addTracks(urls, locked)
        return trackIDs.compactMap { track(forSessionID: sessionID, trackID: $0) }
    }

    func deleteTracks(
        _ trackIDs: Set<UUID>,
        forSessionID sessionID: UUID
    ) throws {
        guard !trackIDs.isEmpty else {
            return
        }
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        let availableTrackIDs = Set(sessionSnapshot(forSessionID: sessionID)?.tracks.map(\.id) ?? [])
        guard trackIDs.isSubset(of: availableTrackIDs) else {
            throw SwiftTagAppleScriptCommandError.invalidTrackTarget
        }

        try bridge.deleteTracks(trackIDs)
        let validTrackIDs = Set(sessionSnapshot(forSessionID: sessionID)?.tracks.map(\.id) ?? [])
        pruneTrackWrappers(forSessionID: sessionID, validTrackIDs: validTrackIDs)
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

    func pictures(forSessionID sessionID: UUID, trackID: UUID) -> [SwiftTagScriptPicture] {
        guard let track = trackSnapshot(forSessionID: sessionID, trackID: trackID) else {
            return []
        }

        return track.flacPictureRecords.indices.map { index in
            SwiftTagScriptPicture(
                sessionID: sessionID,
                trackID: trackID,
                pictureIndex: index
            )
        }
    }

    func pictureSnapshot(
        forSessionID sessionID: UUID,
        trackID: UUID,
        pictureIndex: Int
    ) -> FlacWritablePictureRecord? {
        trackSnapshot(forSessionID: sessionID, trackID: trackID)?
            .flacPictureRecords[safe: pictureIndex]
    }

    func pictureIdentity(
        forSessionID sessionID: UUID,
        trackID: UUID,
        pictureIndex: Int
    ) -> SwiftTagAppleScriptPictureIdentity? {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            return nil
        }

        return bridge.pictureIdentity(trackID, pictureIndex)
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

    func picture(
        forSessionID sessionID: UUID,
        trackID: UUID,
        uniqueID: Any
    ) -> SwiftTagScriptPicture? {
        guard let id = normalizedPictureUniqueID(uniqueID),
              let pictureIndex = pictureIndex(
                forSessionID: sessionID,
                trackID: trackID,
                uniqueID: id
              ) else {
            return nil
        }

        return SwiftTagScriptPicture(
            sessionID: sessionID,
            trackID: trackID,
            pictureIndex: pictureIndex
        )
    }

    func pictureIndex(
        forSessionID sessionID: UUID,
        trackID: UUID,
        uniqueID: UUID
    ) -> Int? {
        guard let track = trackSnapshot(forSessionID: sessionID, trackID: trackID) else {
            return nil
        }

        return track.flacPictureRecords.indices.first { pictureIndex in
            pictureIdentity(forSessionID: sessionID, trackID: trackID, pictureIndex: pictureIndex)?.id == uniqueID
        }
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

    func upsertPicture(
        _ payload: SwiftTagAppleScriptPicturePayload,
        forSessionID sessionID: UUID,
        trackID: UUID
    ) throws -> Int {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        return try bridge.upsertPicture(trackID, payload)
    }

    func replacePicture(
        _ payload: SwiftTagAppleScriptPicturePayload,
        forSessionID sessionID: UUID,
        trackID: UUID,
        pictureIndex: Int
    ) throws -> Int {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        return try bridge.replacePicture(trackID, pictureIndex, payload)
    }

    func updatePictureDescription(
        _ description: String,
        forSessionID sessionID: UUID,
        trackID: UUID,
        pictureIndex: Int
    ) throws {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        try bridge.updatePictureDescription(trackID, pictureIndex, description)
    }

    func deletePicture(
        forSessionID sessionID: UUID,
        trackID: UUID,
        pictureIndex: Int
    ) throws {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        try bridge.deletePicture(trackID, pictureIndex)
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

    func editorWindowIsModified(forSessionID sessionID: UUID) -> Bool {
        sessionBridgesBySessionID[sessionID]?.editorWindowModified() ?? false
    }

    func trackIsModified(forSessionID sessionID: UUID, trackID: UUID) -> Bool {
        guard sessionSnapshot(forSessionID: sessionID)?.tracks.contains(where: { $0.id == trackID }) == true else {
            return false
        }

        return sessionBridgesBySessionID[sessionID]?.trackModified(trackID) ?? false
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

    func trackSortOrder(forSessionID sessionID: UUID) -> TrackTableSortMode {
        sessionSnapshot(forSessionID: sessionID)?.sortMode ?? .number
    }

    func sortTracks(
        forSessionID sessionID: UUID,
        by sortMode: TrackTableSortMode
    ) throws {
        guard let bridge = sessionBridgesBySessionID[sessionID] else {
            throw SwiftTagAppleScriptCommandError.sessionUnavailable
        }

        try bridge.sortTracks(sortMode)
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
        guard let snapshot = sessionSnapshot(forSessionID: sessionID) else {
            return nil
        }

        return snapshot.tracks
            .sortedForTrackTableDisplay(sortMode: snapshot.sortMode)
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

    private func normalizedWindowUniqueID(from uniqueID: Any) -> Int? {
        if let number = uniqueID as? NSNumber {
            return number.intValue
        }

        if let integer = uniqueID as? Int {
            return integer
        }

        if let string = uniqueID as? String {
            return Int(string)
        }

        if let string = uniqueID as? NSString {
            return Int(string as String)
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

    private func normalizedPictureUniqueID(_ uniqueID: Any) -> UUID? {
        normalizedSessionID(from: uniqueID)
    }
}

@MainActor
extension NSApplication {
    @objc(scriptEditorWindows)
    var scriptEditorWindows: [SwiftTagScriptEditorWindow] {
        SwiftTagAppleScriptController.shared.orderedEditorWindows()
    }

    @objc(scriptSettingsWindows)
    var scriptSettingsWindows: [SwiftTagScriptSettingsWindow] {
        SwiftTagAppleScriptController.shared.settingsWindows()
    }

    @objc(scriptDocuments)
    var scriptDocuments: [SwiftTagScriptDocument] {
        SwiftTagAppleScriptController.shared.orderedDocuments()
    }

    @objc(scriptTracks)
    var scriptTracks: [SwiftTagScriptTrack] {
        SwiftTagAppleScriptController.shared.orderedTracks()
    }

    @objc(SaveScopeOptionsSetting)
    var saveScopeOptionsSetting: Any {
        get {
            NSNumber(value: saveScopeOptionSetting.appleScriptCode)
        }
        set {
            guard let option = try? SaveScopeOption.appleScriptValue(
                from: newValue,
                optionName: "track save scope"
            ) else {
                return
            }
            UserDefaults.standard.set(option.rawValue, forKey: SaveSettingsKey.defaultSaveScope)
        }
    }

    @objc(SavePayloadOptionsSetting)
    var savePayloadOptionsSetting: Any {
        get {
            NSNumber(value: savePayloadOptionSetting.appleScriptCode)
        }
        set {
            guard let option = try? SavePayloadOption.appleScriptValue(
                from: newValue,
                optionName: "track save payload"
            ) else {
                return
            }
            UserDefaults.standard.set(option.rawValue, forKey: SaveSettingsKey.defaultSavePayload)
        }
    }

    @objc(SaveReferencedDocumentSetting)
    var saveReferencedDocumentSetting: Bool {
        get {
            boolSetting(
                key: SaveSettingsKey.saveReferencedSwiftTagDocument,
                defaultValue: SaveSettingsDefaults.saveReferencedSwiftTagDocument
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SaveSettingsKey.saveReferencedSwiftTagDocument)
        }
    }

    @objc(AskToSaveNewDocumentSetting)
    var askToSaveNewDocumentSetting: Bool {
        get {
            boolSetting(
                key: SaveSettingsKey.askToSaveNewSwiftTagDocument,
                defaultValue: SaveSettingsDefaults.askToSaveNewSwiftTagDocument
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SaveSettingsKey.askToSaveNewSwiftTagDocument)
        }
    }

    @objc(ZeroPadTrackNumbersSetting)
    var zeroPadTrackNumbersSetting: Bool {
        get {
            boolSetting(
                key: SaveSettingsKey.zeroPadTrackNumber,
                defaultValue: SaveSettingsDefaults.zeroPadTrackNumber
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SaveSettingsKey.zeroPadTrackNumber)
        }
    }

    @objc(ZeroPadDiscNumbersSetting)
    var zeroPadDiscNumbersSetting: Bool {
        get {
            boolSetting(
                key: SaveSettingsKey.zeroPadDiscNumber,
                defaultValue: SaveSettingsDefaults.zeroPadDiscNumber
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SaveSettingsKey.zeroPadDiscNumber)
        }
    }

    @objc(TrackTotalKeySetting)
    var trackTotalKeySetting: Any? {
        get {
            trackCountKeyStrategySetting.appleScriptCode.map { NSNumber(value: $0) }
        }
        set {
            guard let strategy = TrackCountKeyStrategy.appleScriptValue(from: newValue) else {
                return
            }
            UserDefaults.standard.set(strategy.rawValue, forKey: SaveSettingsKey.trackCountKeyStrategy)
        }
    }

    @objc(DiscTotalKeySetting)
    var discTotalKeySetting: Any? {
        get {
            discCountKeyStrategySetting.appleScriptCode.map { NSNumber(value: $0) }
        }
        set {
            guard let strategy = DiscCountKeyStrategy.appleScriptValue(from: newValue) else {
                return
            }
            UserDefaults.standard.set(strategy.rawValue, forKey: SaveSettingsKey.discCountKeyStrategy)
        }
    }

    @objc(AutoUpdateTrackTotalSetting)
    var autoUpdateTrackTotalSetting: Bool {
        get {
            boolSetting(
                key: SaveSettingsKey.autoUpdateTrackTotal,
                defaultValue: SaveSettingsDefaults.autoUpdateTrackTotal
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SaveSettingsKey.autoUpdateTrackTotal)
        }
    }

    @objc(AutoUpdateTrackTotalByDiscSetting)
    var autoUpdateTrackTotalByDiscSetting: Bool {
        get {
            boolSetting(
                key: SaveSettingsKey.autoUpdateTrackTotalByDisc,
                defaultValue: SaveSettingsDefaults.autoUpdateTrackTotalByDisc
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SaveSettingsKey.autoUpdateTrackTotalByDisc)
        }
    }

    @objc(ApplyCompilationToAllTracksSetting)
    var applyCompilationToAllTracksSetting: Bool {
        get {
            boolSetting(
                key: SaveSettingsKey.applyCompilationToAllTracks,
                defaultValue: SaveSettingsDefaults.applyCompilationToAllTracks
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SaveSettingsKey.applyCompilationToAllTracks)
        }
    }

    @objc(SaveFrontCoverToAllTracksSetting)
    var saveFrontCoverToAllTracksSetting: Bool {
        get {
            boolSetting(
                key: SaveSettingsKey.saveFrontCoverToAllTracks,
                defaultValue: SaveSettingsDefaults.saveFrontCoverToAllTracks
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SaveSettingsKey.saveFrontCoverToAllTracks)
        }
    }

    @objc(SaveAllPicturesToAllTracksSetting)
    var saveAllPicturesToAllTracksSetting: Bool {
        get {
            boolSetting(
                key: SaveSettingsKey.saveAllPicturesToAllTracks,
                defaultValue: SaveSettingsDefaults.saveAllPicturesToAllTracks
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SaveSettingsKey.saveAllPicturesToAllTracks)
        }
    }

    @objc(SendSaveNotificationsSetting)
    var sendSaveNotificationsSetting: Any {
        get {
            NSNumber(value: saveNotificationModeSetting.appleScriptCode)
        }
        set {
            guard let mode = SaveNotificationMode.appleScriptValue(from: newValue) else {
                return
            }
            UserDefaults.standard.set(mode.rawValue, forKey: FeedbackSettingsKey.saveNotificationMode)
        }
    }

    @objc(ThemeSetting)
    var themeSetting: Any {
        get {
            NSNumber(value: themePreferenceSetting.appleScriptCode)
        }
        set {
            guard let preference = AppThemePreference.appleScriptValue(from: newValue) else {
                return
            }
            UserDefaults.standard.set(preference.rawValue, forKey: FeedbackSettingsKey.themePreference)
        }
    }

    @objc(QuitAppOnLastWindowCloseSetting)
    var quitAppOnLastWindowCloseSetting: Bool {
        get {
            boolSetting(
                key: FeedbackSettingsKey.quitAppOnLastWindowClose,
                defaultValue: FeedbackSettingsDefaults.quitAppOnLastWindowClose
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: FeedbackSettingsKey.quitAppOnLastWindowClose)
        }
    }

    @objc(TrackToTrackDiffColorSetting)
    var trackToTrackDiffColorSetting: Any {
        get {
            scriptColorSetting(
                key: FeedbackSettingsKey.trackToTrackDiffColor,
                defaultRawValue: FeedbackSettingsDefaults.trackToTrackDiffColor,
                fallback: .systemOrange
            )
        }
        set {
            setScriptColorSetting(newValue, key: FeedbackSettingsKey.trackToTrackDiffColor, fallback: .systemOrange)
        }
    }

    @objc(TrackToFileDiffColorSetting)
    var trackToFileDiffColorSetting: Any {
        get {
            scriptColorSetting(
                key: FeedbackSettingsKey.trackToFileDiffColor,
                defaultRawValue: FeedbackSettingsDefaults.trackToFileDiffColor,
                fallback: .labelColor
            )
        }
        set {
            setScriptColorSetting(newValue, key: FeedbackSettingsKey.trackToFileDiffColor, fallback: .labelColor)
        }
    }

    @objc(ExternallyModifiedDiffColorSetting)
    var externallyModifiedDiffColorSetting: Any {
        get {
            scriptColorSetting(
                key: FeedbackSettingsKey.externallyModifiedDiffColor,
                defaultRawValue: FeedbackSettingsDefaults.externallyModifiedDiffColor,
                fallback: .systemRed
            )
        }
        set {
            setScriptColorSetting(newValue, key: FeedbackSettingsKey.externallyModifiedDiffColor, fallback: .systemRed)
        }
    }

    @objc(TrackAndDiscTotalMismatchColorSetting)
    var trackAndDiscTotalMismatchColorSetting: Any {
        get {
            scriptColorSetting(
                key: FeedbackSettingsKey.trackDiscTotalMismatchColor,
                defaultRawValue: FeedbackSettingsDefaults.trackDiscTotalMismatchColor,
                fallback: .systemRed
            )
        }
        set {
            setScriptColorSetting(newValue, key: FeedbackSettingsKey.trackDiscTotalMismatchColor, fallback: .systemRed)
        }
    }

    @objc(PictureStatusOverlayColorSetting)
    var pictureStatusOverlayColorSetting: Any {
        get {
            scriptColorSetting(
                key: FeedbackSettingsKey.pictureStatusOverlayColor,
                defaultRawValue: FeedbackSettingsDefaults.pictureStatusOverlayColor,
                fallback: .systemOrange
            )
        }
        set {
            setScriptColorSetting(newValue, key: FeedbackSettingsKey.pictureStatusOverlayColor, fallback: .systemOrange)
        }
    }

    @objc(FormatOnTrackToFileDiffSetting)
    var formatOnTrackToFileDiffSetting: Bool {
        get {
            boolSetting(
                key: FeedbackSettingsKey.formatOnTrackToFileDiff,
                defaultValue: FeedbackSettingsDefaults.formatOnTrackToFileDiff
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: FeedbackSettingsKey.formatOnTrackToFileDiff)
        }
    }

    @objc(FormatOnTrackToTrackDiffSetting)
    var formatOnTrackToTrackDiffSetting: Bool {
        get {
            boolSetting(
                key: FeedbackSettingsKey.formatOnTrackToTrackDiff,
                defaultValue: FeedbackSettingsDefaults.formatOnTrackToTrackDiff
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: FeedbackSettingsKey.formatOnTrackToTrackDiff)
        }
    }

    @objc(FormatOnExternallyModifiedDiffSetting)
    var formatOnExternallyModifiedDiffSetting: Bool {
        get {
            boolSetting(
                key: FeedbackSettingsKey.formatOnExternallyModifiedDiff,
                defaultValue: FeedbackSettingsDefaults.formatOnExternallyModifiedDiff
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: FeedbackSettingsKey.formatOnExternallyModifiedDiff)
        }
    }

    @objc(FormatOnTrackTotalMismatchSetting)
    var formatOnTrackTotalMismatchSetting: Bool {
        get {
            boolSetting(
                key: FeedbackSettingsKey.formatOnTrackTotalMismatch,
                defaultValue: FeedbackSettingsDefaults.formatOnTrackTotalMismatch
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: FeedbackSettingsKey.formatOnTrackTotalMismatch)
        }
    }

    @objc(FormatOnDiscTotalMismatchSetting)
    var formatOnDiscTotalMismatchSetting: Bool {
        get {
            boolSetting(
                key: FeedbackSettingsKey.formatOnDiscTotalMismatch,
                defaultValue: FeedbackSettingsDefaults.formatOnDiscTotalMismatch
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: FeedbackSettingsKey.formatOnDiscTotalMismatch)
        }
    }

    @objc(FormatOnDuplicatePictureSetting)
    var formatOnDuplicatePictureSetting: Bool {
        get {
            boolSetting(
                key: FeedbackSettingsKey.formatOnDuplicatePicture,
                defaultValue: FeedbackSettingsDefaults.formatOnDuplicatePicture
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: FeedbackSettingsKey.formatOnDuplicatePicture)
        }
    }

    @objc(countOfScriptTracks)
    var countOfScriptTracks: Int {
        scriptTracks.count
    }

    @objc(countOfScriptSettingsWindows)
    var countOfScriptSettingsWindows: Int {
        scriptSettingsWindows.count
    }

    @objc(objectInScriptSettingsWindowsAtIndex:)
    func objectInScriptSettingsWindows(at index: Int) -> SwiftTagScriptSettingsWindow {
        scriptSettingsWindows[index]
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

    @objc(valueInScriptSettingsWindowsWithUniqueID:)
    func valueInScriptSettingsWindows(withUniqueID uniqueID: Any) -> Any? {
        SwiftTagAppleScriptController.shared.settingsWindow(withUniqueID: uniqueID)
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
            let request = try SwiftTagAppleScriptAddTracksRequest.from(arguments: command.evaluatedArguments)
            let targetWindow = try scriptEditorWindowTarget(from: command)
            let tracks = try targetWindow.addTracks(at: urls, locked: request.locked)
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

    @objc(handleOpenSettingsWindowScriptCommand:)
    func handleOpenSettingsWindowScriptCommand(_ command: NSScriptCommand) -> Any? {
        SwiftTagAppleScriptController.shared.openSettingsWindow()
    }

    @objc(handleMakeScriptCommand:)
    func handleMakeScriptCommand(_ command: NSScriptCommand) -> Any? {
        guard let createCommand = command as? NSCreateCommand else {
            return command.performDefaultImplementation()
        }

        do {
            switch createCommand.createClassDescription.className {
            case "picture":
                let track = try scriptTrackInsertionContainer(
                    from: createCommand,
                    key: "pictures",
                    error: .invalidPictureTrackTarget
                )
                return try track.makePicture(using: createCommand)
            case "tag":
                let track = try scriptTrackInsertionContainer(
                    from: createCommand,
                    key: "tags",
                    error: .invalidTagTrackTarget
                )
                return try track.makeTag(using: createCommand)
            default:
                return command.performDefaultImplementation()
            }
        } catch {
            return command.fail(error)
        }
    }

    @objc(handleQuitScriptCommand:)
    func handleQuitScriptCommand(_ command: NSScriptCommand) -> Any? {
        terminate(nil)
        return nil
    }

    private var saveScopeOptionSetting: SaveScopeOption {
        let rawValue = UserDefaults.standard.string(forKey: SaveSettingsKey.defaultSaveScope)
        return SaveScopeOption(rawValue: rawValue ?? "") ?? SaveSettingsDefaults.defaultSaveScope
    }

    private var savePayloadOptionSetting: SavePayloadOption {
        let rawValue = UserDefaults.standard.string(forKey: SaveSettingsKey.defaultSavePayload)
        return SavePayloadOption(rawValue: rawValue ?? "") ?? SaveSettingsDefaults.defaultSavePayload
    }

    private var trackCountKeyStrategySetting: TrackCountKeyStrategy {
        let rawValue = UserDefaults.standard.string(forKey: SaveSettingsKey.trackCountKeyStrategy)
        return TrackCountKeyStrategy(rawValue: rawValue ?? "") ?? SaveSettingsDefaults.trackCountKeyStrategy
    }

    private var discCountKeyStrategySetting: DiscCountKeyStrategy {
        let rawValue = UserDefaults.standard.string(forKey: SaveSettingsKey.discCountKeyStrategy)
        return DiscCountKeyStrategy(rawValue: rawValue ?? "") ?? SaveSettingsDefaults.discCountKeyStrategy
    }

    private var saveNotificationModeSetting: SaveNotificationMode {
        let rawValue = UserDefaults.standard.string(forKey: FeedbackSettingsKey.saveNotificationMode)
        return SaveNotificationMode(rawValue: rawValue ?? "") ?? FeedbackSettingsDefaults.saveNotificationMode
    }

    private var themePreferenceSetting: AppThemePreference {
        let rawValue = UserDefaults.standard.string(forKey: FeedbackSettingsKey.themePreference)
        return AppThemePreference(rawValue: rawValue ?? "") ?? FeedbackSettingsDefaults.themePreference
    }

    private func boolSetting(key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    private func scriptColorSetting(
        key: String,
        defaultRawValue: String,
        fallback: NSColor
    ) -> NSDictionary {
        SwiftTagScriptColor.from(
            rawValue: UserDefaults.standard.string(forKey: key) ?? defaultRawValue,
            fallback: fallback
        ).scriptRecord
    }

    private func setScriptColorSetting(_ rawValue: Any?, key: String, fallback: NSColor) {
        guard let color = SwiftTagScriptColor.from(scriptValue: rawValue, fallback: fallback) else {
            return
        }

        UserDefaults.standard.set(color.archivedRawValue, forKey: key)
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

    private func scriptTrackTarget(from command: NSScriptCommand) throws -> SwiftTagScriptTrack {
        if let track = scriptTrack(from: command.directParameter) {
            return track
        }

        if let track = scriptTrack(from: command.evaluatedReceivers) {
            return track
        }

        if let track = scriptTrack(from: command.receiversSpecifier?.objectsByEvaluatingSpecifier) {
            return track
        }

        if let subjectDescriptor = command.appleEvent?.attributeDescriptor(forKeyword: Self.swiftTagSubjectAttribute),
           let subjectSpecifier = NSScriptObjectSpecifier(descriptor: subjectDescriptor),
           let track = scriptTrack(from: subjectSpecifier.objectsByEvaluatingSpecifier) {
            return track
        }

        if let directObjectDescriptor = command.appleEvent?.paramDescriptor(forKeyword: Self.swiftTagDirectObjectKeyword),
           let directObjectSpecifier = NSScriptObjectSpecifier(descriptor: directObjectDescriptor),
           let track = scriptTrack(from: directObjectSpecifier.objectsByEvaluatingSpecifier) {
            return track
        }

        throw SwiftTagAppleScriptCommandError.invalidPictureTrackTarget
    }

    private func scriptTrack(from value: Any?) -> SwiftTagScriptTrack? {
        if let track = value as? SwiftTagScriptTrack {
            return track
        }

        if let tracks = value as? [SwiftTagScriptTrack], tracks.count == 1 {
            return tracks[0]
        }

        if let tracks = value as? NSArray, tracks.count == 1 {
            return tracks.firstObject as? SwiftTagScriptTrack
        }

        if let specifier = value as? NSScriptObjectSpecifier {
            return scriptTrack(from: specifier.objectsByEvaluatingSpecifier)
        }

        return nil
    }

    private func scriptTrackInsertionContainer(
        from command: NSCreateCommand,
        key expectedKey: String,
        error: SwiftTagAppleScriptCommandError
    ) throws -> SwiftTagScriptTrack {
        if let location = positionalSpecifier(from: command) {
            location.setInsertionClassDescription(command.createClassDescription)
            location.evaluate()
            guard location.insertionKey == expectedKey,
                  let track = location.insertionContainer as? SwiftTagScriptTrack else {
                throw error
            }
            return track
        }

        if let track = try? scriptTrackTarget(from: command) {
            return track
        }

        throw error
    }

    private func positionalSpecifier(from command: NSScriptCommand) -> NSPositionalSpecifier? {
        command.arguments?["Location"] as? NSPositionalSpecifier
            ?? command.arguments?["at"] as? NSPositionalSpecifier
            ?? command.evaluatedArguments?["Location"] as? NSPositionalSpecifier
            ?? command.evaluatedArguments?["at"] as? NSPositionalSpecifier
    }

    private static var swiftTagDirectObjectKeyword: AEKeyword {
        swiftTagAppleEventKeyword("----")
    }

    private static var swiftTagSubjectAttribute: AEKeyword {
        swiftTagAppleEventKeyword("subj")
    }

    nonisolated private static func swiftTagAppleEventKeyword(_ value: String) -> AEKeyword {
        let bytes = Array(value.utf8.prefix(4))
        let paddedBytes = bytes + Array(repeating: UInt8(32), count: max(0, 4 - bytes.count))
        return paddedBytes.prefix(4).reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
    }
}
