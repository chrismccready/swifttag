# Add UI Feedback Settings Plan

## Goal
Add user-configurable feedback settings for save notifications, app theme, and diff styling; migrate `album`, `albumArtist`, and `totalTracks` from editor-wide state into per-track state; and introduce a `Diff Tools` utility window that controls mismatch warnings and diff emphasis behavior with updated formatting rules for internal/external differences.

## Scope
In scope:
- Move `album`, `albumArtist`, and `totalTracks` data ownership from editor-global state to `Track`.
- Replace the read-only `totalTracks` text in `TagEditorCoreTagsView` with an editable `TextField`.
- Make `totalTracks` mismatch styling use a red background warning when enabled, with default foreground text color.
- Add a `Feedback` tab to `SettingsView` after `Tags`.
- Add `@AppStorage`-backed settings for save notification behavior, theme, internal diff color, and external diff color.
- Apply the saved theme setting through `ContentView.preferredColorScheme(...)`.
- Centralize tag-editor diff styling so internal and external differences can use user-configurable colors and emphasis.
- Add a `Diff Tools` utility window with a top-level `Warn On Track Total Mismatch` toggle that controls the red mismatch background on total tracks.
- Update external-difference formatting so editor values that differ from associated file values (except when the associated file value is empty) render as bold text with default foreground color instead of diff-color text.
- Update internal-difference formatting to use background highlighting with the internal diff color instead of italics.
- Suppress internal-difference formatting when exactly one track is selected.
- Update save-notification scheduling logic to honor the new feedback setting.
- Add targeted tests for the new state-mapping, settings persistence, diff-style decisions, and write-mapping behavior.

Out of scope:
- Changing FLAC bridge behavior or file format support.
- Changing filename-column strike/red behavior for deleted files.
- Reworking album-art diff detection rules beyond consuming the new feedback settings where applicable.
- Replacing existing save settings tabs or save command semantics.
- Adding a generalized preferences storage abstraction unless the implementation proves duplication is otherwise unmanageable.

## Dependencies And Constraints
- Current global album metadata lives in [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift), while per-track editable metadata lives in `Track.tags`; the plan must avoid leaving duplicate sources of truth.
- `Track` currently does not store dedicated `album`, `albumArtist`, or `totalTracks` properties in [Track.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Shared/Models/Track.swift), so model migration affects import, editing, save mapping, TOML generation, and diff detection.
- `FlacImportMapper.initialValues(...)` currently seeds shared editor-wide values from only the first imported file in [FlacImportMapper.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/FlacImport/FlacImportMapper.swift); that behavior must be replaced or narrowed once album metadata becomes per-track.
- `FlacWriteMapper.makeTags(...)` currently writes one shared `album`, `albumArtist`, and track-count value into every output file in [FlacWriteMapper.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/FlacImport/FlacWriteMapper.swift); writeback needs to switch to per-track values without regressing existing tag-write options.
- Diff styling is currently duplicated in [TagEditorAlbumView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorAlbumView.swift), [TagEditorCoreTagsView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorCoreTagsView.swift), and [TagEditorMiscTagsView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorMiscTagsView.swift), mostly with hard-coded red + italic rules. That should be centralized before adding user-configurable styling.
- `SettingsView` currently has only `General` and `Tags` tabs in [SettingsView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/Settings/SettingsView.swift).
- The app scene graph currently defines the editor window group and Settings scene only in [SwiftTagApp.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/SwiftTagApp.swift); the new utility window will need scene registration plus a discoverable open path.
- Save notifications are scheduled through [SaveNotificationCoordinator.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Shared/Utilities/SaveNotificationCoordinator.swift), and foreground presentation is currently unconditional in `AppDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:)`.
- The task changes writeback behavior for `ALBUM`, `ALBUMARTIST`, `TOTALTRACKS`, and `TRACKTOTAL`, so fixture-backed tests should use copied FLAC fixtures from [test.flac](/Users/ccm/Dev/Swift/SwiftTag/SwiftTagTestFiles/test.flac) and [test-with_padding.flac](/Users/ccm/Dev/Swift/SwiftTag/SwiftTagTestFiles/test-with_padding.flac).

## Confirmed Decisions
- `Feedback` is a new Settings tab positioned after `Tags`.
- `Send Save Notifications` is a segmented picker with `Always`, `When Not Frontmost`, and `Never`, defaulting to `When Not Frontmost`, persisted via `@AppStorage`.
- `When Not Frontmost` means notifications are sent only when the app is not frontmost.
- `Theme` is a segmented picker with `System`, `Light`, and `Dark`, defaulting to `System`, persisted via `@AppStorage`.
- `Internal Diff Color` defaults to orange and is persisted via `@AppStorage`.
- `External Diff Color` defaults to red and is persisted via `@AppStorage`.
- `Bold On File Diff` defaults to `true` and is persisted via `@AppStorage`.
- `Warn On Track Total Mismatch` defaults to `true`, appears at the top of the Diff Tools form, and is persisted via `@AppStorage`.
- When `Warn On Track Total Mismatch` is `off`, the total-tracks red mismatch background is not shown.
- `Warn On Disc Total Mismatch` defaults to `true`, appears directly below `Warn On Track Total Mismatch` in Diff Tools, and is persisted via `@AppStorage`.
- When `Warn On Disc Total Mismatch` is `off`, the total-discs red mismatch background is not shown.
- External file differences in editor fields should render as bold and use `Track to File Diff Color` (defaulting to default text color), not a hard-coded foreground color.
- External file difference styling should only apply when the associated file has a non-empty value for that tag.
- Internal differences should render with a background highlight using the internal diff color, not italic text.
- Internal track-to-track differences should render when two or more tracks are selected; single-track selection does not render track-to-track diff styling.
- When a track-to-track differing field shows `*`, background highlight should still be applied.
- Externally modified diff styling overrides track-to-file and track-to-track styles when multiple diff states exist.
- Externally modified diff formatting clears for a tag across all selected tracks updated by a user edit to that tag field.
- The filename column’s current external-difference strikethrough behavior must not change.
- `totalTracks` should become user-editable instead of being rendered as read-only text.
- `album`, `albumArtist`, and `totalTracks` should be able to differ between tracks.
- The top editor controls for `album`, `albumArtist`, and `totalTracks` should edit only the selected tracks.
- When selected tracks have mixed values for those controls, the UI should show a bold `*`.
- Source track files that have no value for a given tag are not considered different for formatting purposes.
- Apple’s `UtilityWindow` behavior should be used as designed: it automatically adds a show/hide item in the `View` menu unless `.commandsRemoved()` is applied.
- When a field has both an internal diff and an external diff at the same time, external diff formatting takes precedence.

## Destructive / Write-Back Behavior
- Preserved data:
  - Existing unrelated FLAC tag values continue to round-trip through `mergeNonEmptyTags(...)`.
  - Existing picture write behavior and save-payload selection stay intact.
  - Filename-column delete styling and current external-difference detection rules remain the source of truth for external file changes.
- Replaced data:
  - `ALBUM` and `ALBUMARTIST` will be written from per-track values instead of shared editor-wide values.
  - `TOTALTRACKS` and `TRACKTOTAL` will be written from each track’s stored `totalTracks` value instead of the loaded track count.
- Removed data:
  - The editor-wide `album` and `albumArtist` properties in `TagEditorViewModel` should be removed once all call sites are migrated.
  - The computed `totalTracks == String(trackItems.count)` source of truth should be removed once per-track storage is established.
- Partial-save behavior:
  - `Save Tags...` continues to update only tag metadata, but now uses each selected track’s own `album`, `albumArtist`, and `totalTracks` values.
  - `Save Pictures...` should not alter per-track textual metadata.
  - `Save` continues to follow existing payload settings, now against the new per-track metadata model.
- Selection semantics that implementation must preserve unless clarified otherwise:
  - The track-table selection remains the current source of truth for selection-based metadata editing.
  - Locked/read-only tracks should still resist mutation through any new bindings.

## High-Risk Concerns

### Product Or Behavioral Risks
- If internal and external diff styling rules are layered ad hoc, the same control can receive conflicting color and emphasis rules with no stable precedence.
- If mismatch warning state and total-tracks external/internal diff state are combined without clear precedence, the total-tracks warning can become unreadable or inconsistent.
- If save notifications suppress or present in the wrong foreground/background state, the new settings will appear inverted and undermine user trust.
- If the `Diff Tools` per-tag toggles are keyed off display labels instead of stable tag identifiers, settings persistence will be brittle and harder to evolve.

### Tooling, Environment, Or Filesystem Risks
- `ColorPicker` with `@AppStorage` requires a stable serialization format because `Color` itself is not directly storable in `UserDefaults` in a durable, cross-launch way without an adapter.
- SwiftUI `UtilityWindow`/window-scene behavior on macOS needs verification in the current SDK; the open path should avoid brittle responder-chain assumptions.
- ViewInspector coverage for `Table`-based editors and color/emphasis modifiers can be limited, so tests should emphasize style-decision helpers and binding behavior rather than full view-tree snapshots.
- FLAC writeback verification should use copied fixtures, since direct mutation of checked-in fixtures would be destructive.

## Implementation Phases

### 1. Define feedback-setting models and keys
- Add stable enums or raw-value wrappers for:
  - save notification mode
  - theme mode
  - diff emphasis options and mismatch warning options
- Extend [SaveSettings.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Shared/Models/SaveSettings.swift) or add a dedicated feedback-settings model file for new `@AppStorage` keys and defaults.
- Introduce a small color-storage adapter so `Internal Diff Color` and `External Diff Color` can round-trip through `UserDefaults`.
- Define one central source of truth for diff-style decisions, for example a `TagDiffStyleSettings` / `TagDiffPresentation` helper.

### 2. Move album metadata and total-tracks ownership onto `Track`
- Extend [Track.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Shared/Models/Track.swift) with dedicated per-track properties for `album`, `albumArtist`, and `totalTracks`, or an equivalent per-track metadata container.
- Update FLAC import mapping so each imported `Track` receives its own values from source tags instead of seeding only editor-global properties.
- Update editor bindings in [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift) and [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift) to edit/read those values through track-based selection bindings.
- Remove the obsolete global `album`, `albumArtist`, and computed `totalTracks` source of truth once all downstream consumers are migrated.
- Update TOML generation to reflect the new storage model or explicitly preserve an aggregate representation if that remains desired.

### 3. Rework selection bindings for track-varying album fields
- Replace the current editor-wide `albumBinding` and `albumArtistBinding` with selection-aware bindings that:
  - return the shared value when selected tracks match
  - return a bold `*` when selected tracks differ
  - write the edited value back to all selected unlocked tracks
- Add the equivalent binding for editable `totalTracks`.
- Keep no-selection behavior consistent with the rest of the editor by disabling controls and using placeholder text where appropriate.
- Ensure locked tracks remain non-editable and are skipped during bulk edits.

### 4. Make `totalTracks` editable and preserve mismatch feedback
- Update [TagEditorCoreTagsView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorCoreTagsView.swift) so `totalTracks` uses a `TextField` rather than `Text`.
- Rework mismatch logic so it compares the edited/stored `totalTracks` value against `trackItems.count`.
- Rework mismatch presentation so total tracks uses a red background warning (with default text color) when mismatch exists and warning is enabled.
- Decide and implement how mismatch interacts with internal and external diff presentation in one centralized style rule.

### 5. Update FLAC write mapping and diff detection for per-track values
- Update [FlacWriteMapper.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/FlacImport/FlacWriteMapper.swift) to write `ALBUM`, `ALBUMARTIST`, `TOTALTRACKS`, and `TRACKTOTAL` from the track being saved.
- Update any view-model save-preview or diff helper logic that still injects shared `album`, `albumArtist`, or loaded-track-count values.
- Ensure external-difference detection compares the current per-track values against the latest file snapshot for those keys.
- Treat missing source-file values as non-differences for formatting purposes when the file has no value for the relevant tag.
- Keep tag-write option semantics intact:
  - `TrackCountKeyStrategy` still governs whether `TOTALTRACKS`, `TRACKTOTAL`, both, or neither are emitted.
  - zero-padding behavior still applies to stored per-track totals when numeric.

### 6. Add the Feedback settings UI
- Create a new `FeedbackSettingsView` and add it as the tab after `Tags` in [SettingsView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/Settings/SettingsView.swift).
- Add segmented pickers for notification mode and theme mode using `@AppStorage`.
- Add labeled color pickers for internal and external diff colors using the new color-storage adapter.
- Add accessibility identifiers for the new controls so targeted tests and future UI automation can reach them.

### 7. Apply theme and notification settings
- Read the theme setting in [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift) and apply `.preferredColorScheme(nil/.light/.dark)` from the persisted mode.
- Update save-notification presentation logic so:
  - `Always` allows notifications whenever existing save logic says a notification is applicable.
  - `When Not Frontmost` sends notifications only when the app is not frontmost.
  - `Never` suppresses notifications entirely.
- Ensure the same notification-mode logic covers both foreground presentation and background scheduling paths so behavior is consistent.

### 8. Centralize configurable diff styling
- Replace duplicated diff rules in tag-editing views with a shared modifier or presentation helper that keeps first-responder focus stable during edits.
- Model at least these states separately:
  - internal diff against another track or current editor mismatch
  - external diff against the associated file snapshot
  - mismatch-only state for `totalTracks`
  - invalid misc-tag key state, which should remain distinct from diff styling
- Encode precedence so each control can derive:
  - foreground color
  - background color
  - bold emphasis
- Apply the following formatting behavior:
  - external file diff with non-empty file value: bold + default foreground color (not diff-color text)
  - internal diff: internal diff color used for background highlight
  - single-track selection: internal diff formatting suppressed
  - total-tracks mismatch warning enabled: red background warning on total-tracks field
- Apply external diff precedence whenever both internal and external diff states are simultaneously true.
- Preserve the existing filename-column external styling rules outside that shared modifier when required by the task.

### 9. Add the `Diff Tools` utility window
- Create a dedicated view for the utility window controls.
- Register a new utility scene in [SwiftTagApp.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/SwiftTagApp.swift) for `Diff Tools`.
- Add `@AppStorage`-backed toggles for:
  - `Warn On Track Total Mismatch` (placed at the top of the form)
  - `Warn On Disc Total Mismatch` (placed immediately under track-total warning toggle)
  - `Bold On File Diff`
- Remove or retire per-tag italicization controls if they no longer apply after background-based internal diff formatting.
- Use stable tag identifiers, not view labels alone, for persistence keys.
- Migrate persisted keys for renamed settings even if it breaks previous defaults/values.
- Rely on SwiftUI `UtilityWindow` default behavior so the app gets a `View` menu show/hide item automatically unless a later change intentionally removes the commands.

### 10. Add targeted tests and verification
- Unit tests first:
  - per-track album/artist/total-tracks import mapping
  - selection-binding behavior for matching, mixed, locked, and empty selections
  - `FlacWriteMapper` writes per-track `ALBUM`, `ALBUMARTIST`, and track-count values correctly
  - color/background/emphasis presentation mapping for internal, external, and mismatch states
  - notification-mode gating for always / conditional / never
  - theme-mode mapping to preferred color scheme
  - mismatch-warning toggle behavior for both track and disc totals
  - externally-modified override precedence and clear-on-edit behavior
- Service/fixture tests next:
  - copied `test.flac` and `test-with_padding.flac` round-trip the migrated fields correctly without regressing zero-padding and tag-count strategy behavior
- Targeted SwiftUI/ViewInspector tests where practical:
  - `Feedback` tab exists after `Tags`
  - `totalTracks` renders as an editable text field
  - `Warn On Track Total Mismatch` appears at top of Diff Tools form and persists
  - `Warn On Disc Total Mismatch` appears below it and persists
  - settings views bind to persisted values correctly
- Compile verification:
  - `XcodeRefreshCodeIssuesInFile` on touched Swift files
  - `BuildProject`

## Suggested File Updates
- Update [Track.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Shared/Models/Track.swift)
- Update [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift)
- Update [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift)
- Update [TagEditorView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorView.swift)
- Update [TagEditorAlbumView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorAlbumView.swift)
- Update [TagEditorCoreTagsView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorCoreTagsView.swift)
- Update [TagEditorMiscTagsView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorMiscTagsView.swift)
- Update [FlacImportMapper.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/FlacImport/FlacImportMapper.swift)
- Update [FlacWriteMapper.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/FlacImport/FlacWriteMapper.swift)
- Update [SettingsView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/Settings/SettingsView.swift)
- Add `FeedbackSettingsView` under `Features/Settings`
- Add a feedback-settings model/helper file under `Shared/Models` or `Shared/Utilities`
- Add a diff-style presentation helper/modifier file under `Shared/Utilities` or `Features/TagEditor`
- Update [SaveNotificationCoordinator.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Shared/Utilities/SaveNotificationCoordinator.swift)
- Update [SwiftTagApp.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/SwiftTagApp.swift)
- Update or add focused tests under [SwiftTagTests.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTagTests/SwiftTagTests.swift) and related test files

## Test Strategy
- Follow the project harness order from [testing-guide.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/Guides/testing-guide.md):
  1. pure unit tests
  2. fixture-backed service/write tests
  3. targeted ViewInspector tests
  4. XCUI only if a utility-window open flow or scene interaction cannot be validated otherwise
- Prefer helper-level assertions for diff-style decisions rather than brittle modifier-tree inspection.
- Use copied FLAC fixtures for writeback tests so repository fixtures remain unchanged.
- Keep tests targeted to the migrated fields and new feedback settings; do not broaden into full-suite automation unless explicitly requested.

## Acceptance Criteria
- `album`, `albumArtist`, and `totalTracks` are stored per track and can differ between tracks.
- The editor no longer relies on a duplicate global source of truth for those fields.
- `totalTracks` is editable in the core tags section through a `TextField`.
- `totalTracks` shows a red background warning whenever mismatch exists and `Warn On Track Total Mismatch` is on.
- `totalTracks` does not show the mismatch background when `Warn On Track Total Mismatch` is off.
- `totalDiscs` shows a red background warning whenever mismatch exists and `Warn On Disc Total Mismatch` is on.
- `totalDiscs` does not show the mismatch background when `Warn On Disc Total Mismatch` is off.
- `totalDiscs` mismatch warning is true when either loaded/selected tracks disagree on total-discs values or any track has `discNumber > max(totalDiscs)` among tracks with a non-empty total-discs value.
- `Feedback` appears in Settings after `Tags`.
- `Send Save Notifications` persists and changes notification behavior according to the finalized frontmost/background rule.
- `Theme` persists and drives `.preferredColorScheme(nil/.light/.dark)` correctly.
- `Track to Track Diff Color` persists and is used for track-to-track background highlighting.
- `Track to File Diff Color` persists and is used for track-to-file diff foreground color, with default value equal to default text color.
- Externally modified differences use `Externally Modified Diff Color` and apply italic + bold + foreground color while the override is active.
- Existing external file-difference detection logic remains the source of truth for determining when external differences exist.
- When externally modified, track-to-file, and track-to-track states overlap, externally modified formatting wins.
- Filename-column delete strikethrough behavior is unchanged.
- `Diff Tools` exists as a utility window and persists its toggle states.
- `Format on Track to File Diff` controls whether track-to-file formatting applies.
- `Format on Track to Track Diff` controls whether track-to-track formatting applies.
- `Format on Externally Modified Diff` controls whether externally-modified formatting applies.
- Internal diff formatting does not appear when only one track is selected.
- Fields whose source track files have no value for the relevant tag are not formatted as different on that basis alone.
- Save/write operations persist the migrated per-track fields correctly for selected or all tracks, respecting existing write settings.
- The implementation is covered by targeted tests plus successful compile validation.
