import SwiftUI

struct TagDiffPresentation: Equatable {
    let foregroundColor: Color
    let backgroundColor: Color?
    let isBold: Bool
    let isItalic: Bool

    static func resolve(
        tag: DiffTagIdentifier,
        hasTrackToTrackDifference: Bool,
        hasTrackToFileDifference: Bool,
        hasExternallyModifiedDifference: Bool,
        showsMismatchWarning: Bool,
        isInvalid: Bool,
        trackToTrackColor: Color,
        trackToFileColor: Color,
        externallyModifiedColor: Color,
        mismatchColor: Color,
        formatOnTrackToFileDiff: Bool,
        formatOnTrackToTrackDiff: Bool,
        formatOnExternallyModifiedDiff: Bool
    ) -> TagDiffPresentation {
        let showsExternallyModified = hasExternallyModifiedDifference && formatOnExternallyModifiedDiff
        let showsTrackToFile = hasTrackToFileDifference && formatOnTrackToFileDiff && !showsExternallyModified
        let showsTrackToTrack = hasTrackToTrackDifference && formatOnTrackToTrackDiff && !showsExternallyModified && !showsTrackToFile

        return TagDiffPresentation(
            foregroundColor: {
                if isInvalid {
                    return .red
                }
                if showsMismatchWarning {
                    return mismatchColor
                }
                if showsExternallyModified {
                    return externallyModifiedColor
                }
                if showsTrackToFile {
                    return trackToFileColor
                }
                if showsTrackToTrack {
                    return trackToTrackColor
                }
                return .primary
            }(),
            backgroundColor: {
                if showsMismatchWarning {
                    return mismatchColor
                }
                if showsTrackToTrack {
                    return trackToTrackColor
                }
                return nil
            }(),
            isBold: showsExternallyModified || showsTrackToFile,
            isItalic: showsExternallyModified
        )
    }
}

struct TagDiffStyleModifier: ViewModifier {
    @AppStorage(FeedbackSettingsKey.trackToTrackDiffColor)
    private var trackToTrackDiffColorRawValue: String = FeedbackSettingsDefaults.trackToTrackDiffColor

    @AppStorage(FeedbackSettingsKey.trackToFileDiffColor)
    private var trackToFileDiffColorRawValue: String = FeedbackSettingsDefaults.trackToFileDiffColor

    @AppStorage(FeedbackSettingsKey.externallyModifiedDiffColor)
    private var externallyModifiedDiffColorRawValue: String = FeedbackSettingsDefaults.externallyModifiedDiffColor

    @AppStorage(FeedbackSettingsKey.trackDiscTotalMismatchColor)
    private var trackDiscTotalMismatchColorRawValue: String = FeedbackSettingsDefaults.trackDiscTotalMismatchColor

    @AppStorage(FeedbackSettingsKey.formatOnTrackToFileDiff)
    private var formatOnTrackToFileDiff: Bool = FeedbackSettingsDefaults.formatOnTrackToFileDiff

    @AppStorage(FeedbackSettingsKey.formatOnTrackToTrackDiff)
    private var formatOnTrackToTrackDiff: Bool = FeedbackSettingsDefaults.formatOnTrackToTrackDiff

    @AppStorage(FeedbackSettingsKey.formatOnExternallyModifiedDiff)
    private var formatOnExternallyModifiedDiff: Bool = FeedbackSettingsDefaults.formatOnExternallyModifiedDiff

    let tag: DiffTagIdentifier
    let hasTrackToTrackDifference: Bool
    let hasTrackToFileDifference: Bool
    let hasExternallyModifiedDifference: Bool
    let showsMismatchWarning: Bool
    let isInvalid: Bool

    private var presentation: TagDiffPresentation {
        TagDiffPresentation.resolve(
            tag: tag,
            hasTrackToTrackDifference: hasTrackToTrackDifference,
            hasTrackToFileDifference: hasTrackToFileDifference,
            hasExternallyModifiedDifference: hasExternallyModifiedDifference,
            showsMismatchWarning: showsMismatchWarning,
            isInvalid: isInvalid,
            trackToTrackColor: AppColorStorage.color(from: trackToTrackDiffColorRawValue, fallback: .systemOrange),
            trackToFileColor: AppColorStorage.color(from: trackToFileDiffColorRawValue, fallback: .labelColor),
            externallyModifiedColor: AppColorStorage.color(from: externallyModifiedDiffColorRawValue, fallback: .systemRed),
            mismatchColor: AppColorStorage.color(from: trackDiscTotalMismatchColorRawValue, fallback: .systemRed),
            formatOnTrackToFileDiff: formatOnTrackToFileDiff,
            formatOnTrackToTrackDiff: formatOnTrackToTrackDiff,
            formatOnExternallyModifiedDiff: formatOnExternallyModifiedDiff
        )
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .foregroundStyle(presentation.foregroundColor)
            .background(presentation.backgroundColor?.opacity(0.35))
            .fontWeight(presentation.isBold ? .bold : .regular)
            .italic(presentation.isItalic)
    }
}

extension View {
    func tagDiffStyle(
        tag: DiffTagIdentifier,
        hasTrackToTrackDifference: Bool = false,
        hasTrackToFileDifference: Bool = false,
        hasExternallyModifiedDifference: Bool = false,
        showsMismatchWarning: Bool = false,
        isInvalid: Bool = false
    ) -> some View {
        modifier(
            TagDiffStyleModifier(
                tag: tag,
                hasTrackToTrackDifference: hasTrackToTrackDifference,
                hasTrackToFileDifference: hasTrackToFileDifference,
                hasExternallyModifiedDifference: hasExternallyModifiedDifference,
                showsMismatchWarning: showsMismatchWarning,
                isInvalid: isInvalid
            )
        )
    }
}
