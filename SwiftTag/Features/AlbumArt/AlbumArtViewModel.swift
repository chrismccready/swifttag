import AppKit
import CryptoKit
import ImageIO
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

struct AlbumArtInfoOverlayState {
    let poolItemID: UUID
    let message: String
}

@MainActor
@Observable
final class AlbumArtViewModel {
    private enum FrontCoverDropAction {
        case cancel
        case replace
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
    var pinAlbumPictures: Bool = false
    var trackPictureScope: AlbumArtPictureScope = .allTrackPictures
    var typePictureScopeBySlot: [AlbumArtSlot: AlbumArtPictureScope] = [:]

    private var saveFrontCoverToAllTracks: Bool = SaveSettingsDefaults.saveFrontCoverToAllTracks
    private var saveAllPicturesToAllTracks: Bool = SaveSettingsDefaults.saveAllPicturesToAllTracks

    func configurePinSettings(saveFrontCoverToAllTracks: Bool, saveAllPicturesToAllTracks: Bool) {
        self.saveFrontCoverToAllTracks = saveFrontCoverToAllTracks
        self.saveAllPicturesToAllTracks = saveAllPicturesToAllTracks
    }

    func configureTrackContext(trackItems: [Track], selectedTrackIDs: Set<UUID>, albumArtTypes: [AlbumArtType]) {
        self.allTrackIDs = trackItems.map(\.id)
        self.selectedTrackIDs = selectedTrackIDs
        self.isTrackLockedByID = Dictionary(uniqueKeysWithValues: trackItems.map { ($0.id, $0.isLocked) })
        self.trackReferencesByTrackID = trackReferencesByTrackID
            .filter { allTrackIDs.contains($0.key) }
        self.unpinnedReferenceKeysByTrackID = unpinnedReferenceKeysByTrackID
            .filter { allTrackIDs.contains($0.key) }

        mergePoolAndReferences(from: trackItems, albumArtTypes: albumArtTypes)
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func imageForAlbumArtSlot(_ albumArtSlot: AlbumArtSlot) -> Image {
        if let asset = albumArtImages[albumArtSlot] {
            return Image(nsImage: asset.image)
        }

        return Image(systemName: "photo.badge.plus")
    }

    func hasImage(for albumArtSlot: AlbumArtSlot) -> Bool {
        albumArtImages[albumArtSlot] != nil
    }

    func typePictureScope(for slot: AlbumArtSlot) -> AlbumArtPictureScope {
        typePictureScopeBySlot[slot] ?? .allTrackPictures
    }

    func setTrackPictureScope(_ scope: AlbumArtPictureScope, albumArtTypes: [AlbumArtType]) {
        trackPictureScope = scope
        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    func setTypePictureScope(_ scope: AlbumArtPictureScope, for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) {
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

    func isPinAlbumPicturesOn() -> Bool {
        saveAllPicturesToAllTracks || pinAlbumPictures
    }

    func isPinAlbumPicturesDisabled() -> Bool {
        saveAllPicturesToAllTracks || hasLockedTrackInScope(trackPictureScope)
    }

    func uniquePictureCount(for albumArtSlot: AlbumArtSlot) -> Int {
        var uniquePoolIDs: Set<UUID> = []
        for trackID in visibleTrackIDs(for: trackPictureScope) {
            for reference in trackReferencesByTrackID[trackID, default: []] where reference.slot == albumArtSlot {
                uniquePoolIDs.insert(reference.poolItemID)
            }
        }
        return uniquePoolIDs.count
    }

    func hasCrossTypeDuplicate(for slot: AlbumArtSlot) -> Bool {
        for trackID in allTrackIDs {
            let refs = trackReferencesByTrackID[trackID, default: []]
            let slotRefs = refs.filter { $0.slot == slot }
            for slotRef in slotRefs {
                if refs.contains(where: { $0.poolItemID == slotRef.poolItemID && $0.slot != slot }) {
                    return true
                }
            }
        }
        return false
    }

    func duplicateOverlayText(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) -> String? {
        guard let currentReference = currentReference(for: slot) else {
            return nil
        }

        let slotNameByValue = Dictionary(uniqueKeysWithValues: albumArtTypes.map { ($0.slot, $0.navigationLinkName) })
        var twinNames: Set<String> = []

        for trackID in allTrackIDs {
            let refs = trackReferencesByTrackID[trackID, default: []]
            guard refs.contains(where: { $0.slot == slot && $0.poolItemID == currentReference.poolItemID }) else {
                continue
            }

            for twin in refs where twin.poolItemID == currentReference.poolItemID && twin.slot != slot {
                twinNames.insert(slotNameByValue[twin.slot] ?? "Other")
            }
        }

        guard !twinNames.isEmpty else {
            return nil
        }
        let names = twinNames.sorted().joined(separator: ", ")
        return "This picture is duplicated across types. Twin type(s): \(names)."
    }

    func currentPictureMetadataText(for slot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) -> String? {
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
        let descriptionText = reference.description.isEmpty ? "None" : reference.description
        let mimeText = reference.mimeType.isEmpty ? "unknown" : reference.mimeType
        let byteCount = ByteCountFormatter.string(fromByteCount: Int64(poolItem.data.count), countStyle: .file)
//        let inFileStatus = inFileStatusText(for: reference)
        return "\(descriptionText) \(reference.poolItemIDShort()) \(refCount.inSlot) \(refCount.outSlot) \(refCount.pinCount) · \(mimeText) · \(byteCount) · \(currentIndex) of \(typeImageCount)"
    }

    func infoOverlayText(for slot: AlbumArtSlot) -> String? {
        guard let overlayState = infoOverlayStateBySlot[slot],
              let currentReference = currentReference(for: slot),
              currentReference.poolItemID == overlayState.poolItemID else {
            return nil
        }

        return overlayState.message
    }

    func scopeLabelText() -> String {
        if selectedTrackIDs.isEmpty || selectedTrackIDs.count == allTrackIDs.count {
            return "All Tracks"
        }
        return "Selected Tracks (\(selectedTrackIDs.count))"
    }

    func hasLockedTrackInActiveSelection() -> Bool {
        if selectedTrackIDs.isEmpty || selectedTrackIDs.count == allTrackIDs.count {
            return allTrackIDs.contains { isTrackLockedByID[$0] == true }
        }
        return selectedTrackIDs.contains { isTrackLockedByID[$0] == true }
    }

    func isCurrentPicturePinned(for slot: AlbumArtSlot) -> Bool {
        guard let currentReference = currentReference(for: slot) else {
            return false
        }

        if let forcedState = forcedTrackPinState(for: slot, reference: currentReference) {
            return forcedState
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

        guard !isTrackPinForced(for: slot) else {
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

    func setAlbumPicturesPinned(_ isPinned: Bool, albumArtTypes: [AlbumArtType]) {
        guard !saveAllPicturesToAllTracks else {
            syncLegacySlotImages(albumArtTypes: albumArtTypes)
            return
        }

        pinAlbumPictures = isPinned
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
                message: "Removed from selected tracks. Still visible because other tracks reference this picture. Re-pin to add it back."
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
            imageProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data, let image = NSImage(data: data) else {
                    return
                }

                Task { @MainActor in
                    self.applyDroppedImage(
                        image: image,
                        data: data,
                        type: self.albumArtType(for: data),
                        for: albumArtSlot,
                        albumArtTypes: albumArtTypes
                    )
                    didUpdate()
                }
            }
            return true
        }

        if let fileProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            fileProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = Self.droppedFileURL(from: item),
                      let image = NSImage(contentsOf: url),
                      let data = try? Data(contentsOf: url) else {
                    return
                }

                Task { @MainActor in
                    self.applyDroppedImage(
                        image: image,
                        data: data,
                        type: self.albumArtType(for: url),
                        for: albumArtSlot,
                        albumArtTypes: albumArtTypes
                    )
                    didUpdate()
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

        guard let image = NSImage(contentsOf: selectedURL),
              let data = try? Data(contentsOf: selectedURL) else {
            return
        }

        applyDroppedImage(
            image: image,
            data: data,
            type: albumArtType(for: selectedURL),
            for: pendingAlbumArtSlotForImport,
            albumArtTypes: albumArtTypes
        )
        didUpdate()
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
                  let image = NSImage(data: data) else {
                continue
            }

            albumArtImages[mappedAlbumArtType.slot] = AlbumArtImageAsset(
                image: image,
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
                    FlacWritablePictureRecord(
                        type: flacType,
                        mimeType: reference.mimeType,
                        description: reference.description,
                        data: poolItem.data
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
            for reference in effectivePinnedReferences(for: trackID, slot: slot) {
                guard let poolItem = picturePool[reference.poolItemID],
                      let flacType = albumArtTypes.first(where: { $0.slot == reference.slot })?.flacPictureType else {
                    continue
                }

                let record = FlacWritablePictureRecord(
                    type: flacType,
                    mimeType: reference.mimeType,
                    description: reference.description,
                    data: poolItem.data
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
            for reference in incomingRefs {
                if let existingIndex = mergedRefs.firstIndex(where: { referencesMatch($0, reference) }) {
                    clearReferencePinState(mergedRefs[existingIndex], for: track.id)
                    continue
                }
                mergedRefs.append(reference)
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
                type: utType(forMimeType: reference.mimeType),
                data: poolItem.data
            )
        }

        albumArtImages = updated
    }

    private func applyDroppedImage(
        image: NSImage,
        data: Data,
        type: UTType,
        for slot: AlbumArtSlot,
        albumArtTypes: [AlbumArtType]
    ) {
        let existingPoolID = existingPoolItemID(for: data)
        let poolID = existingPoolID ?? upsertPoolItem(image: image, data: data)
        let mimeType = type.preferredMIMEType ?? "image/png"
        let targetTrackIDs = manualTrackPinTargetTrackIDs(for: slot)

        guard !targetTrackIDs.isEmpty else {
            return
        }

        if slot == .frontCover {
            let targetTracksWithFrontCover = targetTrackIDs.filter { trackID in
                trackReferencesByTrackID[trackID, default: []].contains(where: { $0.slot == .frontCover })
            }

            if existingPoolID != nil, !targetTracksWithFrontCover.isEmpty {
                let alreadyFirstEverywhere = targetTracksWithFrontCover.allSatisfy { trackID in
                    trackReferencesByTrackID[trackID, default: []].first(where: { $0.slot == .frontCover })?.poolItemID == poolID
                }

                if alreadyFirstEverywhere {
                    syncLegacySlotImages(albumArtTypes: albumArtTypes)
                    return
                }

                let action = chooseFrontCoverDropAction()
                guard action != .cancel else {
                    return
                }

                applyFrontCoverDrop(poolID: poolID, mimeType: mimeType, targetTrackIDs: targetTrackIDs, action: action)
                syncLegacySlotImages(albumArtTypes: albumArtTypes)
                return
            }

            if !targetTracksWithFrontCover.isEmpty {
                let action = chooseFrontCoverDropAction()
                guard action != .cancel else {
                    return
                }
                applyFrontCoverDrop(poolID: poolID, mimeType: mimeType, targetTrackIDs: targetTrackIDs, action: action)
                syncLegacySlotImages(albumArtTypes: albumArtTypes)
                return
            }
        }

        for trackID in targetTrackIDs {
            var refs = trackReferencesByTrackID[trackID, default: []]
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

        syncLegacySlotImages(albumArtTypes: albumArtTypes)
    }

    private func chooseFrontCoverDropAction() -> FrontCoverDropAction {
        #if DEBUG
        if let debugFrontCoverDropAction {
            switch debugFrontCoverDropAction {
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

        switch alert.runModal() {
        case .alertSecondButtonReturn:
            return .replace
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
                  let image = NSImage(data: record.data) else {
                return nil
            }

            let poolID = upsertPoolItem(image: image, data: record.data)
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

    private func hasLockedTrackInScope(_ scope: AlbumArtPictureScope) -> Bool {
        visibleTrackIDs(for: scope).contains { isTrackLockedByID[$0] == true }
    }

    private func manualTrackPinTargetTrackIDs(for slot: AlbumArtSlot) -> [UUID] {
        if slot == .frontCover, saveFrontCoverToAllTracks {
            return editableTrackIDs(for: .allTrackPictures)
        }
        if saveAllPicturesToAllTracks {
            return editableTrackIDs(for: .allTrackPictures)
        }
        return editableTrackIDs(for: typePictureScope(for: slot))
    }

    private func albumPinTargetTrackIDs() -> [UUID] {
        editableTrackIDs(for: trackPictureScope)
    }

    private func removalTargetTrackIDs() -> [UUID] {
        if selectedTrackIDs.isEmpty || selectedTrackIDs.count == allTrackIDs.count {
            return editableTrackIDs(for: .allTrackPictures)
        }
        return editableTrackIDs(for: .selectedTrackPictures)
    }

    func isTrackPinForced(for slot: AlbumArtSlot) -> Bool {
        if saveAllPicturesToAllTracks {
            return true
        }
        if slot == .frontCover, saveFrontCoverToAllTracks {
            return true
        }
        return pinAlbumPictures
    }

    private func forcedTrackPinState(for slot: AlbumArtSlot, reference: AlbumArtTrackReference) -> Bool? {
        if saveAllPicturesToAllTracks {
            return hasAnyPicture(for: slot)
        }
        if slot == .frontCover, saveFrontCoverToAllTracks {
            return hasAnyPicture(for: .frontCover)
        }
        if pinAlbumPictures {
            return true
        }
        return nil
    }

    private func hasAnyPicture(for slot: AlbumArtSlot) -> Bool {
        !allReferences(for: slot).isEmpty
    }

    private func inFileStatusText(for reference: AlbumArtTrackReference) -> String {
        let trackIDs = activeTrackIDs()
        guard !trackIDs.isEmpty else {
            return "No"
        }

        let count = trackIDs.count(where: { trackID in
            trackReferencesByTrackID[trackID, default: []].contains(where: {
                $0.slot == reference.slot && $0.poolItemID == reference.poolItemID
            })
        })

        switch count {
        case 0:
            return "No"
        case trackIDs.count:
            return "Yes"
        default:
            return "Mixed"
        }
    }

    private func effectivePinnedReferences(for trackID: UUID, slot: AlbumArtSlot) -> [AlbumArtTrackReference] {
        let refs = trackReferencesByTrackID[trackID, default: []].filter {
            $0.slot == slot && isReferencePinned($0, for: trackID)
        }

        guard isTrackLockedByID[trackID] != true else {
            return refs
        }

        if saveAllPicturesToAllTracks {
            return mergeUniqueReferences(
                refs,
                with: uniquePresentationReferences(from: allReferences(for: slot))
            )
        }

        if slot == .frontCover, saveFrontCoverToAllTracks {
            return mergeUniqueReferences(
                refs,
                with: uniquePresentationReferences(from: allReferences(for: .frontCover))
            )
        }

        guard pinAlbumPictures, albumPinTargetTrackIDs().contains(trackID) else {
            return refs
        }

        return mergeUniqueReferences(
            refs,
            with: uniquePresentationReferences(from: references(for: slot, trackIDs: visibleTrackIDs(for: trackPictureScope)))
        )
    }

    private func mergeUniqueReferences(
        _ lhs: [AlbumArtTrackReference],
        with rhs: [AlbumArtTrackReference]
    ) -> [AlbumArtTrackReference] {
        var merged = lhs
        for reference in rhs where !merged.contains(where: { referencesMatch($0, reference) }) {
            merged.append(reference)
        }
        return merged
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

    private func upsertPoolItem(image: NSImage, data: Data) -> UUID {
        let key = Self.poolKey(for: data)
        if let existingID = poolItemIDByKey[key] {
            return existingID
        }

        let id = UUID()
        picturePool[id] = AlbumArtPoolItem(id: id, data: data, image: image)
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
