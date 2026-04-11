import Foundation

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
