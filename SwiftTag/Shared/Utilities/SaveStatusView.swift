import Foundation
import SwiftUI

struct SaveStatusPresentation: Equatable {
    var album: String
    var currentTrackName: String
    var showsSelectedTrackName: Bool
    var currentTrackIndex: Int
    var totalTrackCount: Int
}

struct SaveStatusState: Equatable {
    let startedAt: Date
    var presentation: SaveStatusPresentation
}

enum SaveStatusTiming {
    static let minimumDisplayDuration: TimeInterval = 1.5
    static let fadeDuration: TimeInterval = 0.25

    static var fadeAnimation: Animation {
        .easeInOut(duration: fadeDuration)
    }

    static var fadeDurationNanoseconds: UInt64 {
        nanoseconds(for: fadeDuration)
    }

    static func remainingDisplayDuration(
        startedAt: Date,
        endedAt: Date = .now,
        minimumDisplayDuration: TimeInterval = minimumDisplayDuration
    ) -> TimeInterval {
        max(0, minimumDisplayDuration - endedAt.timeIntervalSince(startedAt))
    }

    static func nanoseconds(for interval: TimeInterval) -> UInt64 {
        UInt64(max(0, interval) * 1_000_000_000)
    }
}

struct SaveStatusView: View {
    @Environment(\.colorScheme) private var colorScheme

    let presentation: SaveStatusPresentation

    private var statusLabelText: String {
        if presentation.showsSelectedTrackName {
            return "Saving Track:"
        }

        return "Saving Album:"
    }

    private var statusValueText: String {
        if presentation.showsSelectedTrackName {
            return presentation.currentTrackName
        }

        return presentation.album
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .blur(radius: 8)

            Image("Brightly_Colored_Fish-512-circle-alpha-full")
                .resizable()
                .scaledToFit()
                .frame(width: 512, height: 512)
                .offset(x: 0, y: -5)

            HStack(spacing: 0) {
                readOnlyField(
                    statusLabelText,
                    width: 96,
                )

                readOnlyField(
                    statusValueText,
                    leadingPadding: 4
                )

                Spacer(minLength: 4)

                readOnlyField(
                    String(format: "%2d", presentation.currentTrackIndex),
                    textAlignment: .trailing,
                    width: 30,
                    monospaced: true,
                    trailingPadding: 2
                )

                readOnlyField(
                    "of",
                    textAlignment: .center,
                    width: 20
                )

                readOnlyField(
                    String(format: "%2d", presentation.totalTrackCount),
                    textAlignment: .leading,
                    width: 30,
                    monospaced: true,
                    leadingPadding: 2
                )
            }
            .padding(EdgeInsets(top: 0, leading: 12, bottom: 4, trailing:12))
        }
        .frame(width: 512, height: 512)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("saveStatusView")
    }

    private func readOnlyField(
        _ text: String,
        textAlignment: TextAlignment = .leading,
        width: CGFloat? = nil,
        monospaced: Bool = false,
        leadingPadding: CGFloat = 0,
        trailingPadding: CGFloat = 0,
        fixedSize: Bool = false
    ) -> some View {
        Text(text)
            .font(monospaced ? .system(.body, design: .monospaced).weight(.bold) : .body.weight(.bold))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .padding(.vertical, 6)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: frameAlignment(for: textAlignment))
            .frame(width: width)
            .fixedSize(horizontal: fixedSize, vertical: false)
    }

    private func frameAlignment(for alignment: TextAlignment) -> Alignment {
        switch alignment {
        case .center:
            return .center
        case .trailing:
            return .trailing
        default:
            return .leading
        }
    }
}
