import Foundation

enum FlacMetadataServiceError: LocalizedError {
    case bridgeFailed(message: String)

    var errorDescription: String? {
        switch self {
        case let .bridgeFailed(message):
            return message
        }
    }
}

struct FlacMetadataRecord {
    let tags: [String: String]
}

enum FlacMetadataService {
    static func readTags(for fileURL: URL) throws -> FlacMetadataRecord {
        var result = FlacTagResult(pairs: nil, count: 0)
        var errorMessage: UnsafeMutablePointer<CChar>? = nil

        let status: Int32 = fileURL.path.withCString { filePath in
            flac_read_tags(filePath, &result, &errorMessage)
        }

        defer {
            flac_free_tag_result(&result)
            if let errorMessage {
                flac_free_c_string(errorMessage)
            }
        }

        guard status == 0 else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown FLAC metadata bridge error."
            throw FlacMetadataServiceError.bridgeFailed(message: message)
        }

        var tags: [String: String] = [:]
        if let pairs = result.pairs {
            for index in 0 ..< Int(result.count) {
                let pair = pairs.advanced(by: index).pointee
                guard let keyC = pair.key, let valueC = pair.value else {
                    continue
                }

                let key = String(cString: keyC).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let value = String(cString: valueC).trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    tags[key] = value
                }
            }
        }

        return FlacMetadataRecord(tags: tags)
    }
}
