import Foundation

struct FlacPictureDescriptionValidation: Equatable {
    let maximumDescriptionBytes: Int
    let proposedDescriptionBytes: Int

    var isValid: Bool {
        proposedDescriptionBytes <= maximumDescriptionBytes
    }
}

struct FlacPictureDataValidation: Equatable {
    let maximumPictureBytes: Int
    let proposedPictureBytes: Int

    var isValid: Bool {
        proposedPictureBytes <= maximumPictureBytes
    }
}

enum FlacPictureDescriptionBudget {
    static let metadataPayloadMaxBytes = (1 << 24) - 1
    static let fixedMetadataFieldBytes = 32
    static let safetyBufferBytes = 256
    static let editDescriptionBufferBytes = 256

    static func validation(
        mimeType: String,
        pictureData: Data,
        proposedDescription: String
    ) -> FlacPictureDescriptionValidation {
        let availableDescriptionBytes = metadataPayloadMaxBytes
            - fixedMetadataFieldBytes
            - safetyBufferBytes
            - mimeType.lengthOfBytes(using: .utf8)
            - pictureData.count

        return FlacPictureDescriptionValidation(
            maximumDescriptionBytes: max(0, availableDescriptionBytes),
            proposedDescriptionBytes: proposedDescription.lengthOfBytes(using: .utf8)
        )
    }
}

enum FlacPictureDataBudget {
    
    
    static func validation(
        mimeType: String,
        currentDescription: String,
        proposedPictureData: Data
    ) -> FlacPictureDataValidation {
        let availablePictureBytes = FlacPictureDescriptionBudget.metadataPayloadMaxBytes
            - FlacPictureDescriptionBudget.fixedMetadataFieldBytes
            - FlacPictureDescriptionBudget.safetyBufferBytes
            - FlacPictureDescriptionBudget.editDescriptionBufferBytes
            - mimeType.lengthOfBytes(using: .utf8)
            - currentDescription.lengthOfBytes(using: .utf8)

        return FlacPictureDataValidation(
            maximumPictureBytes: max(0, availablePictureBytes),
            proposedPictureBytes: proposedPictureData.count
        )
    }
}

extension FlacWritablePictureRecord {
    func withComputedPictureMetadata() -> FlacWritablePictureRecord {
        let specifications = PictureDataUtilities.computedSpecifications(from: data)
        return FlacWritablePictureRecord(
            type: type,
            mimeType: PictureDataUtilities.normalizedMimeType(mimeType: mimeType, data: data),
            description: description,
            data: data,
            width: specifications.width,
            height: specifications.height,
            depth: specifications.depth,
            colors: specifications.colors
        )
    }
}

enum PictureRecordCanonicalizer {
    static func canonicalize(
        _ pictures: [FlacWritablePictureRecord],
        normalizeImageMetadata: Bool = true
    ) -> [FlacWritablePictureRecord] {
        let normalizedPictures = normalizeImageMetadata
            ? pictures.map { $0.withComputedPictureMetadata() }
            : pictures

        return normalizedPictures.sorted { lhs, rhs in
            if lhs.type != rhs.type {
                return lhs.type < rhs.type
            }

            let lhsHash = PictureDataUtilities.sha256Hex(of: lhs.data)
            let rhsHash = PictureDataUtilities.sha256Hex(of: rhs.data)
            if lhsHash != rhsHash {
                return lhsHash < rhsHash
            }

            if lhs.mimeType != rhs.mimeType {
                return lhs.mimeType < rhs.mimeType
            }

            if lhs.description != rhs.description {
                return lhs.description < rhs.description
            }

            if lhs.width != rhs.width {
                return lhs.width < rhs.width
            }

            if lhs.height != rhs.height {
                return lhs.height < rhs.height
            }

            if lhs.depth != rhs.depth {
                return lhs.depth < rhs.depth
            }

            return lhs.colors < rhs.colors
        }
    }
}
