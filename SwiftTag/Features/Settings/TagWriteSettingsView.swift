import SwiftUI

struct TagWriteSettingsView: View {
    @AppStorage(SaveSettingsKey.zeroPadTrackNumber) private var zeroPadTrackNumber: Bool = SaveSettingsDefaults.zeroPadTrackNumber
    @AppStorage(SaveSettingsKey.trackCountKeyStrategy) private var trackCountKeyStrategyRawValue: String = SaveSettingsDefaults.trackCountKeyStrategy.rawValue
    @AppStorage(SaveSettingsKey.zeroPadDiscNumber) private var zeroPadDiscNumber: Bool = SaveSettingsDefaults.zeroPadDiscNumber
    @AppStorage(SaveSettingsKey.discCountKeyStrategy) private var discCountKeyStrategyRawValue: String = SaveSettingsDefaults.discCountKeyStrategy.rawValue
    @AppStorage(SaveSettingsKey.autoUpdateTrackTotal) private var autoUpdateTrackTotal: Bool = SaveSettingsDefaults.autoUpdateTrackTotal
    @AppStorage(SaveSettingsKey.updateTrackTotalOnLockedTracks) private var updateTrackTotalOnLockedTracks: Bool = SaveSettingsDefaults.updateTrackTotalOnLockedTracks
    @AppStorage(SaveSettingsKey.saveFrontCoverToAllTracks) private var saveFrontCoverToAllTracks: Bool = SaveSettingsDefaults.saveFrontCoverToAllTracks
    @AppStorage(SaveSettingsKey.saveAllPicturesToAllTracks) private var saveAllPicturesToAllTracks: Bool = SaveSettingsDefaults.saveAllPicturesToAllTracks

    private var trackCountKeyStrategy: Binding<TrackCountKeyStrategy> {
        Binding(
            get: { TrackCountKeyStrategy(rawValue: trackCountKeyStrategyRawValue) ?? SaveSettingsDefaults.trackCountKeyStrategy },
            set: { trackCountKeyStrategyRawValue = $0.rawValue }
        )
    }

    private var discCountKeyStrategy: Binding<DiscCountKeyStrategy> {
        Binding(
            get: { DiscCountKeyStrategy(rawValue: discCountKeyStrategyRawValue) ?? SaveSettingsDefaults.discCountKeyStrategy },
            set: { discCountKeyStrategyRawValue = $0.rawValue }
        )
    }

    private var writeTotalTracksKey: Binding<Bool> {
        Binding(
            get: {
                switch trackCountKeyStrategy.wrappedValue {
                case .totalTracks, .both:
                    return true
                case .trackTotal, .none:
                    return false
                }
            },
            set: { isOn in
                let writesTrackTotalKey = writeTrackTotalKey.wrappedValue
                trackCountKeyStrategy.wrappedValue = strategyForTrackCountKeys(
                    writesTotalTracksKey: isOn,
                    writesTrackTotalKey: writesTrackTotalKey
                )
            }
        )
    }

    private var writeTrackTotalKey: Binding<Bool> {
        Binding(
            get: {
                switch trackCountKeyStrategy.wrappedValue {
                case .trackTotal, .both:
                    return true
                case .totalTracks, .none:
                    return false
                }
            },
            set: { isOn in
                let writesTotalTracksKey = writeTotalTracksKey.wrappedValue
                trackCountKeyStrategy.wrappedValue = strategyForTrackCountKeys(
                    writesTotalTracksKey: writesTotalTracksKey,
                    writesTrackTotalKey: isOn
                )
            }
        )
    }

    private var writeTotalDiscsKey: Binding<Bool> {
        Binding(
            get: {
                switch discCountKeyStrategy.wrappedValue {
                case .totalDiscs, .both:
                    return true
                case .discTotal, .none:
                    return false
                }
            },
            set: { isOn in
                let writesDiscTotalKey = writeDiscTotalKey.wrappedValue
                discCountKeyStrategy.wrappedValue = strategyForDiscCountKeys(
                    writesTotalDiscsKey: isOn,
                    writesDiscTotalKey: writesDiscTotalKey
                )
            }
        )
    }

    private var writeDiscTotalKey: Binding<Bool> {
        Binding(
            get: {
                switch discCountKeyStrategy.wrappedValue {
                case .discTotal, .both:
                    return true
                case .totalDiscs, .none:
                    return false
                }
            },
            set: { isOn in
                let writesTotalDiscsKey = writeTotalDiscsKey.wrappedValue
                discCountKeyStrategy.wrappedValue = strategyForDiscCountKeys(
                    writesTotalDiscsKey: writesTotalDiscsKey,
                    writesDiscTotalKey: isOn
                )
            }
        )
    }

    var body: some View {
        Form {
            Toggle("Zero pad Track Number/Total", isOn: $zeroPadTrackNumber)
                .accessibilityIdentifier("settings.tags.zeroPadTrackNumber")
                .accessibilityValue(zeroPadTrackNumber ? "On" : "Off")
            
            Toggle("Zero pad Disc Number/Total", isOn: $zeroPadDiscNumber)
                .accessibilityIdentifier("settings.tags.zeroPadDiscNumber")
                .accessibilityValue(zeroPadDiscNumber ? "On" : "Off")

            Toggle("Auto update Track Total", isOn: $autoUpdateTrackTotal)
                .accessibilityIdentifier("settings.tags.autoUpdateTrackTotal")
                .accessibilityValue(autoUpdateTrackTotal ? "On" : "Off")

            Toggle("Update Track Total on Locked Tracks", isOn: $updateTrackTotalOnLockedTracks)
                .accessibilityIdentifier("settings.tags.updateTrackTotalOnLockedTracks")
                .accessibilityValue(updateTrackTotalOnLockedTracks ? "On" : "Off")

            LabeledContent("Write Track Total key") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("TOTALTRACKS", isOn: writeTotalTracksKey)
                        .accessibilityIdentifier("settings.tags.trackCountKey.totalTracks")
                    Toggle("TRACKTOTAL", isOn: writeTrackTotalKey)
                        .accessibilityIdentifier("settings.tags.trackCountKey.trackTotal")
                }
                .toggleStyle(.switch)
            }
            .accessibilityIdentifier("settings.tags.trackCountKeyStrategy")

            LabeledContent("Write Disc Total key") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("TOTALDISCS", isOn: writeTotalDiscsKey)
                        .accessibilityIdentifier("settings.tags.discCountKey.totalDiscs")
                    Toggle("DISCTOTAL", isOn: writeDiscTotalKey)
                        .accessibilityIdentifier("settings.tags.discCountKey.discTotal")
                }
                .toggleStyle(.switch)
            }
            .accessibilityIdentifier("settings.tags.discCountKeyStrategy")

            Toggle("Save Front Cover to all Tracks", isOn: $saveFrontCoverToAllTracks)
                .accessibilityIdentifier("settings.tags.saveFrontCoverToAllTracks")
                .accessibilityValue(saveFrontCoverToAllTracks ? "On" : "Off")

            Toggle("Save all Pictures to all Tracks", isOn: $saveAllPicturesToAllTracks)
                .accessibilityIdentifier("settings.tags.saveAllPicturesToAllTracks")
                .accessibilityValue(saveAllPicturesToAllTracks ? "On" : "Off")
        }
        .formStyle(.grouped)
    }

    private func strategyForTrackCountKeys(
        writesTotalTracksKey: Bool,
        writesTrackTotalKey: Bool
    ) -> TrackCountKeyStrategy {
        switch (writesTotalTracksKey, writesTrackTotalKey) {
        case (true, true):
            return .both
        case (true, false):
            return .totalTracks
        case (false, true):
            return .trackTotal
        case (false, false):
            return .none
        }
    }

    private func strategyForDiscCountKeys(
        writesTotalDiscsKey: Bool,
        writesDiscTotalKey: Bool
    ) -> DiscCountKeyStrategy {
        switch (writesTotalDiscsKey, writesDiscTotalKey) {
        case (true, true):
            return .both
        case (true, false):
            return .totalDiscs
        case (false, true):
            return .discTotal
        case (false, false):
            return .none
        }
    }
}
