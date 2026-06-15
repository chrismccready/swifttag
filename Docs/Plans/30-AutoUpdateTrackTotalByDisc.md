# Auto Update Track Total By Disc Plan

## Goal

Add a track-total calculation mode that can set or auto-update each track's
`TOTALTRACKS` value to the number of non-deleted tracks on that track's disc,
while preserving the current full-table track-count behavior when the new mode
is off.

## Scope

### In Scope

- Add `SaveSettingsKey.autoUpdateTrackTotalByDisc`.
- Add `SaveSettingsDefaults.autoUpdateTrackTotalByDisc = false`.
- Add an `@AppStorage` toggle in
  `SwiftTag/Features/Settings/TagWriteSettingsView.swift` after
  `Auto update Track Total`.
- Label the toggle `Auto update Track Total by Disc`.
- Add an accessibility identifier, recommended:
  `settings.tags.autoUpdateTrackTotalByDisc`.
- Add `@AppStorage` wiring in `SwiftTag/ContentView.swift`.
- When `autoUpdateTrackTotal` is on and
  `autoUpdateTrackTotalByDisc` is off, keep current behavior:
  set track total to non-deleted track count.
- When both settings are on, set each applicable track total to count of
  non-deleted tracks for that track's disc.
- Add `File` menu item after `Set Track Total`:
  `Set Track Total by Disc (...)`.
- Add `Set Track Total by Disc (...)` after existing `Set Track Total` in
  track-table and total-track field context menus.
- Route the new menu action to the focused key editor window.
- Enable the new menu with same base rules as `Set Track Total`.
- Expose the new setting to AppleScript.
- Update total-track mismatch, hover/help accuracy text, and diff/state checks
  so expected values use current active calculation mode.
- Update User Documentation HTML files where this behavior appears.
- Add focused unit, ViewInspector/source-order, and targeted integration tests
  where they provide useful coverage.

### Out Of Scope

- Changing track number calculation.
- Changing disc total calculation.
- Changing album, album artist, compilation, picture, or save-scope behavior.
- Changing FLAC parser behavior or fixture formats.
- Reworking total-track alias storage beyond existing `Track.totalTracks`
  abstraction.

## Plan Input Checklist Coverage

- Latest numbered plan reviewed:
  - `Docs/Plans/29-AddSandboxSettings.md`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
- Relevant app files reviewed:
  - `SwiftTag/Features/Settings/TagWriteSettingsView.swift`
  - `SwiftTag/Shared/Models/SaveSettings.swift`
  - `SwiftTag/SwiftTagApp.swift`
  - `SwiftTag/ContentView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/Features/TagEditor/TagEditorView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorCoreTagsView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorTrackFileView.swift`
  - `SwiftTag/Features/FlacImport/FlacWriteMapper.swift`
  - `SwiftTag/Shared/Models/Track.swift`
  - `SwiftTag/Shared/Utilities/TagDiffFormatting.swift`
- Relevant user documentation files to inspect/update:
  - `Docs/UserDocumentation/workflows/settings.html`
  - `Docs/UserDocumentation/workflows/tags.html`
  - `Docs/UserDocumentation/workflows/saving.html`
  - `Docs/UserDocumentation/automation/applescript-application.html`
  - `Docs/UserDocumentation/automation/applescript.html`
  - `Docs/UserDocumentation/index.html`
- Relevant tests reviewed:
  - `SwiftTagTests/SwiftTagTests.swift`
  - `SwiftTagTests/TrackStatusViewInspectorTests.swift`
  - `SwiftTagTests/SwiftTagAppleScriptTests.swift`
  - `SwiftTagTests/SwiftTagHelpDocumentationTests.swift`
  - `SwiftTagUITests/SwiftTagUITests.swift`
- Relevant fixtures reviewed:
  - `SwiftTagTestFiles/test.flac`
  - `SwiftTagTestFiles/test-with_padding.flac`
  - `SwiftTagTestFiles/test.swifttag`

## Current Implementation Snapshot

- `TagWriteSettingsView` already stores `autoUpdateTrackTotal` via
  `@AppStorage`.
- `ContentView` mirrors `autoUpdateTrackTotal` via `@AppStorage` and calls
  `applyAutoTrackTotalIfNeeded()`.
- Current auto-update behavior calls
  `TagEditorViewModel.setTrackTotalToCurrentCount()`.
- Current manual menu title is `Set Track Total (<non-deleted count>)`.
- Current manual menu is disabled during save operations, when no non-deleted
  tracks exist, or when `autoUpdateTrackTotal` is on.
- `TagEditorViewModel.setTrackTotal(_:)` skips deleted and locked tracks.
- Current total-track mismatch logic compares non-empty total-track values
  against loaded track count.
- Current total-track diff logic writes expected tags through
  `FlacWriteMapper.makeTags(...)` from the current editor track values.
- `Track.totalTracks` normalizes aliases by removing `TOTALTRACKS` and
  `TRACKTOTAL`, then storing the editor value under `TOTALTRACKS`.
- Save output still follows `TrackCountKeyStrategy`, so FLAC writes can emit
  `TOTALTRACKS`, `TRACKTOTAL`, both, or neither.

## Confirmed Decisions

- Plan file path is `Docs/Plans/_AutoUpdateTrackTotalByDisc.md`.
- New persisted key name is `settings.autoUpdateTrackTotalByDisc`.
- New setting default is off.
- New Settings label is `Auto update Track Total by Disc`.
- New `File` menu label stem is `Set Track Total by Disc`.
- Menu title suffix uses comma-separated per-disc counts with zero placeholders
  for gaps, for example `Set Track Total by Disc (10,0,5)`.
- Existing table-count mode remains unchanged when new setting is off.
- New manual menu command acts on the focused key editor window, same as
  existing `Set Track Total`.
- Missing, blank, zero, or non-numeric `DISCNUMBER` values are invalid for
  by-disc counting.
- Tracks with invalid `DISCNUMBER` values are excluded from by-disc counts and
  keep their existing total-track value.
- Disc-number gaps are represented by `0` placeholders in menu titles. For
  example, discs 1 and 3 display as `(10,0,5)`.
- New setting is scriptable through AppleScript.
- New `Set Track Total by Disc (...)` command appears in the `File` menu,
  track-table context menu, and total-track field context menu.

## Product Behavior

### Settings

1. User opens Settings > Tags.
2. In `Track Total/Compilation Management`, user sees:
   - `Auto update Track Total`
   - `Auto update Track Total by Disc`
   - `Apply Compilation to all Tracks`
3. Toggling `Auto update Track Total by Disc` persists to user defaults.
4. The by-disc setting affects automatic updates only when
   `Auto update Track Total` is on.
5. Recommended UI behavior: leave by-disc toggle enabled even when parent auto
   update toggle is off, so user can preselect calculation mode.

### Automatic Track Total

1. If `Auto update Track Total` is off, no automatic total-track mutation occurs.
2. If `Auto update Track Total` is on and by-disc mode is off:
   - non-deleted unlocked tracks get total track count equal to non-deleted
     track count.
3. If both auto update settings are on:
   - app builds per-disc counts from non-deleted tracks.
   - tracks with missing, blank, zero, or non-numeric disc numbers are excluded
     from counts.
   - locked tracks contribute to counts.
   - deleted tracks do not contribute to counts.
   - non-deleted unlocked tracks get the count for their disc.
   - non-deleted unlocked tracks with invalid disc numbers keep their existing
     total-track value.
   - locked tracks keep existing editor values.
4. Auto-update must run after imports, deletes, reloads, lock toggles, and any
   disc-number edit that changes per-disc counts.
5. Auto-update should no-op when target values are already correct, avoiding
   needless view update loops.

### Manual File Menu Command

1. `File` menu shows existing `Set Track Total (...)`.
2. Immediately after it, `File` menu shows
   `Set Track Total by Disc (...)`.
3. Title suffix displays per-disc counts in disc-number order.
4. Disc gaps display as zero placeholders, for example `(10,0,5)`.
5. Selecting command updates the focused key editor window.
6. Command applies to whole non-deleted track table, not selected rows.
7. Command skips locked tracks, matching current `Set Track Total` behavior.
8. Command skips deleted tracks, matching current `Set Track Total` behavior.
9. Command leaves tracks with invalid disc numbers unchanged.
10. Command is disabled with same base rules as current `Set Track Total`:
   - save operation running
   - no non-deleted tracks
   - `autoUpdateTrackTotal` is on

### Context Menu Commands

1. Track-table context menu shows `Set Track Total by Disc (...)` immediately
   after existing `Set Track Total (...)`.
2. Total-track field context menu shows `Set Track Total by Disc (...)`
   immediately after existing `Set Track Total (...)`.
3. Context-menu command title and enablement match the `File` menu command.
4. Context-menu command action uses the same view callback as the `File` menu
   command.

### AppleScript Setting

1. AppleScript exposes `auto update track total by disc`.
2. Property reads and writes the same user defaults key as the Settings toggle.
3. Existing `auto update track total` remains the parent behavior switch.
4. Scripts can set by-disc preference before enabling automatic update.

## Proposed Implementation

### 1. Settings Model

- Extend `SaveSettingsKey`:
  - `static let autoUpdateTrackTotalByDisc = "settings.autoUpdateTrackTotalByDisc"`
- Extend `SaveSettingsDefaults`:
  - `static let autoUpdateTrackTotalByDisc = false`
- Add matching `@AppStorage` in:
  - `TagWriteSettingsView`
  - `ContentView`

Add AppleScript settings parity:

- `SwiftTag.sdef` property:
  - name: `auto update track total by disc`
  - recommended code: `autd`
  - cocoa key: `AutoUpdateTrackTotalByDiscSetting`
- `SwiftTagAppleScriptSupport.swift` property:
  - `@objc(AutoUpdateTrackTotalByDiscSetting)`

### 2. View Model Helpers

Add focused helpers in `TagEditorViewModel`:

- normalized positive disc-number lookup for a track.
- non-deleted track grouping by valid positive disc number.
- per-disc menu title suffix.
- expected total-track value for a track under:
  - table-count mode
  - by-disc mode
- `setTrackTotalToCurrentDiscCounts()`.
- `hasTotalTracksMismatch(autoUpdateTrackTotalByDisc:)`.
- `totalTracksHoverMessage(autoUpdateTrackTotalByDisc:)`.
- an `Equatable` auto-update input snapshot for `ContentView.onChange`.

Keep old property names as compatibility shims if that reduces test churn:

- `hasTotalTracksMismatch` can call new method with `false`.
- `totalTracksHoverMessage` can call new method with `false`.

### 3. Content View Wiring

- Add `@AppStorage(SaveSettingsKey.autoUpdateTrackTotalByDisc)`.
- Change `hasTotalTracksMismatch` to call view-model method with active mode.
- Change `totalTracksHoverMessage` to use active mode.
- Add `setTrackTotalByDiscMenuTitle`.
- Add `canSetTrackTotalByDisc`.
- Add `setTrackTotalToCurrentDiscCounts()` action wrapper.
- Pass by-disc menu title, action, and enablement into
  `TagEditorTrackFileView`, `TagEditorCoreTagsView`, and `TagEditorView`.
- Change `applyAutoTrackTotalIfNeeded()`:
  - guard `autoUpdateTrackTotal`.
  - if `autoUpdateTrackTotalByDisc`, call by-disc setter.
  - else call current-count setter.
- Add `.onChange(of: autoUpdateTrackTotalByDisc)`.
- Replace or augment `.onChange(of: viewModel.nonDeletedTrackCount)` with a
  snapshot that also changes when normalized disc numbers change.
- Add focused scene values:
  - `setTrackTotalByDiscTitle`
  - `performSetTrackTotalByDisc`
  - `canPerformSetTrackTotalByDisc`

### 4. File Menu

In `SwiftTagApp.swift`, add after existing `Set Track Total` button:

- Button with `setTrackTotalByDiscTitle ?? "Set Track Total by Disc (0)"`.
- Action calls focused `performSetTrackTotalByDisc`.
- Disabled when focused `canPerformSetTrackTotalByDisc` is false.

Keep divider placement consistent with existing `File` menu:

- no new divider between the two total-track commands.
- keep existing divider after the total-track command group.

### 5. Context Menus

- Add `Set Track Total by Disc (...)` after existing `Set Track Total (...)` in
  `TagEditorTrackFileView` table context menu.
- Add `Set Track Total by Disc (...)` after existing `Set Track Total (...)` in
  both total-track field context-menu branches in `TagEditorCoreTagsView`.
- Use same title, action, and disabled state as the `File` menu item.

### 6. Diff And Accuracy Checks

- Make total-track mismatch compare against active expected count:
  - table-count mode: non-deleted track count.
  - by-disc mode: count for each track's valid positive disc number.
- In by-disc mode, ignore tracks with invalid disc numbers for mismatch.
- Keep empty total-track values ignored for mismatch, unless auto update fills
  them first.
- Update hover/help text to report active expectation:
  - table mode: loaded non-deleted track count.
  - by-disc mode: per-disc count list with zero placeholders for gaps.
- Ensure track-to-file and editor difference checks see by-disc values after
  manual or automatic mutation.
- If stale values can exist before mutation, prefer computing expected
  total-track values inside view-model comparison helpers rather than relying
  on UI timing.

### 7. User Documentation

- Update `Docs/UserDocumentation/workflows/settings.html` for the new
  `Auto update Track Total by Disc` setting.
- Update `Docs/UserDocumentation/workflows/tags.html` for table-count versus
  per-disc total-track behavior.
- Update `Docs/UserDocumentation/workflows/saving.html` if it describes
  automatic count updates or pending tag edits.
- Update AppleScript documentation pages for the new scriptable setting:
  - `Docs/UserDocumentation/automation/applescript-application.html`
  - `Docs/UserDocumentation/automation/applescript.html`
- Update `Docs/UserDocumentation/index.html` only if navigation, feature
  summary, or cross-links need the new setting surfaced.
- Preserve existing documentation visual style, link structure, table format,
  and terminology.

## Destructive / Write-Back Semantics

### Data Preserved

- Track order.
- Track selection.
- Track lock state.
- Deleted-row status.
- Album, album artist, title, date, genre, composer, location, description,
  comment, compilation, and picture data.
- Existing save scope and save payload semantics.
- Existing `TrackCountKeyStrategy` behavior on write.

### Data Replaced

- For affected non-deleted unlocked tracks, current editor total-track value is
  replaced with calculated value.
- Existing editor `TOTALTRACKS` / `TRACKTOTAL` alias pair is normalized through
  existing `Track.totalTracks` setter.
- On FLAC tag writes, count keys are rewritten according to
  `TrackCountKeyStrategy`.

### Data Removed

- Existing alternate total-track alias values may be removed from the editor
  model by the existing `Track.totalTracks` setter.
- When `TrackCountKeyStrategy` is `.none`, saved FLAC tags omit total-track
  keys as they do today.

### Partial Save Behavior

- `Tags` and `Tags & Pictures` saves can persist new total-track values.
- `Pictures` saves do not persist total-track changes.
- Manual menu mutation can create pending tag edits even before save.
- Automatic mutation can create pending tag edits when active setting changes
  or track/disc composition changes.

### Selection Semantics

- Existing `Set Track Total` and new `Set Track Total by Disc` are table-wide
  commands scoped to the focused key editor window.
- Selected rows are not the source of truth for either command.

## High-Risk Concerns

### Product / Behavior Risks

- Missing, blank, zero, or non-numeric disc numbers are invalid for by-disc
  counting and must be consistently ignored by mutation, mismatch, and title
  helpers.
- Gaps in disc numbers must show zero placeholders without creating any track
  mutations for missing discs.
- Locked tracks count toward disc totals but remain unchanged,
  matching current total-track behavior.
- Deleted rows are excluded from counts and updates, matching
  current total-track behavior.
- Auto-update by disc must react to disc-number edits, not only row-count
  changes.
- If by-disc mode writes different totals per disc, selected multi-disc rows
  will intentionally show mixed total-track values.

### Tooling / Environment Risks

- SwiftUI command menu state flows through `FocusedValues`, which is better
  covered by focused source/order checks plus small ViewInspector seams than by
  broad UI automation.
- ViewInspector support for `Table` and command menus is limited.
- Full UI suite may be slow and brittle; prefer targeted tests.
- FLAC writeback tests must mutate copied fixtures only.

## Test Strategy

### Unit Tests

Add or update `SwiftTagTests/SwiftTagTests.swift`:

- defaults include `autoUpdateTrackTotalByDisc == false`.
- per-disc count helper returns ordered counts for disc groups.
- `setTrackTotalToCurrentDiscCounts()`:
  - counts non-deleted tracks per disc.
  - excludes missing, blank, zero, and non-numeric disc numbers.
  - includes locked tracks in counts.
  - skips locked tracks on mutation.
  - skips deleted tracks in counts and mutation.
  - leaves invalid-disc tracks unchanged.
- menu suffix helper formats `(10,0,5)` when disc 2 has no tracks.
- table-count mismatch behavior remains current when by-disc mode is false.
- by-disc mismatch behavior accepts per-disc totals and rejects table totals
  when they differ.
- by-disc mismatch behavior ignores invalid-disc tracks.
- editor difference counts reflect by-disc calculated values after manual
  mutation.

### ViewInspector / Source Tests

Update `SwiftTagTests/TrackStatusViewInspectorTests.swift`:

- `TagWriteSettingsView` source or inspected tree includes
  `Auto update Track Total by Disc`.
- Toggle accessibility identifier is present.
- Toggle appears after `Auto update Track Total`.
- `SwiftTagApp` source has `Set Track Total by Disc` menu wiring after
  existing `Set Track Total`.
- `TagEditorTrackFileView` source has `Set Track Total by Disc` context-menu
  wiring after existing `Set Track Total`.
- `TagEditorCoreTagsView` source has `Set Track Total by Disc` context-menu
  wiring after existing `Set Track Total`.
- Existing helper initializers are updated if view signatures gain new inputs.

### AppleScript Tests

- Update settings read/write tests in `SwiftTagAppleScriptTests`.
- Add new setting key to reset/default test helpers.
- Update sdef terminology checks if present.

### Documentation Tests

- Update `SwiftTagHelpDocumentationTests` if navigation, expected paths, or
  generated help assumptions change.
- Add lightweight source/link checks if documentation pages gain new anchors or
  cross-page links.

### Optional FLAC Fixture Test

Use copied `SwiftTagTestFiles/test-with_padding.flac` only if mapper/unit tests
do not cover enough writeback confidence:

- import/copy fixture into temp directory.
- apply by-disc totals to editor model.
- save tags only.
- read metadata back and verify per-disc total-track value.

Prefer not adding this unless pure unit coverage leaves a gap.

## Verification Strategy

Use Xcode MCP tools where available:

1. `XcodeRefreshCodeIssuesInFile` for edited Swift files.
2. `BuildProject`.
3. `RunSomeTests` for:
   - `SwiftTagTests/SwiftTagTests`
   - `SwiftTagTests/TrackStatusViewInspectorTests`
   - `SwiftTagTests/SwiftTagAppleScriptTests`
   - `SwiftTagTests/SwiftTagHelpDocumentationTests`
4. Avoid full UI suite unless targeted coverage exposes a command-routing gap.

Fallback shell commands, only if MCP unavailable:

```sh
xcodebuild -scheme SwiftTag build
xcodebuild -scheme SwiftTag -destination 'platform=macOS' test -only-testing:SwiftTagTests/SwiftTagTests
xcodebuild -scheme SwiftTag -destination 'platform=macOS' test -only-testing:SwiftTagTests/TrackStatusViewInspectorTests
```

## Acceptance Criteria

- Settings > Tags shows `Auto update Track Total by Disc` immediately after
  `Auto update Track Total`.
- New setting persists through `@AppStorage`.
- Default value is off.
- With auto update on and by-disc off, existing table-count behavior remains.
- With auto update on and by-disc on, total-track values are calculated per
  disc.
- Tracks with missing, blank, zero, or non-numeric disc numbers keep their
  existing total-track values.
- `File` menu shows `Set Track Total by Disc (...)` after `Set Track Total`.
- Track-table context menu shows `Set Track Total by Disc (...)` after
  `Set Track Total`.
- Total-track field context menu shows `Set Track Total by Disc (...)` after
  `Set Track Total`.
- Menu title displays ordered per-disc counts with zero placeholders for gaps,
  for example `(10,0,5)`.
- Menu command applies to focused key editor window.
- Menu command obeys same enablement rules as `Set Track Total`.
- AppleScript can read and write `auto update track total by disc`.
- User Documentation HTML describes the setting, per-disc behavior, menu/context
  commands, and AppleScript property where appropriate.
- Documentation links and help tests remain valid.
- Diff formatting and mismatch warning use active expected total-track mode.
- Targeted tests pass.
- Project builds.

## Open Questions Before Implementation

None.
