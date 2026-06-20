import AppKit
import CryptoKit
import ImageIO
import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum AlbumArtPictureScope: String, CaseIterable, Identifiable {
    case allTrackPictures
    case selectedTrackPictures

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allTrackPictures:
            return "All Track Pictures"
        case .selectedTrackPictures:
            return "Selected Track Pictures"
        }
    }

    var systemImage: String {
        switch self {
        case .allTrackPictures:
            return "photo.stack.fill"
        case .selectedTrackPictures:
            return "photo.on.rectangle.angled.fill"
        }
    }
}

enum AlbumArtInfoOverlayMessageType: Equatable {
    case hasOutOfScopeReference
    case hasDuplicateInOtherSlot
}

struct AlbumArtInfoOverlayMessage: Equatable {
    let messageType: AlbumArtInfoOverlayMessageType
    let message: String
}

struct AlbumArtInfoOverlayState: Equatable {
    let poolItemID: UUID
    let messages: [AlbumArtInfoOverlayMessage]
}

struct AlbumArtPictureMetadata: Equatable {
    let poolItemID: UUID
    let description: String
    let poolItemIDShort: String
    let inSlotReferenceCount: Int
    let outOfSlotReferenceCount: Int
    let pinCount: Int
    let mimeType: String
    let byteCount: Int
    let currentIndex: Int
    let totalCount: Int
    
    func descriptionText() -> String {
        return self.description.isEmpty ? "None" : self.description
    }
    
    func mimeTypeText() -> String {
        return self.mimeType.isEmpty ? "NA" : self.mimeType
    }
    
    func byteCountText() -> String {
        return ByteCountFormatter.string(
            fromByteCount: Int64(self.byteCount),
            countStyle: .file
        )
    }
}

@MainActor
@Observable
final class AlbumArtViewModel {
    private enum FrontCoverDropAction {
        case cancel
        case replace
        case add
    }

    #if DEBUG
    var debugFrontCoverDropAction: String?
    #endif
    var isAlbumArtFileImporterPresented: Bool = false
    var isAlbumArtFileExporterPresented: Bool = false
    var pendingAlbumArtSlotForImport: AlbumArtSlot?
    var albumArtExportDocument: AlbumArtExportDocument?
    var albumArtExportContentType: UTType = .png
    var albumArtExportDefaultFileName: String = "Album Art"
    var albumArtNavigationPath: [AlbumArtSlot] = []
    var isPictureImportAlertPresented: Bool = false
    var pictureImportAlertMessage: String = ""

    // Legacy compatibility map still used by tests and existing call sites.
    var albumArtImages: [AlbumArtSlot: AlbumArtImageAsset] = [:]

    var picturePool: [UUID: AlbumArtPoolItem] = [:]
    var picturePoolOrder: [UUID] = []
    private var poolItemIDByKey: [String: UUID] = [:]
    var trackReferencesByTrackID: [UUID: [AlbumArtTrackReference]] = [:]
    var unpinnedReferenceKeysByTrackID: [UUID: Set<String>] = [:]
    var selectedTrackIDs: Set<UUID> = []
    var allTrackIDs: [UUID] = []
    var isTrackLockedByID: [UUID: Bool] = [:]
    var currentReferenceIndexBySlot: [AlbumArtSlot: Int] = [:]
    var infoOverlayStateBySlot: [AlbumArtSlot: AlbumArtInfoOverlayState] = [:]
    var typePictureScopeBySlot: [AlbumArtSlot: AlbumArtPictureScope] = [:]

    private var saveFrontCoverToAllTracks: Bool = SaveSettingsDefaults.saveFrontCoverToAllTracks
    private var saveAllPicturesToAllTracks: Bool = SaveSettingsDefaults.saveAllPicturesToAllTracks
    private var configuredSlots: [AlbumArtSlot] = []
    private var hasConfiguredPinSettings: Bool = false

    func configurePinSettings(saveFrontCoverToAllTracks: Bool, saveAllPicturesToAllTracks: Bool) {
        hasConfiguredPinSettings = true
        self.saveFrontCoverToAllTracks = saveFrontCoverToAllTracks
        self.saveAllPicturesToAllTracks = saveAllPicturesToAllTracks
        applyActivePinSettings()
    }

    func configureTrackContext(trackItems: [Track], selectedTrackIDs: Set<UUID>, albumArtTypes: [AlbumArtType]) {
        configuredSlots = albumArtTypes.map(\.slot)
        self.allTrackIDs = trackItems.map(\.id)
        self.selectedTrackIDs = selectedTrackIDs
        self.isTrackLockedByID = Dictionary(uniqueKeysWithValues: trackItems.map { ($0.id, $0.isLocked) })
        self.trackReferencesByTrackID = trackReferencesByTrackID
            .filter { allTrackIDs.contains($0.key) }
        self.unpinnedReferenceKeysByTrackID = unpinnedReferenceKeysByTrackID
            .filter { allTrackIDs.contains($0.key) }

        mergePoolAndReferences(from: trackItems, albumArtTypes: albumArtTypes)
        for slot in configuredSlots where typePictureScopeBySlot[slot] == nil {
            typePictureScopeBySlot[slot] = .selectedTrackPictures
        }
        typePictureScopeBySlot = typePictureScopeBySlot.filter { configuredSlots.contains($0.key) }
        if hasConfiguredPinSettings {
            applyActivePinSettings()
        }
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func imageForAlbumArtSlot(_ albumArtSlot: AlbumArtSlot) -> Image {
        if let asset = albumArtImages[albumArtSlot] {
            return Image(decorative: asset.cgImage, scale: 1, orientation: .up)
        }

        return Image(systemName: "photo.badge.plus")
    }

    func hasImage(for albumArtSlot: AlbumArtSlot) -> Bool {
        albumArtImages[albumArtSlot] != nil
    }

    func typePictureScope(for slot: AlbumArtSlot) -> AlbumArtPictureScope {
        typePictureScopeBySlot[slot] ?? .selectedTrackPictures
    }

    func setTypePictureScope(_ scope: AlbumArtPictureScope, for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) {
        guard !isTypePictureScopeControlDisabled(for: slot) else {
            syncLegacySlotImages(albumArtTypes: albumArtTypes)
            return
        }

        typePictureScopeBySlot[slot] = scope
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func discardTransientState(for trackIDs: Set<UUID>, albumArtTypes: [AlbumArtType]) {
        guard !trackIDs.isEmpty else {
            return
        }

        for trackID in trackIDs {
            trackReferencesByTrackID.removeValue(forKey: trackID)
            unpinnedReferenceKeysByTrackID.removeValue(forKey: trackID)
        }

        garbageCollectPool()
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func removeAppleScriptPictureIdentity(
        _ identity: SwiftTagAppleScriptPictureIdentity,
        for trackID: UUID,
        albumArtTypes: [AlbumArtType]
    ) {
        guard var refs = trackReferencesByTrackID[trackID] else {
            return
        }

        let removedRefs = refs.filter { $0.id == identity.id }
        guard !removedRefs.isEmpty else {
            return
        }

        refs.removeAll { $0.id == identity.id }
        for removedRef in removedRefs {
            clearReferencePinState(removedRef, for: trackID)
        }
        trackReferencesByTrackID[trackID] = refs
        garbageCollectPool()
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func uniquePictureCount(for albumArtSlot: AlbumArtSlot) -> (count: Int, pinCount: Int) {
        var uniquePoolIDs: Set<UUID> = []
        var pinCount = 0
        for trackID in visibleTrackIDs(for: typePictureScope(for: albumArtSlot)) {
            for reference in trackReferencesByTrackID[trackID, default: []] where reference.slot == albumArtSlot {
                uniquePoolIDs.insert(reference.poolItemID)
                if isReferencePinned(reference, for: trackID) {
                    pinCount += 1
                }
            }
        }
        return (uniquePoolIDs.count, pinCount)
    }

    func hasCrossTypeDuplicate(for slot: AlbumArtSlot) -> Bool {
        let visibleTrackIDs = visibleTrackIDs(for: typePictureScope(for: slot))
        let slotPoolItemIDs = Set(
            references(for: slot, trackIDs: visibleTrackIDs).map(\.poolItemID)
        )

        guard !slotPoolItemIDs.isEmpty else {
            return false
        }

        return trackReferencesByTrackID
            .filter { visibleTrackIDs.contains($0.key) }
            .values
            .joined()
            .contains { reference in
                reference.slot != slot && slotPoolItemIDs.contains(reference.poolItemID)
            }
    }

    private func duplicateTwinNames(for slot: AlbumArtSlot, poolItemID: UUID, albumArtTypes: [AlbumArtType]) -> [String] {
        let slotNameByValue = Dictionary(uniqueKeysWithValues: albumArtTypes.map { ($0.slot, $0.navigationLinkName) })
        let visibleTrackIDs = visibleTrackIDs(for: typePictureScope(for: slot))

        return Set(
            trackReferencesByTrackID
                .filter { visibleTrackIDs.contains($0.key) }
                .values
                .joined()
                .filter { $0.poolItemID == poolItemID && $0.slot != slot }
                .map { slotNameByValue[$0.slot] ?? "Other" }
        )
        .sorted()
    }

    func currentPictureMetadata(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) -> AlbumArtPictureMetadata? {
        guard let reference = currentReference(for: slot),
              let poolItem = picturePool[reference.poolItemID] else {
            return nil
        }

        var refCount = (inSlot: 0, outSlot: 0, pinCount: 0)
        for trackID in allTrackIDs {
            let refs = trackReferencesByTrackID[trackID, default: []]
            for ref in refs where ref.poolItemID == reference.poolItemID {
                if ref.slot == reference.slot {
                    refCount.inSlot += 1
                } else {
                    refCount.outSlot += 1
                }
                if isReferencePinned(ref, for: trackID) {
                    refCount.pinCount += 1
                }
            }
        }
        let presentedRefs = presentedReferences(for: slot)
        let typeImageCount = presentedRefs.count
        let currentIndex = min(currentReferenceIndexBySlot[slot, default: 0], max(typeImageCount - 1, 0)) + 1

        return AlbumArtPictureMetadata(
            poolItemID: reference.poolItemID,
            description: reference.description,
            poolItemIDShort: reference.poolItemIDShort(),
            inSlotReferenceCount: refCount.inSlot,
            outOfSlotReferenceCount: refCount.outSlot,
            pinCount: refCount.pinCount,
            mimeType: reference.mimeType,
            byteCount: poolItem.data.count,
            currentIndex: currentIndex,
            totalCount: typeImageCount
        )
    }

    func canEditCurrentPictureDescription(for slot: AlbumArtSlot) -> Bool {
        guard let currentReference = currentReference(for: slot),
              picturePool[currentReference.poolItemID] != nil else {
            return false
        }

        return !descriptionEditTargetTrackIDs(for: slot).isEmpty
    }

    func currentPictureDescriptionValidation(
        for slot: AlbumArtSlot,
        proposedDescription: String
    ) -> FlacPictureDescriptionValidation? {
        guard let currentReference = currentReference(for: slot),
              let poolItem = picturePool[currentReference.poolItemID] else {
            return nil
        }

        return FlacPictureDescriptionBudget.validation(
            mimeType: currentReference.mimeType,
            pictureData: poolItem.data,
            proposedDescription: proposedDescription
        )
    }

    func currentPictureImportValidation(
        for slot: AlbumArtSlot,
        proposedPictureData: Data,
        mimeType: String,
        albumArtTypes: [AlbumArtType]
    ) -> FlacPictureDataValidation? {
        let currentDescription = currentPictureImportDescription(for: slot, albumArtTypes: albumArtTypes)
        return FlacPictureDataBudget.validation(
            mimeType: mimeType,
            currentDescription: currentDescription,
            proposedPictureData: proposedPictureData
        )
    }

    @discardableResult
    func rejectOversizedPictureImportIfNeeded(
        for slot: AlbumArtSlot,
        pictureData: Data,
        mimeType: String,
        albumArtTypes: [AlbumArtType]
    ) -> Bool {
        guard let validation = currentPictureImportValidation(
            for: slot,
            proposedPictureData: pictureData,
            mimeType: mimeType,
            albumArtTypes: albumArtTypes
        ),
        !validation.isValid else {
            return false
        }

        presentPictureImportAlert(
            validation: validation,
            currentDescription: currentPictureImportDescription(for: slot, albumArtTypes: albumArtTypes)
        )
        return true
    }

    @discardableResult
    func updateCurrentPictureDescription(
        _ description: String,
        for slot: AlbumArtSlot,
        albumArtTypes: [AlbumArtType]
    ) -> Bool {
        guard let currentReference = currentReference(for: slot) else {
            return false
        }

        let targetTrackIDs = descriptionEditTargetTrackIDs(for: slot)
        guard !targetTrackIDs.isEmpty else {
            return false
        }

        var didUpdate = false

        for trackID in targetTrackIDs {
            var refs = trackReferencesByTrackID[trackID, default: []]

            for index in refs.indices {
                guard refs[index].slot == slot,
                      refs[index].poolItemID == currentReference.poolItemID else {
                    continue
                }

                let existingReference = refs[index]
                guard existingReference.description != description else {
                    continue
                }

                let wasPinned = isReferencePinned(existingReference, for: trackID)
                clearReferencePinState(existingReference, for: trackID)

                let updatedReference = AlbumArtTrackReference(
                    id: existingReference.id,
                    poolItemID: existingReference.poolItemID,
                    slot: existingReference.slot,
                    mimeType: existingReference.mimeType,
                    description: description
                )
                refs[index] = updatedReference
                setReferencePinned(updatedReference, for: trackID, isPinned: wasPinned)
                didUpdate = true
            }

            trackReferencesByTrackID[trackID] = refs
        }

        guard didUpdate else {
            return false
        }

        syncLegacySlotImages(albumArtTypes: albumArtTypes)
        return true
    }

    func infoOverlayMessages(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) -> [AlbumArtInfoOverlayMessage] {
        resolvedInfoOverlayState(for: slot, albumArtTypes: albumArtTypes)?.messages ?? []
    }

    func infoOverlayState(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) -> AlbumArtInfoOverlayState? {
        resolvedInfoOverlayState(for: slot, albumArtTypes: albumArtTypes)
    }

    func scopeLabelText() -> String {
        if selectedTrackIDs.isEmpty || selectedTrackIDs.count == allTrackIDs.count {
            return "All Tracks (\(allTrackIDs.count))"
        }
        return "Selected Tracks (\(selectedTrackIDs.count))"
    }

    func isCurrentPicturePinned(for slot: AlbumArtSlot) -> Bool {
        guard let currentReference = currentReference(for: slot) else {
            return false
        }

        let targetTrackIDs = manualTrackPinTargetTrackIDs(for: slot)
        guard !targetTrackIDs.isEmpty else {
            return false
        }

        return targetTrackIDs.allSatisfy { trackID in
            let refs = trackReferencesByTrackID[trackID, default: []]
            guard refs.contains(where: { $0.slot == slot && $0.poolItemID == currentReference.poolItemID }) else {
                return false
            }
            return isReferencePinned(currentReference, for: trackID)
        }
    }

    func setCurrentPicturePinned(_ isPinned: Bool, for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) {
        guard let currentReference = currentReference(for: slot) else {
            return
        }

        guard !isTrackPinControlDisabled(for: slot) else {
            syncLegacySlotImages(albumArtTypes: albumArtTypes)
            return
        }

        let targetTrackIDs = manualTrackPinTargetTrackIDs(for: slot)
        for trackID in targetTrackIDs {
            var refs = trackReferencesByTrackID[trackID, default: []]
            if isPinned {
                let alreadyPinned = refs.contains(where: { $0.slot == slot && $0.poolItemID == currentReference.poolItemID })
                if !alreadyPinned {
                    refs.append(
                        AlbumArtTrackReference(
                            poolItemID: currentReference.poolItemID,
                            slot: slot,
                            mimeType: currentReference.mimeType,
                            description: currentReference.description
                        )
                    )
                }
                setReferencePinned(currentReference, for: trackID, isPinned: true)
            } else {
                setReferencePinned(currentReference, for: trackID, isPinned: false)
            }
            trackReferencesByTrackID[trackID] = refs
        }

        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func canNavigatePictures(for slot: AlbumArtSlot) -> Bool {
        presentedReferences(for: slot).count > 1
    }

    func canGoToPreviousPicture(for slot: AlbumArtSlot) -> Bool {
        let refs = presentedReferences(for: slot)
        guard refs.count > 1 else {
            return false
        }

        return currentReferenceIndexBySlot[slot, default: 0] > 0
    }

    func canGoToNextPicture(for slot: AlbumArtSlot) -> Bool {
        let refs = presentedReferences(for: slot)
        guard refs.count > 1 else {
            return false
        }

        return currentReferenceIndexBySlot[slot, default: 0] < refs.count - 1
    }

    func goToFirstPicture(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) {
        guard canNavigatePictures(for: slot) else {
            return
        }
        currentReferenceIndexBySlot[slot] = 0
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func goToPreviousPicture(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) {
        let refs = presentedReferences(for: slot)
        guard !refs.isEmpty else {
            return
        }
        let currentIndex = currentReferenceIndexBySlot[slot, default: 0]
        currentReferenceIndexBySlot[slot] = max(0, currentIndex - 1)
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func goToNextPicture(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) {
        let refs = presentedReferences(for: slot)
        guard !refs.isEmpty else {
            return
        }
        let currentIndex = currentReferenceIndexBySlot[slot, default: 0]
        currentReferenceIndexBySlot[slot] = min(refs.count - 1, currentIndex + 1)
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func goToLastPicture(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) {
        let refs = presentedReferences(for: slot)
        guard !refs.isEmpty else {
            return
        }
        currentReferenceIndexBySlot[slot] = refs.count - 1
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func removeCurrentPicture(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) {
        guard let currentReference = currentReference(for: slot) else {
            return
        }

        let inScopeTrackIDs = Set(removalTargetTrackIDs())
        var outOfScopeReferenceExists = false

        for trackID in allTrackIDs {
            var refs = trackReferencesByTrackID[trackID, default: []]
            let hadReference = refs.contains(where: { $0.slot == slot && $0.poolItemID == currentReference.poolItemID })

            if inScopeTrackIDs.contains(trackID) {
                let removedRefs = refs.filter { $0.slot == slot && $0.poolItemID == currentReference.poolItemID }
                refs.removeAll { $0.slot == slot && $0.poolItemID == currentReference.poolItemID }
                for removedRef in removedRefs {
                    clearReferencePinState(removedRef, for: trackID)
                }
                trackReferencesByTrackID[trackID] = refs
            } else if hadReference {
                outOfScopeReferenceExists = true
            }
        }

        if outOfScopeReferenceExists {
            infoOverlayStateBySlot[slot] = AlbumArtInfoOverlayState(
                poolItemID: currentReference.poolItemID,
                messages: [
                    AlbumArtInfoOverlayMessage(
                        messageType: .hasOutOfScopeReference,
                        message: "Removed from selected tracks. Still visible because other tracks reference this picture. Re-pin to add it back."
                    )
                ]
            )
        } else {
            infoOverlayStateBySlot.removeValue(forKey: slot)
        }

        garbageCollectPool()
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func prepareAlbumArtExport(for albumArtSlot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) {
        guard let currentReference = currentReference(for: albumArtSlot),
              let poolItem = picturePool[currentReference.poolItemID] else {
            return
        }

        let exportType = utType(forMimeType: currentReference.mimeType)
        let fileExtension = exportType.preferredFilenameExtension ?? (exportType.conforms(to: .jpeg) ? "jpg" : "png")
        let baseName = albumArtTypes.first(where: { $0.slot == albumArtSlot })?.navigationLinkName ?? "Album Art"

        albumArtExportDocument = AlbumArtExportDocument(data: poolItem.data)
        albumArtExportContentType = exportType
        albumArtExportDefaultFileName = "\(baseName).\(fileExtension)"
        isAlbumArtFileExporterPresented = true
    }

    func currentPictureItemProviders(for slot: AlbumArtSlot) -> [NSItemProvider] {
        guard let currentReference = currentReference(for: slot),
              let poolItem = picturePool[currentReference.poolItemID] else {
            return []
        }

        let contentType = utType(forMimeType: currentReference.mimeType)
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: contentType.identifier, visibility: .all) { completion in
            completion(poolItem.data, nil)
            return nil
        }
        return [provider]
    }

    func copyCurrentPictureToPasteboard(for slot: AlbumArtSlot) {
        guard let currentReference = currentReference(for: slot),
              let poolItem = picturePool[currentReference.poolItemID] else {
            return
        }

        let contentType = utType(forMimeType: currentReference.mimeType)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(poolItem.data, forType: NSPasteboard.PasteboardType(contentType.identifier))
    }

    func handleAlbumArtFileExportResult(_ result: Result<URL, Error>) {
        albumArtExportDocument = nil
    }

    func handleAlbumArtDrop(
        _ providers: [NSItemProvider],
        for albumArtSlot: AlbumArtSlot,
        albumArtTypes: [AlbumArtType],
        didUpdate: @escaping () -> Void = {}
    ) -> Bool {
        if let imageProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            let preferredTypeIdentifier = preferredImageTypeIdentifier(for: imageProvider) ?? UTType.image.identifier
            imageProvider.loadDataRepresentation(forTypeIdentifier: preferredTypeIdentifier) { data, _ in
                guard let data,
                      let displayImage = AlbumArtDisplayImageFactory.displayImage(from: data) else {
                    return
                }

                Task { @MainActor in
                    if self.applyDroppedImage(
                        displayImage: displayImage,
                        data: data,
                        type: UTType(preferredTypeIdentifier) ?? self.albumArtType(for: data),
                        for: albumArtSlot,
                        albumArtTypes: albumArtTypes
                    ) {
                        didUpdate()
                    }
                }
            }
            return true
        }

        if let fileProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            fileProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = Self.droppedFileURL(from: item),
                      let data = try? Data(contentsOf: url),
                      let displayImage = AlbumArtDisplayImageFactory.displayImage(from: data) else {
                    return
                }

                Task { @MainActor in
                    if self.applyDroppedImage(
                        displayImage: displayImage,
                        data: data,
                        type: self.albumArtType(for: url),
                        for: albumArtSlot,
                        albumArtTypes: albumArtTypes
                    ) {
                        didUpdate()
                    }
                }
            }
            return true
        }

        return false
    }

    func handleAlbumArtFileImportResult(
        _ result: Result<[URL], Error>,
        albumArtTypes: [AlbumArtType],
        didUpdate: @escaping () -> Void = {}
    ) {
        defer {
            pendingAlbumArtSlotForImport = nil
        }

        guard case .success(let urls) = result,
              let selectedURL = urls.first,
              let pendingAlbumArtSlotForImport,
              selectedURL.startAccessingSecurityScopedResource() else {
            return
        }

        defer {
            selectedURL.stopAccessingSecurityScopedResource()
        }

        guard let data = try? Data(contentsOf: selectedURL),
              let displayImage = AlbumArtDisplayImageFactory.displayImage(from: data) else {
            return
        }

        if applyDroppedImage(
            displayImage: displayImage,
            data: data,
            type: albumArtType(for: selectedURL),
            for: pendingAlbumArtSlotForImport,
            albumArtTypes: albumArtTypes
        ) {
            didUpdate()
        }
    }

    func openAlbumArtFilePicker(for albumArtSlot: AlbumArtSlot) {
        pendingAlbumArtSlotForImport = albumArtSlot
        DispatchQueue.main.async {
            self.isAlbumArtFileImporterPresented = true
        }
    }

    func applyImportedFlacPictures(_ picturesByType: [Int: Data], albumArtTypes: [AlbumArtType]) {
        guard !picturesByType.isEmpty else {
            return
        }

        let albumArtTypeByFlacType = Dictionary(
            uniqueKeysWithValues: albumArtTypes.map { ($0.flacPictureType, $0) }
        )

        for (flacPictureType, data) in picturesByType {
            guard let mappedAlbumArtType = albumArtTypeByFlacType[flacPictureType],
                  let displayImage = AlbumArtDisplayImageFactory.displayImage(from: data) else {
                continue
            }

            albumArtImages[mappedAlbumArtType.slot] = AlbumArtImageAsset(
                image: displayImage.image,
                cgImage: displayImage.cgImage,
                type: albumArtType(for: data),
                data: data
            )
        }
    }

    func flacPictures(albumArtTypes: [AlbumArtType]) -> [FlacWritablePictureRecord] {
        var records: [FlacWritablePictureRecord] = []
        var seenReferenceIDs: Set<UUID> = []

        for slot in albumArtTypes.map(\.slot) {
            for reference in orderedReferences(for: slot) {
                guard !seenReferenceIDs.contains(reference.id),
                      let poolItem = picturePool[reference.poolItemID],
                      let flacType = albumArtTypes.first(where: { $0.slot == reference.slot })?.flacPictureType else {
                    continue
                }

                seenReferenceIDs.insert(reference.id)
                records.append(
                    writablePictureRecord(
                        reference: reference,
                        flacType: flacType,
                        poolItem: poolItem
                    )
                )
            }
        }

        return records
    }

    func flacPictures(for trackID: UUID, albumArtTypes: [AlbumArtType]) -> [FlacWritablePictureRecord] {
        var nonFrontCoverRecords: [FlacWritablePictureRecord] = []
        var frontCoverRecords: [FlacWritablePictureRecord] = []
        for slot in albumArtTypes.map(\.slot) {
            for reference in pinnedReferences(for: trackID, slot: slot) {
                guard let poolItem = picturePool[reference.poolItemID],
                      let flacType = albumArtTypes.first(where: { $0.slot == reference.slot })?.flacPictureType else {
                    continue
                }

                let record = writablePictureRecord(
                    reference: reference,
                    flacType: flacType,
                    poolItem: poolItem
                )

                if reference.slot == .frontCover {
                    frontCoverRecords.append(record)
                } else {
                    nonFrontCoverRecords.append(record)
                }
            }
        }

        return nonFrontCoverRecords + frontCoverRecords
    }

    private func writablePictureRecord(
        reference: AlbumArtTrackReference,
        flacType: Int,
        poolItem: AlbumArtPoolItem
    ) -> FlacWritablePictureRecord {
        let specifications = poolItem.specifications
        return FlacWritablePictureRecord(
            type: flacType,
            mimeType: reference.mimeType,
            description: reference.description,
            data: poolItem.data,
            width: specifications.width,
            height: specifications.height,
            depth: specifications.depth,
            colors: specifications.colors
        )
    }

    func appleScriptPictureIdentity(
        for trackID: UUID,
        pictureIndex: Int,
        albumArtTypes: [AlbumArtType]
    ) -> SwiftTagAppleScriptPictureIdentity? {
        var nonFrontCoverIdentities: [SwiftTagAppleScriptPictureIdentity] = []
        var frontCoverIdentities: [SwiftTagAppleScriptPictureIdentity] = []
        for slot in albumArtTypes.map(\.slot) {
            for reference in pinnedReferences(for: trackID, slot: slot) {
                guard picturePool[reference.poolItemID] != nil,
                      albumArtTypes.contains(where: { $0.slot == reference.slot }) else {
                    continue
                }

                let identity = SwiftTagAppleScriptPictureIdentity(
                    id: reference.id,
                    poolId: reference.poolItemID
                )

                if reference.slot == .frontCover {
                    frontCoverIdentities.append(identity)
                } else {
                    nonFrontCoverIdentities.append(identity)
                }
            }
        }

        let identities = nonFrontCoverIdentities + frontCoverIdentities
        guard identities.indices.contains(pictureIndex) else {
            return nil
        }
        return identities[pictureIndex]
    }

    func appleScriptPictureIdentity(
        for trackID: UUID,
        record: FlacWritablePictureRecord,
        occurrence: Int,
        albumArtTypes: [AlbumArtType]
    ) -> SwiftTagAppleScriptPictureIdentity? {
        guard let slot = albumArtTypes.first(where: { $0.flacPictureType == record.type })?.slot else {
            return nil
        }

        let matchingReferences = pinnedReferences(for: trackID, slot: slot).filter { reference in
            guard let poolItem = picturePool[reference.poolItemID] else {
                return false
            }

            return poolItem.data == record.data &&
                reference.mimeType == record.mimeType &&
                reference.description == record.description
        }
        guard matchingReferences.indices.contains(occurrence) else {
            return nil
        }

        let reference = matchingReferences[occurrence]
        return SwiftTagAppleScriptPictureIdentity(
            id: reference.id,
            poolId: reference.poolItemID
        )
    }

    private func mergePoolAndReferences(from trackItems: [Track], albumArtTypes: [AlbumArtType]) {
        let slotByType = Dictionary(uniqueKeysWithValues: albumArtTypes.map { ($0.flacPictureType, $0.slot) })

        for track in trackItems {
            let existingRefs = trackReferencesByTrackID[track.id, default: []]
            let incomingRefs = references(
                from: track.flacPictureRecords,
                slotByType: slotByType
            )

            guard !incomingRefs.isEmpty else {
                if trackReferencesByTrackID[track.id] == nil {
                    trackReferencesByTrackID[track.id] = []
                }
                continue
            }

            if existingRefs.isEmpty {
                trackReferencesByTrackID[track.id] = incomingRefs
                continue
            }

            var mergedRefs = existingRefs
            var matchedExistingIndices: Set<Int> = []
            for reference in incomingRefs {
                if let existingIndex = firstReferenceIndex(
                    in: mergedRefs,
                    excluding: matchedExistingIndices,
                    where: { referencesMatch($0, reference) }
                ) {
                    clearReferencePinState(mergedRefs[existingIndex], for: track.id)
                    matchedExistingIndices.insert(existingIndex)
                    continue
                }

                if let existingIndex = firstReferenceIndex(
                    in: mergedRefs,
                    excluding: matchedExistingIndices,
                    where: { referencesSharePictureIdentity($0, reference) }
                ) {
                    let existingReference = mergedRefs[existingIndex]
                    let wasPinned = isReferencePinned(existingReference, for: track.id)
                    clearReferencePinState(existingReference, for: track.id)
                    let updatedReference = referenceWithStableID(
                        existingReference: existingReference,
                        incomingReference: reference
                    )
                    mergedRefs[existingIndex] = updatedReference
                    setReferencePinned(updatedReference, for: track.id, isPinned: wasPinned)
                    matchedExistingIndices.insert(existingIndex)
                    continue
                }
                mergedRefs.append(reference)
                matchedExistingIndices.insert(mergedRefs.index(before: mergedRefs.endIndex))
            }
            trackReferencesByTrackID[track.id] = mergedRefs
        }
    }

    private func syncLegacySlotImages(albumArtTypes: [AlbumArtType]) {
        var updated: [AlbumArtSlot: AlbumArtImageAsset] = [:]

        for slot in albumArtTypes.map(\.slot) {
            guard let reference = currentReference(for: slot),
                  let poolItem = picturePool[reference.poolItemID] else {
                continue
            }

            updated[slot] = AlbumArtImageAsset(
                image: poolItem.image,
                cgImage: poolItem.cgImage,
                type: utType(forMimeType: reference.mimeType),
                data: poolItem.data
            )
        }

        albumArtImages = updated
    }

    @discardableResult
    private func applyDroppedImage(
        displayImage: AlbumArtDisplayImage,
        data: Data,
        type: UTType,
        for slot: AlbumArtSlot,
        albumArtTypes: [AlbumArtType]
    ) -> Bool {
        let existingPoolID = existingPoolItemID(for: data)
        let mimeType = type.preferredMIMEType ?? "image/png"
        let targetTrackIDs = manualTrackPinTargetTrackIDs(for: slot)

        guard !targetTrackIDs.isEmpty else {
            return false
        }

        if let existingPoolID {
            let targetTracksWithMatchingReference = targetTrackIDs.filter { trackID in
                trackReferencesByTrackID[trackID, default: []]
                    .contains(where: { $0.slot == slot && $0.poolItemID == existingPoolID })
            }

            if targetTracksWithMatchingReference.count == targetTrackIDs.count {
                focusSlotAfterAddingPicture(
                    poolID: existingPoolID,
                    for: slot,
                    addedExistingPicture: true
                )
                syncLegacySlotImages(albumArtTypes: albumArtTypes)
                return true
            }
        }

        if rejectOversizedPictureImportIfNeeded(
            for: slot,
            pictureData: data,
            mimeType: mimeType,
            albumArtTypes: albumArtTypes
        ) {
            return false
        }

        let poolID = existingPoolID ?? upsertPoolItem(displayImage: displayImage, data: data)

        if slot == .frontCover {
            let targetTracksWithFrontCover = targetTrackIDs.filter { trackID in
                trackReferencesByTrackID[trackID, default: []].contains(where: { $0.slot == .frontCover })
            }

            if existingPoolID != nil, !targetTracksWithFrontCover.isEmpty {
                let alreadyFirstEverywhere = targetTracksWithFrontCover.allSatisfy { trackID in
                    trackReferencesByTrackID[trackID, default: []].first(where: { $0.slot == .frontCover })?.poolItemID == poolID
                }

                if alreadyFirstEverywhere {
                    focusSlotAfterAddingPicture(
                        poolID: poolID,
                        for: slot,
                        addedExistingPicture: true
                    )
                    syncLegacySlotImages(albumArtTypes: albumArtTypes)
                    return true
                }

                let action = chooseFrontCoverDropAction()
                guard action != .cancel else {
                    return false
                }

                applyFrontCoverDrop(poolID: poolID, mimeType: mimeType, targetTrackIDs: targetTrackIDs, action: action)
                focusSlotAfterAddingPicture(
                    poolID: poolID,
                    for: slot,
                    addedExistingPicture: existingPoolID != nil
                )
                syncLegacySlotImages(albumArtTypes: albumArtTypes)
                return true
            }

            if !targetTracksWithFrontCover.isEmpty {
                let action = chooseFrontCoverDropAction()
                guard action != .cancel else {
                    return false
                }
                applyFrontCoverDrop(poolID: poolID, mimeType: mimeType, targetTrackIDs: targetTrackIDs, action: action)
                focusSlotAfterAddingPicture(
                    poolID: poolID,
                    for: slot,
                    addedExistingPicture: false
                )
                syncLegacySlotImages(albumArtTypes: albumArtTypes)
                return true
            }
        }

        for trackID in targetTrackIDs {
            var refs = trackReferencesByTrackID[trackID, default: []]
            let alreadyHasMatchingReference = refs.contains(where: { $0.slot == slot && $0.poolItemID == poolID })
            guard !alreadyHasMatchingReference else {
                trackReferencesByTrackID[trackID] = refs
                continue
            }

            if slot == .frontCover {
                refs.insert(
                    AlbumArtTrackReference(
                        poolItemID: poolID,
                        slot: slot,
                        mimeType: mimeType,
                        description: "Cover (front)"
                    ),
                    at: 0
                )
            } else {
                refs.append(
                    AlbumArtTrackReference(
                        poolItemID: poolID,
                        slot: slot,
                        mimeType: mimeType,
                        description: albumArtTypes.first(where: { $0.slot == slot })?.flacDescription ?? ""
                    )
                )
            }
            trackReferencesByTrackID[trackID] = refs
        }

        focusSlotAfterAddingPicture(
            poolID: poolID,
            for: slot,
            addedExistingPicture: existingPoolID != nil
        )
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
        return true
    }

    private func focusSlotAfterAddingPicture(
        poolID: UUID,
        for slot: AlbumArtSlot,
        addedExistingPicture: Bool
    ) {
        let refs = presentedReferences(for: slot)
        guard !refs.isEmpty else {
            currentReferenceIndexBySlot[slot] = 0
            return
        }

        if addedExistingPicture,
           let matchIndex = refs.firstIndex(where: { $0.poolItemID == poolID }) {
            currentReferenceIndexBySlot[slot] = matchIndex
            return
        }

        currentReferenceIndexBySlot[slot] = refs.count - 1
    }

    private func chooseFrontCoverDropAction() -> FrontCoverDropAction {
        #if DEBUG
        if let debugFrontCoverDropAction {
            switch debugFrontCoverDropAction {
            case "add":
                return .add
            case "replace":
                return .replace
            default:
                return .cancel
            }
        }
        #endif

        let alert = NSAlert()
        alert.messageText = "Front Cover Pictures Already Exist"
        alert.informativeText = "Choose how to handle the dropped front cover picture."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Replace Existing")
        alert.addButton(withTitle: "Add")

        switch alert.runModal() {
        case .alertSecondButtonReturn:
            return .replace
        case .alertThirdButtonReturn:
            return .add
        default:
            return .cancel
        }
    }

    private func applyFrontCoverDrop(
        poolID: UUID,
        mimeType: String,
        targetTrackIDs: [UUID],
        action: FrontCoverDropAction
    ) {
        for trackID in targetTrackIDs {
            var refs = trackReferencesByTrackID[trackID, default: []]

            switch action {
            case .cancel:
                return
            case .replace:
                let replacementIndex = refs.firstIndex(where: { $0.slot == .frontCover }) ?? refs.endIndex
                refs.removeAll { $0.slot == .frontCover }
                refs.insert(
                    AlbumArtTrackReference(
                        poolItemID: poolID,
                        slot: .frontCover,
                        mimeType: mimeType,
                        description: "Cover (front)"
                    ),
                    at: min(replacementIndex, refs.endIndex)
                )
            case .add:
                guard !refs.contains(where: { $0.slot == .frontCover && $0.poolItemID == poolID }) else {
                    trackReferencesByTrackID[trackID] = refs
                    continue
                }
                refs.append(
                    AlbumArtTrackReference(
                        poolItemID: poolID,
                        slot: .frontCover,
                        mimeType: mimeType,
                        description: "Cover (front)"
                    )
                )
            }
            trackReferencesByTrackID[trackID] = refs
        }
    }

    private func activeTrackIDs() -> [UUID] {
        if selectedTrackIDs.isEmpty || selectedTrackIDs.count == allTrackIDs.count {
            return allTrackIDs
        }
        return selectedTrackIDs.sorted { $0.uuidString < $1.uuidString }
    }

    private func orderedReferences(for slot: AlbumArtSlot) -> [AlbumArtTrackReference] {
        var refs: [AlbumArtTrackReference] = []
        for trackID in activeTrackIDs() {
            refs.append(contentsOf: trackReferencesByTrackID[trackID, default: []].filter { $0.slot == slot })
        }
        return refs
    }

    private func allReferences(for slot: AlbumArtSlot) -> [AlbumArtTrackReference] {
        references(for: slot, trackIDs: allTrackIDs)
    }

    private func references(for slot: AlbumArtSlot, trackIDs: [UUID]) -> [AlbumArtTrackReference] {
        var refs: [AlbumArtTrackReference] = []
        for trackID in trackIDs {
            refs.append(contentsOf: trackReferencesByTrackID[trackID, default: []].filter { $0.slot == slot })
        }
        return refs
    }

    private func presentedReferences(for slot: AlbumArtSlot) -> [AlbumArtTrackReference] {
        uniquePresentationReferences(from: references(for: slot, trackIDs: visibleTrackIDs(for: typePictureScope(for: slot))))
    }

    private func uniquePresentationReferences(from refs: [AlbumArtTrackReference]) -> [AlbumArtTrackReference] {
        var seenPoolIDs: Set<UUID> = []
        var uniqueRefs: [AlbumArtTrackReference] = []
        for reference in refs {
            guard !seenPoolIDs.contains(reference.poolItemID) else {
                continue
            }
            seenPoolIDs.insert(reference.poolItemID)
            uniqueRefs.append(reference)
        }
        return uniqueRefs
    }

    private func deduplicatedReferences(for slot: AlbumArtSlot) -> [AlbumArtTrackReference] {
        var seenPoolIDs: Set<UUID> = []
        var deduped: [AlbumArtTrackReference] = []
        for reference in allReferences(for: slot) {
            guard !seenPoolIDs.contains(reference.poolItemID) else {
                continue
            }
            seenPoolIDs.insert(reference.poolItemID)
            deduped.append(reference)
        }
        return deduped
    }

    private func referenceKey(for reference: AlbumArtTrackReference) -> String {
        [
            reference.slot.hashValue.description,
            reference.poolItemID.uuidString,
            reference.mimeType,
            reference.description
        ].joined(separator: "|")
    }

    private func references(
        from records: [FlacWritablePictureRecord],
        slotByType: [Int: AlbumArtSlot]
    ) -> [AlbumArtTrackReference] {
        records.compactMap { record in
            guard let slot = slotByType[record.type],
                  let displayImage = AlbumArtDisplayImageFactory.displayImage(from: record.data) else {
                return nil
            }

            let poolID = upsertPoolItem(displayImage: displayImage, data: record.data)
            return AlbumArtTrackReference(
                poolItemID: poolID,
                slot: slot,
                mimeType: record.mimeType,
                description: record.description
            )
        }
    }

    private func referencesMatch(_ lhs: AlbumArtTrackReference, _ rhs: AlbumArtTrackReference) -> Bool {
        lhs.poolItemID == rhs.poolItemID &&
            lhs.slot == rhs.slot &&
            lhs.mimeType == rhs.mimeType &&
            lhs.description == rhs.description
    }

    private func referencesSharePictureIdentity(_ lhs: AlbumArtTrackReference, _ rhs: AlbumArtTrackReference) -> Bool {
        lhs.poolItemID == rhs.poolItemID &&
            lhs.slot == rhs.slot &&
            lhs.mimeType == rhs.mimeType
    }

    private func firstReferenceIndex(
        in references: [AlbumArtTrackReference],
        excluding excludedIndices: Set<Int>,
        where predicate: (AlbumArtTrackReference) -> Bool
    ) -> Int? {
        references.indices.first { index in
            !excludedIndices.contains(index) && predicate(references[index])
        }
    }

    private func referenceWithStableID(
        existingReference: AlbumArtTrackReference,
        incomingReference: AlbumArtTrackReference
    ) -> AlbumArtTrackReference {
        AlbumArtTrackReference(
            id: existingReference.id,
            poolItemID: incomingReference.poolItemID,
            slot: incomingReference.slot,
            mimeType: incomingReference.mimeType,
            description: incomingReference.description
        )
    }

    private func isReferencePinned(_ reference: AlbumArtTrackReference, for trackID: UUID) -> Bool {
        let key = referenceKey(for: reference)
        return !(unpinnedReferenceKeysByTrackID[trackID] ?? []).contains(key)
    }

    private func setReferencePinned(_ reference: AlbumArtTrackReference, for trackID: UUID, isPinned: Bool) {
        let key = referenceKey(for: reference)
        var keys = unpinnedReferenceKeysByTrackID[trackID, default: []]
        if isPinned {
            keys.remove(key)
        } else {
            keys.insert(key)
        }
        if keys.isEmpty {
            unpinnedReferenceKeysByTrackID.removeValue(forKey: trackID)
        } else {
            unpinnedReferenceKeysByTrackID[trackID] = keys
        }
    }

    private func clearReferencePinState(_ reference: AlbumArtTrackReference, for trackID: UUID) {
        setReferencePinned(reference, for: trackID, isPinned: true)
    }

    private func currentReference(for slot: AlbumArtSlot) -> AlbumArtTrackReference? {
        let refs = presentedReferences(for: slot)
        guard !refs.isEmpty else {
            return nil
        }

        let requestedIndex = currentReferenceIndexBySlot[slot, default: 0]
        let index = min(max(0, requestedIndex), refs.count - 1)
        return refs[index]
    }

    private func resolvedInfoOverlayState(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) -> AlbumArtInfoOverlayState? {
        var messages: [AlbumArtInfoOverlayMessage] = []
        let currentPoolItemID = currentReference(for: slot)?.poolItemID
        var resolvedPoolItemID: UUID?

        let duplicateTwinNamesList = currentPoolItemID.map {
            duplicateTwinNames(for: slot, poolItemID: $0, albumArtTypes: albumArtTypes)
        } ?? []
        if !duplicateTwinNamesList.isEmpty {
            resolvedPoolItemID = currentPoolItemID
            messages.append(
                AlbumArtInfoOverlayMessage(
                    messageType: .hasDuplicateInOtherSlot,
                    message: "This picture is duplicated across types. Twin type(s): \(duplicateTwinNamesList.joined(separator: ", "))."
                )
            )
        }

        if let storedState = infoOverlayStateBySlot[slot] {
            let activeStoredMessages = storedState.messages.filter { message in
                switch message.messageType {
                case .hasOutOfScopeReference:
                    return hasOutOfScopeReference(for: slot, poolItemID: storedState.poolItemID)
                case .hasDuplicateInOtherSlot:
                    return !duplicateTwinNamesList.isEmpty
                }
            }

            if !activeStoredMessages.isEmpty {
                resolvedPoolItemID = storedState.poolItemID
                messages.append(contentsOf: activeStoredMessages.filter { $0.messageType != .hasDuplicateInOtherSlot })
            } else if storedState.messages.contains(where: { $0.messageType == .hasOutOfScopeReference }) {
                infoOverlayStateBySlot.removeValue(forKey: slot)
            }
        }

        guard !messages.isEmpty, let resolvedPoolItemID else {
            return nil
        }

        return AlbumArtInfoOverlayState(
            poolItemID: resolvedPoolItemID,
            messages: messages
        )
    }

    private func hasOutOfScopeReference(for slot: AlbumArtSlot, poolItemID: UUID) -> Bool {
        let inScopeTrackIDs = Set(removalTargetTrackIDs())
        let hasInScopeReference = inScopeTrackIDs.contains { trackID in
            trackReferencesByTrackID[trackID, default: []]
                .contains(where: { $0.slot == slot && $0.poolItemID == poolItemID })
        }
        let hasOutOfScopeReference = allTrackIDs.contains { trackID in
            !inScopeTrackIDs.contains(trackID) &&
                trackReferencesByTrackID[trackID, default: []]
                .contains(where: { $0.slot == slot && $0.poolItemID == poolItemID })
        }

        return hasOutOfScopeReference && !hasInScopeReference
    }

    private func visibleTrackIDs(for scope: AlbumArtPictureScope) -> [UUID] {
        switch scope {
        case .allTrackPictures:
            return allTrackIDs.sorted { $0.uuidString < $1.uuidString }
        case .selectedTrackPictures:
            if selectedTrackIDs.isEmpty {
                return allTrackIDs.sorted { $0.uuidString < $1.uuidString }
            }
            return selectedTrackIDs.sorted { $0.uuidString < $1.uuidString }
        }
    }

    private func editableTrackIDs(for scope: AlbumArtPictureScope) -> [UUID] {
        visibleTrackIDs(for: scope).filter { isTrackLockedByID[$0] != true }
    }

    private func manualTrackPinTargetTrackIDs(for slot: AlbumArtSlot) -> [UUID] {
        editableTrackIDs(for: slotEffectiveScope(for: slot))
    }

    private func descriptionEditTargetTrackIDs(for slot: AlbumArtSlot) -> [UUID] {
        guard let currentPoolItemID = currentReference(for: slot)?.poolItemID else {
            return []
        }

        return editableTrackIDs(for: slotEffectiveScope(for: slot)).filter { trackID in
            trackReferencesByTrackID[trackID, default: []]
                .contains(where: { $0.slot == slot && $0.poolItemID == currentPoolItemID })
        }
    }

    private func currentPictureImportDescription(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) -> String {
        if let currentReference = currentReference(for: slot) {
            return currentReference.description
        }

        return albumArtTypes.first(where: { $0.slot == slot })?.flacDescription ?? ""
    }

    private func presentPictureImportAlert(
        validation: FlacPictureDataValidation,
        currentDescription: String
    ) {
        let descriptionBytes = currentDescription.lengthOfBytes(using: .utf8)
        let proposedPictureSizeText = ByteCountFormatter.string(
            fromByteCount: Int64(validation.proposedPictureBytes),
            countStyle: .file
        )
        let maximumPictureSizeText = ByteCountFormatter.string(
            fromByteCount: Int64(validation.maximumPictureBytes),
            countStyle: .file
        )

        pictureImportAlertMessage = """
        This picture is too large to embed in FLAC. It uses \(proposedPictureSizeText) \
        (\(validation.proposedPictureBytes) bytes), but only \(maximumPictureSizeText) \
        (\(validation.maximumPictureBytes) bytes) are available after reserving \(descriptionBytes) \
        bytes for current description, required FLAC picture fields, and 256-byte buffer.
        """
        isPictureImportAlertPresented = true
    }

    private func removalTargetTrackIDs() -> [UUID] {
        if selectedTrackIDs.isEmpty || selectedTrackIDs.count == allTrackIDs.count {
            return editableTrackIDs(for: .allTrackPictures)
        }
        return editableTrackIDs(for: .selectedTrackPictures)
    }

    func isTrackPinControlDisabled(for slot: AlbumArtSlot) -> Bool {
        slotUsesForcedAllTracks(slot)
    }

    func isTypePictureScopeControlDisabled(for slot: AlbumArtSlot) -> Bool {
        slotUsesForcedAllTracks(slot)
    }

    private func pinnedReferences(for trackID: UUID, slot: AlbumArtSlot) -> [AlbumArtTrackReference] {
        trackReferencesByTrackID[trackID, default: []].filter {
            $0.slot == slot && isReferencePinned($0, for: trackID)
        }
    }

    private func slotEffectiveScope(for slot: AlbumArtSlot) -> AlbumArtPictureScope {
        slotUsesForcedAllTracks(slot) ? .allTrackPictures : typePictureScope(for: slot)
    }

    private func slotUsesForcedAllTracks(_ slot: AlbumArtSlot) -> Bool {
        guard hasConfiguredPinSettings else {
            return false
        }
        if slot == .frontCover, saveFrontCoverToAllTracks {
            return true
        }
        return saveAllPicturesToAllTracks
    }

    private func applyActivePinSettings() {
        guard !configuredSlots.isEmpty else {
            return
        }

        let unlockedTrackIDs = allTrackIDs.filter { isTrackLockedByID[$0] != true }
        guard !unlockedTrackIDs.isEmpty else {
            return
        }

        for slot in configuredSlots where slotUsesForcedAllTracks(slot) {
            typePictureScopeBySlot[slot] = .allTrackPictures
            let sourceReferences = uniquePresentationReferences(
                from: references(for: slot, trackIDs: unlockedTrackIDs)
            )
            guard !sourceReferences.isEmpty else {
                continue
            }

            for trackID in unlockedTrackIDs {
                var refs = trackReferencesByTrackID[trackID, default: []]
                for sourceReference in sourceReferences {
                    if let existingIndex = refs.firstIndex(where: { referencesMatch($0, sourceReference) }) {
                        setReferencePinned(refs[existingIndex], for: trackID, isPinned: true)
                        continue
                    }

                    if let existingIndex = refs.firstIndex(where: { referencesSharePictureIdentity($0, sourceReference) }) {
                        let updatedReference = referenceWithStableID(
                            existingReference: refs[existingIndex],
                            incomingReference: sourceReference
                        )
                        clearReferencePinState(refs[existingIndex], for: trackID)
                        refs[existingIndex] = updatedReference
                        setReferencePinned(updatedReference, for: trackID, isPinned: true)
                        continue
                    }

                    let copiedReference = AlbumArtTrackReference(
                        poolItemID: sourceReference.poolItemID,
                        slot: sourceReference.slot,
                        mimeType: sourceReference.mimeType,
                        description: sourceReference.description
                    )
                    refs.append(copiedReference)
                    setReferencePinned(copiedReference, for: trackID, isPinned: true)
                }
                trackReferencesByTrackID[trackID] = refs
            }
        }
    }

    private func garbageCollectPool() {
        let referencedPoolIDs = Set(trackReferencesByTrackID.values.flatMap { $0.map(\.poolItemID) })
        picturePool = picturePool.filter { referencedPoolIDs.contains($0.key) }
        picturePoolOrder.removeAll { !referencedPoolIDs.contains($0) }
        poolItemIDByKey = Dictionary(
            uniqueKeysWithValues: picturePoolOrder.compactMap { poolID in
                guard let item = picturePool[poolID] else {
                    return nil
                }
                return (Self.poolKey(for: item.data), poolID)
            }
        )
    }

    private func upsertPoolItem(displayImage: AlbumArtDisplayImage, data: Data) -> UUID {
        let key = Self.poolKey(for: data)
        if let existingID = poolItemIDByKey[key] {
            return existingID
        }

        let id = UUID()
        picturePool[id] = AlbumArtPoolItem(
            id: id,
            data: data,
            image: displayImage.image,
            cgImage: displayImage.cgImage,
            specifications: PictureDataUtilities.computedSpecifications(from: data)
        )
        picturePoolOrder.append(id)
        poolItemIDByKey[key] = id
        return id
    }

    private func existingPoolItemID(for data: Data) -> UUID? {
        poolItemIDByKey[Self.poolKey(for: data)]
    }

    private static func poolKey(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func utType(forMimeType mimeType: String) -> UTType {
        if mimeType.localizedCaseInsensitiveContains("jpeg") || mimeType.localizedCaseInsensitiveContains("jpg") {
            return .jpeg
        }
        return .png
    }

    private func albumArtType(for fileURL: URL) -> UTType {
        guard let type = UTType(filenameExtension: fileURL.pathExtension.lowercased()) else {
            return .png
        }

        if type.conforms(to: .jpeg) {
            return .jpeg
        }

        if type.conforms(to: .png) {
            return .png
        }

        return .png
    }

    private func albumArtType(for imageData: Data) -> UTType {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let sourceType = CGImageSourceGetType(source),
              let type = UTType(sourceType as String) else {
            return .png
        }

        if type.conforms(to: .jpeg) {
            return .jpeg
        }

        if type.conforms(to: .png) {
            return .png
        }

        return .png
    }

    private func preferredImageTypeIdentifier(for provider: NSItemProvider) -> String? {
        provider.registeredTypeIdentifiers.first { typeIdentifier in
            guard let type = UTType(typeIdentifier) else {
                return false
            }
            return type.conforms(to: .image)
        }
    }

    nonisolated private static func droppedFileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }

        if let text = item as? String {
            return URL(string: text)
        }

        if let text = item as? NSString {
            return URL(string: text as String)
        }

        return nil
    }
}

struct AlbumArtDisplayImage {
    let image: NSImage
    let cgImage: CGImage
}

enum AlbumArtDisplayImageFactory {
    private static let maximumDisplayPixelSize = 1024

    static func image(from data: Data) -> NSImage? {
        displayImage(from: data)?.image
    }

    static func displayImage(from data: Data) -> AlbumArtDisplayImage? {
        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDisplayPixelSize,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceDecodeRequest: kCGImageSourceDecodeToSDR
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }

        let cgImage = sRGBImage(from: thumbnail) ?? thumbnail
        return AlbumArtDisplayImage(
            image: NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            ),
            cgImage: cgImage
        )
    }

    private static func sRGBImage(from image: CGImage) -> CGImage? {
        guard image.width > 0,
              image.height > 0,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}
