import Darwin
import Foundation

@MainActor
final class TrackFileMonitor {
    private struct Observation {
        let trackID: UUID
        let source: DispatchSourceFileSystemObject
        let fileDescriptor: Int32
        let securityScopedURL: URL?
        let didAccessSecurityScope: Bool
        var monitoredPath: String
    }

    private var observationsByTrackID: [UUID: Observation] = [:]
    private var pendingRetryTrackIDs: Set<UUID> = []

    deinit {
        let observations = Array(observationsByTrackID.values)
        for observation in observations {
            observation.source.cancel()
        }
    }

    func replaceObservations(
        for tracks: [Track],
        onChange: @escaping @MainActor (TrackFileMonitorEvent) -> Void
    ) {
        let targetTrackIDs: Set<UUID> = Set(tracks.compactMap { track in
            guard track.sourceFileURL != nil else {
                return nil
            }

            return track.id
        })

        for trackID in Set(observationsByTrackID.keys).subtracting(targetTrackIDs) {
            removeObservation(for: trackID)
        }

        for track in tracks {
            guard let sourceFileURL = track.sourceFileURL else {
                removeObservation(for: track.id)
                continue
            }

            let monitoredPath = Self.monitoredPath(for: sourceFileURL)
            if var existingObservation = observationsByTrackID[track.id] {
                let pointsToCurrentPath = Self.fileDescriptor(
                    existingObservation.fileDescriptor,
                    pointsToPath: monitoredPath
                )

                if existingObservation.monitoredPath == monitoredPath && pointsToCurrentPath {
                    continue
                }

                if existingObservation.monitoredPath == monitoredPath,
                   !FileManager.default.fileExists(atPath: monitoredPath) {
                    continue
                }

                if pointsToCurrentPath {
                    existingObservation.monitoredPath = monitoredPath
                    observationsByTrackID[track.id] = existingObservation
                    continue
                }
            }

            removeObservation(for: track.id)
            guard let observation = makeObservation(for: track, onChange: onChange) else {
                scheduleObservationRetry(for: track, onChange: onChange)
                continue
            }
            observationsByTrackID[track.id] = observation
            pendingRetryTrackIDs.remove(track.id)
            observation.source.resume()
        }
    }

    func stopAll() {
        for trackID in Array(observationsByTrackID.keys) {
            removeObservation(for: trackID)
        }
    }

    private func makeObservation(
        for track: Track,
        onChange: @escaping @MainActor (TrackFileMonitorEvent) -> Void
    ) -> Observation? {
        guard let resolved = resolveMonitoringURL(for: track) else {
            return nil
        }

        let monitoredURL = Self.monitoredURL(for: resolved.url)
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
        source.setEventHandler { [trackID = track.id] in
            let currentPath = Self.pathForFileDescriptor(fileDescriptor)
            Task { @MainActor in
                onChange(TrackFileMonitorEvent(trackID: trackID, currentPath: currentPath))
            }
        }
        source.setCancelHandler {
            close(fileDescriptor)
            if resolved.didAccessSecurityScope {
                resolved.url.stopAccessingSecurityScopedResource()
            }
        }

        return Observation(
            trackID: track.id,
            source: source,
            fileDescriptor: fileDescriptor,
            securityScopedURL: resolved.didAccessSecurityScope ? resolved.url : nil,
            didAccessSecurityScope: resolved.didAccessSecurityScope,
            monitoredPath: monitoredURL.path
        )
    }

    private func resolveMonitoringURL(for track: Track) -> (url: URL, didAccessSecurityScope: Bool)? {
        if let bookmarkData = track.securityScopedBookmarkData {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                let didAccess = resolvedURL.startAccessingSecurityScopedResource()
                if didAccess, FileManager.default.fileExists(atPath: resolvedURL.path) {
                    return (resolvedURL.standardizedFileURL, true)
                }
                if didAccess {
                    resolvedURL.stopAccessingSecurityScopedResource()
                }
            } catch {
                // Fall back to the saved file URL when the bookmark can no longer resolve.
            }
        }

        guard let sourceFileURL = track.sourceFileURL?.standardizedFileURL,
              FileManager.default.fileExists(atPath: sourceFileURL.path) else {
            return nil
        }

        return (sourceFileURL, false)
    }

    private func removeObservation(for trackID: UUID) {
        pendingRetryTrackIDs.remove(trackID)
        guard let observation = observationsByTrackID.removeValue(forKey: trackID) else {
            return
        }

        observation.source.cancel()
    }

    private func scheduleObservationRetry(
        for track: Track,
        onChange: @escaping @MainActor (TrackFileMonitorEvent) -> Void
    ) {
        guard pendingRetryTrackIDs.insert(track.id).inserted else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.pendingRetryTrackIDs.remove(track.id)
            guard self.observationsByTrackID[track.id] == nil else {
                return
            }

            guard track.sourceFileURL != nil,
                  let observation = self.makeObservation(for: track, onChange: onChange) else {
                return
            }

            self.observationsByTrackID[track.id] = observation
            observation.source.resume()
        }
    }

    nonisolated static func monitoredURL(for fileURL: URL) -> URL {
        fileURL
    }

    private nonisolated static func monitoredPath(for fileURL: URL) -> String {
        monitoredURL(for: fileURL).path
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
