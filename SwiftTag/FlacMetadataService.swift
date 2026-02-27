import Foundation

enum FlacMetadataServiceError: LocalizedError {
    case bundledToolMissing
    case launchFailed(filePath: String, reason: String)
    case commandFailed(filePath: String, status: Int32, stderr: String)
    case invalidOutput(filePath: String)

    var errorDescription: String? {
        switch self {
        case .bundledToolMissing:
            return "Bundled metaflac not found in app resources."
        case let .launchFailed(filePath, reason):
            return "Failed to start metaflac for \(filePath): \(reason)"
        case let .commandFailed(filePath, status, stderr):
            return "metaflac failed for \(filePath) with exit code \(status).\n\n\(stderr)"
        case let .invalidOutput(filePath):
            return "metaflac returned unreadable output for \(filePath)."
        }
    }
}

struct FlacMetadataRecord {
    let tags: [String: String]
}

enum FlacMetadataService {
    static func readTags(for fileURL: URL) throws -> FlacMetadataRecord {
        guard let metaflacPath = bundledToolPath(named: "metaflac") else {
            throw FlacMetadataServiceError.bundledToolMissing
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: metaflacPath)
        process.arguments = ["--show-all-tags", fileURL.path]
        print("Running command: \(metaflacPath) \((process.arguments ?? []).joined(separator: " "))")

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw FlacMetadataServiceError.launchFailed(filePath: fileURL.path, reason: error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw FlacMetadataServiceError.commandFailed(
                filePath: fileURL.path,
                status: process.terminationStatus,
                stderr: errorText
            )
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let outputText = String(data: outputData, encoding: .utf8) else {
            throw FlacMetadataServiceError.invalidOutput(filePath: fileURL.path)
        }

        var tags: [String: String] = [:]
        for line in outputText.split(separator: "\n") {
            guard let equalsIndex = line.firstIndex(of: "=") else {
                continue
            }

            let key = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let value = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                tags[key] = value
            }
        }

        return FlacMetadataRecord(tags: tags)
    }

    private static func bundledToolPath(named toolName: String) -> String? {
        let fileManager = FileManager.default
        let candidates = [
            Bundle.main.url(forResource: toolName, withExtension: nil, subdirectory: "bin"),
            Bundle.main.url(forResource: toolName, withExtension: nil)
        ]

        for case let url? in candidates where fileManager.isExecutableFile(atPath: url.path) {
            return url.path
        }

        return nil
    }
}
