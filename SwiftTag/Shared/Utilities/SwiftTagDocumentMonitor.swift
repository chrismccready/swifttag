import Darwin
import Foundation

struct SwiftTagDocumentMonitorEvent {
    let currentPath: String?
}

@MainActor
final class SwiftTagDocumentMonitor {
    private struct Observation {
        let source: DispatchSourceFileSystemObject
        let fileDescriptor: Int32
        let securityScopedURL: URL?
        let didAccessSecurityScope: Bool
        var monitoredPath: String
    }

    private var observation: Observation?
    private var pendingRetry: Task<Void, Never>?

    deinit {
        pendingRetry?.cancel()
        observation?.source.cancel()
    }

    func replaceObservation(
        with state: SwiftTagDocumentSaveState,
        onChange: @escaping @MainActor (SwiftTagDocumentMonitorEvent) -> Void
    ) {
        guard let liveDestinationURL = state.liveDestinationURL else {
            stopAll()
            return
        }

        let monitoredPath = Self.monitoredPath(for: liveDestinationURL)
        if var existingObservation = observation {
            let pointsToCurrentPath = Self.fileDescriptor(
                existingObservation.fileDescriptor,
                pointsToPath: monitoredPath
            )

            if existingObservation.monitoredPath == monitoredPath && pointsToCurrentPath {
                return
            }

            if pointsToCurrentPath {
                existingObservation.monitoredPath = monitoredPath
                observation = existingObservation
                return
            }
        }

        stopAll()
        guard let newObservation = makeObservation(for: state, onChange: onChange) else {
            scheduleRetry(with: state, onChange: onChange)
            return
        }

        pendingRetry?.cancel()
        pendingRetry = nil
        observation = newObservation
        newObservation.source.resume()
    }

    func stopAll() {
        pendingRetry?.cancel()
        pendingRetry = nil

        guard let observation else {
            return
        }

        self.observation = nil
        observation.source.cancel()
    }

    private func makeObservation(
        for state: SwiftTagDocumentSaveState,
        onChange: @escaping @MainActor (SwiftTagDocumentMonitorEvent) -> Void
    ) -> Observation? {
        guard let resolved = resolveMonitoringURL(for: state) else {
            return nil
        }

        let monitoredURL = resolved.url
        let fileDescriptor = open(monitoredURL.path, O_EVTONLY)
        let openError = errno
        guard fileDescriptor >= 0 else {
            Self.debugTrapOnPermissionDeniedOpen(for: monitoredURL, errnoCode: openError)
            if resolved.didAccessSecurityScope {
                resolved.url.stopAccessingSecurityScopedResource()
            }
            return nil
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.main
        )
        source.setEventHandler {
            let currentPath = Self.pathForFileDescriptor(fileDescriptor)
            Task { @MainActor in
                onChange(SwiftTagDocumentMonitorEvent(currentPath: currentPath))
            }
        }
        source.setCancelHandler {
            close(fileDescriptor)
            if resolved.didAccessSecurityScope {
                resolved.url.stopAccessingSecurityScopedResource()
            }
        }

        return Observation(
            source: source,
            fileDescriptor: fileDescriptor,
            securityScopedURL: resolved.didAccessSecurityScope ? resolved.url : nil,
            didAccessSecurityScope: resolved.didAccessSecurityScope,
            monitoredPath: monitoredURL.path
        )
    }

    private func resolveMonitoringURL(
        for state: SwiftTagDocumentSaveState
    ) -> (url: URL, didAccessSecurityScope: Bool)? {
        if let bookmarkData = state.securityScopedBookmarkData {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ).standardizedFileURL
                let didAccess = resolvedURL.startAccessingSecurityScopedResource()
                if didAccess, FileManager.default.fileExists(atPath: resolvedURL.path) {
                    return (resolvedURL, true)
                }
                if didAccess {
                    resolvedURL.stopAccessingSecurityScopedResource()
                }
            } catch {
                // Fall back to the remembered URL when the bookmark can no longer resolve.
            }
        }

        guard let liveDestinationURL = state.liveDestinationURL,
              FileManager.default.fileExists(atPath: liveDestinationURL.path) else {
            return nil
        }

        return (liveDestinationURL, false)
    }

    private func scheduleRetry(
        with state: SwiftTagDocumentSaveState,
        onChange: @escaping @MainActor (SwiftTagDocumentMonitorEvent) -> Void
    ) {
        guard pendingRetry == nil else {
            return
        }

        pendingRetry = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let self else {
                return
            }

            self.pendingRetry = nil
            self.replaceObservation(with: state, onChange: onChange)
        }
    }

    private nonisolated static func monitoredPath(for fileURL: URL) -> String {
        fileURL.path
    }

    private nonisolated static func pathForFileDescriptor(_ fileDescriptor: Int32) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard fcntl(fileDescriptor, F_GETPATH, &pathBuffer) != -1 else {
            return nil
        }

        return String(cString: pathBuffer)
    }

    private nonisolated static func fileDescriptor(_ fileDescriptor: Int32, pointsToPath path: String) -> Bool {
        var descriptorStat = stat()
        guard fstat(fileDescriptor, &descriptorStat) == 0 else {
            return false
        }

        var pathStat = stat()
        guard stat(path, &pathStat) == 0 else {
            return false
        }

        return descriptorStat.st_dev == pathStat.st_dev &&
            descriptorStat.st_ino == pathStat.st_ino
    }

    @inline(never)
    private nonisolated static func debugTrapOnPermissionDeniedOpen(for fileURL: URL, errnoCode: Int32) {
#if DEBUG
        guard errnoCode == EPERM else {
            return
        }

        let message = "Could not open() the item: [\(errnoCode): \(String(cString: strerror(errnoCode)))] \(fileURL.path)"
        fputs("\(message)\n", stderr)
        raise(SIGTRAP)
#endif
    }
}
