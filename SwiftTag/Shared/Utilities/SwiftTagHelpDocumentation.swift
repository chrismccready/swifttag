import AppKit
import Foundation

enum SwiftTagHelpDocumentation {
    static func indexURL(in bundle: Bundle = .main) -> URL? {
        indexURL(resourceURL: bundle.resourceURL)
    }

    static func indexURL(resourceURL: URL?) -> URL? {
        guard let resourceURL else {
            return nil
        }

        return resourceURL
            .appendingPathComponent("UserDocumentation", isDirectory: true)
            .appendingPathComponent("index.html", isDirectory: false)
    }

    @MainActor
    static func open(in bundle: Bundle = .main, fileManager: FileManager = .default) {
        guard let documentationURL = indexURL(in: bundle),
              fileManager.fileExists(atPath: documentationURL.path) else {
            NSSound.beep()
            return
        }

        NSWorkspace.shared.open(documentationURL)
    }
}
