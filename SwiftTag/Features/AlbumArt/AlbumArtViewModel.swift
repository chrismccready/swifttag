import AppKit
import ImageIO
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class AlbumArtViewModel {
    var isAlbumArtFileImporterPresented: Bool = false
    var isAlbumArtFileExporterPresented: Bool = false
    var pendingAlbumArtSlotForImport: AlbumArtSlot?
    var albumArtExportDocument: AlbumArtExportDocument?
    var albumArtExportContentType: UTType = .png
    var albumArtExportDefaultFileName: String = "Album Art"
    var albumArtNavigationPath: [AlbumArtSlot] = []
    var albumArtImages: [AlbumArtSlot: AlbumArtImageAsset] = [:]

    func imageForAlbumArtSlot(_ albumArtSlot: AlbumArtSlot) -> Image {
        if let asset = albumArtImages[albumArtSlot] {
            return Image(nsImage: asset.image)
        }

        return Image(systemName: "photo.badge.plus")
    }

    func hasImage(for albumArtSlot: AlbumArtSlot) -> Bool {
        albumArtImages[albumArtSlot] != nil
    }

    func prepareAlbumArtExport(for albumArtSlot: AlbumArtSlot, albumArtTypes: [AlbumArtType]) {
        guard let asset = albumArtImages[albumArtSlot] else {
            return
        }

        let exportType: UTType = asset.type.conforms(to: .jpeg) ? .jpeg : .png
        let fileExtension = exportType.preferredFilenameExtension ?? (exportType.conforms(to: .jpeg) ? "jpg" : "png")
        let baseName = albumArtTypes.first(where: { $0.slot == albumArtSlot })?.navigationLinkName ?? "Album Art"
        let data = asset.type == exportType ? asset.data : (imageData(from: asset.image, as: exportType) ?? asset.data)

        albumArtExportDocument = AlbumArtExportDocument(data: data)
        albumArtExportContentType = exportType
        albumArtExportDefaultFileName = "\(baseName).\(fileExtension)"
        isAlbumArtFileExporterPresented = true
    }

    func handleAlbumArtFileExportResult(_ result: Result<URL, Error>) {
        albumArtExportDocument = nil
    }

    func handleAlbumArtDrop(_ providers: [NSItemProvider], for albumArtSlot: AlbumArtSlot) -> Bool {
        if let imageProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            imageProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data, let image = NSImage(data: data) else {
                    return
                }

                Task { @MainActor in
                    self.setAlbumArtImage(image, data: data, type: self.albumArtType(for: data), for: albumArtSlot)
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
                    self.setAlbumArtImage(image, data: data, type: self.albumArtType(for: url), for: albumArtSlot)
                }
            }
            return true
        }

        return false
    }

    func handleAlbumArtFileImportResult(_ result: Result<[URL], Error>) {
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

        guard let image = NSImage(contentsOf: selectedURL) else {
            return
        }

        guard let data = try? Data(contentsOf: selectedURL) else {
            return
        }

        setAlbumArtImage(image, data: data, type: albumArtType(for: selectedURL), for: pendingAlbumArtSlotForImport)
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

            setAlbumArtImage(image, data: data, type: albumArtType(for: data), for: mappedAlbumArtType.slot)
        }
    }

    func flacPictures(albumArtTypes: [AlbumArtType]) -> [FlacWritablePictureRecord] {
        let albumArtTypeBySlot = Dictionary(uniqueKeysWithValues: albumArtTypes.map { ($0.slot, $0) })

        return albumArtImages.compactMap { slot, asset in
            guard let albumArtType = albumArtTypeBySlot[slot] else {
                return nil
            }

            return FlacWritablePictureRecord(
                type: albumArtType.flacPictureType,
                mimeType: asset.type.preferredMIMEType ?? "image/png",
                description: albumArtType.flacDescription,
                data: asset.data
            )
        }
        .sorted { lhs, rhs in
            lhs.type < rhs.type
        }
    }

    private func setAlbumArtImage(_ image: NSImage, data: Data, type: UTType, for albumArtSlot: AlbumArtSlot) {
        albumArtImages[albumArtSlot] = AlbumArtImageAsset(image: image, type: type, data: data)
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

    private func imageData(from image: NSImage, as type: UTType) -> Data? {
        guard let tiffRepresentation = image.tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }

        let bitmapFileType: NSBitmapImageRep.FileType = type.conforms(to: .jpeg) ? .jpeg : .png
        return bitmapRepresentation.representation(using: bitmapFileType, properties: [:])
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
