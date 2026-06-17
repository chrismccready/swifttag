# Auto Update Disc Total Plan

## Goal

Add automatic and manual disc-total commands that set each applicable track's
`TOTALDISCS` value to the calculated disc count for the key editor window,
where disc count is the maximum valid `DISCNUMBER` found across tracks.

## Scope

### In Scope

- Add `SaveSettingsKey.autoUpdateDiscTotal`.
- Add `SaveSettingsDefaults.autoUpdateDiscTotal = false`.
- Add an `@AppStorage` toggle in
  `SwiftTag/Features/Settings/TagWriteSettingsView.swift` immediately after
  `Auto update Track Total by Disc`.
- Label the toggle `Auto update Disc Total`.
- Add an accessibility identifier, recommended:
  `settings.tags.autoUpdateDiscTotal`.
- Add `@AppStorage` wiring in `SwiftTag/ContentView.swift`.
- When `autoUpdateDiscTotal` is on, update applicable tracks so `TOTALDISCS`
  equals calculated disc count.
- When `autoUpdateDiscTotal` is off, do not automatically calculate or mutate
  disc totals.
- Add `File` menu item after `Set Track Total by Disc (...)`:
  `Set Disc Total (...)`.
- Add `Set Disc Total (...)` to the track-table context menu after
  `Set Track Total by Disc (...)`.
- Route the new menu action to the focused key editor window.
- Enable the new menu when `autoUpdateDiscTotal` is off, the key editor window
  has tracks, and calculated disc count is greater than `0`.
- Expose the new setting to AppleScript as `auto update disc total` on the
  `application` class.
- Add focused unit, source-order/ViewInspector, AppleScript, and build
  verification coverage.
- Update user documentation where settings, tag commands, and AppleScript
  application properties are documented.

### Out Of Scope

- Changing track-total behavior.
- Changing track-number behavior.
- Changing FLAC parser behavior or fixture formats.
- Adding AppleScript commands for `Set Disc Total`.
- Changing save scope, save payload, or picture behavior.
- Changing `DiscCountKeyStrategy` semantics for actual FLAC writeback.
- Adding `Set Disc Total` to total-disc field context menu unless confirmed.

## Plan Input Checklist Coverage

- Latest numbered plan reviewed:
  - `Docs/Plans/31-SetTrackNumbersAndSortTracks.md`
- Closest related plan reviewed:
  - `Docs/Plans/30-AutoUpdateTrackTotalByDisc.md`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
- Relevant app files reviewed:
  - `SwiftTag/Shared/Models/SaveSettings.swift`
  - `SwiftTag/Features/Settings/TagWriteSettingsView.swift`
  - `SwiftTag/SwiftTagApp.swift`
  - `SwiftTag/ContentView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorTrackFileView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorCoreTagsView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/Shared/Models/Track.swift`
  - `SwiftTag/Features/FlacImport/FlacWriteMapper.swift`
  - `SwiftTag/SwiftTag.sdef`
  - `SwiftTag/Shared/Utilities/SwiftTagAppleScriptSupport.swift`
- Relevant user documentation files to inspect/update:
  - `Docs/UserDocumentation/workflows/settings.html`
  - `Docs/UserDocumentation/workflows/tags.html`
  - `Docs/UserDocumentation/automation/applescript-application.html`
  - `Docs/UserDocumentation/automation/applescript.html`
  - `Docs/UserDocumentation/index.html`
- Relevant tests reviewed:
  - `SwiftTagTests/SwiftTagTests.swift`
  - `SwiftTagTests/TrackStatusViewInspectorTests.swift`
  - `SwiftTagTests/SwiftTagAppleScriptTests.swift`
  - `SwiftTagUITests/SwiftTagUITests.swift`
- Relevant fixtures reviewed:
  - `SwiftTagTestFiles/test.flac`
  - `SwiftTagTestFiles/test-with_padding.flac`
  - `SwiftTagTestFiles/test.swifttag`

## Current Implementation Snapshot

- `TagWriteSettingsView` already has:
  - `Auto update Track Total`
  - `Auto update Track Total by Disc`
  - `Apply Compilation to all Tracks`
- `SaveSettingsKey` and `SaveSettingsDefaults` already contain
  `autoUpdateTrackTotal` and `autoUpdateTrackTotalByDisc`.
- `ContentView` owns command titles, enablement, action wrappers,
  `@AppStorage` settings, and focused scene values for track-total commands.
- `SwiftTagApp.AppCommands` consumes focused values for `File` menu commands.
- Existing `File` menu order near totals is:
  - `Set Track Total (...)`
  - `Set Track Total by Disc (...)`
- `TagEditorTrackFileView` context menu mirrors the same command order.
- `TagEditorCoreTagsView` has context-menu commands only for total-track field,
  not total-disc field.
- `TagEditorViewModel.validDiscNumber(for:)` already normalizes positive
  integer `DISCNUMBER` values.
- `TagEditorViewModel.totalTrackCountsByDisc()` already counts non-deleted
  tracks by valid disc number for track-total-by-disc behavior.
- `TagEditorViewModel.currentTotalDiscsValue(for:)` reads `TOTALDISCS`, then
  `DISCTOTAL`, then global editor `totalDiscs`.
- `TagEditorViewModel.setCurrentTotalDiscsValue(...)` preserves an existing
  `DISCTOTAL` alias when that is the only present disc-total key.
- `.swifttag` document export canonicalizes disc total to `TOTALDISCS`.
- FLAC save output still follows `DiscCountKeyStrategy`, so saved FLAC can emit
  `TOTALDISCS`, `DISCTOTAL`, both, or neither.
- AppleScript application settings are exposed through SDEF properties and
  `@objc(...Setting)` KVC properties on `NSApplication`.

## Confirmed Decisions

- Draft plan file path is `Docs/Plans/_AutoUpdateDiscTotal.md`.
- New Swift setting name is `autoUpdateDiscTotal`.
- New Settings label is `Auto update Disc Total`.
- New Settings toggle appears immediately after
  `Auto update Track Total by Disc`.
- New `File` menu item label stem is `Set Disc Total`.
- New `File` menu item appears immediately after
  `Set Track Total by Disc (...)`.
- New track-table context-menu item appears immediately after
  `Set Track Total by Disc (...)`.
- Menu title uses parentheses around calculated disc count:
  `Set Disc Total (3)`.
- Disc count is calculated from maximum valid positive numeric `DISCNUMBER`.
  Gaps still count because maximum disc number is source of truth. Example:
  discs `1` and `3` produce disc count `3`.
- Manual command is disabled when `autoUpdateDiscTotal` is on.
- Manual command targets the focused key editor window.
- AppleScript setting name is `auto update disc total`.
- Locked tracks are skipped, matching existing total commands.
- Deleted-in-table tracks are excluded from calculated disc count and skipped
  during mutation, matching existing track-total count behavior.
- `TOTALDISCS` and `DISCTOTAL` are aliases; preserve existing alias shape when
  updating disc totals.
- The total-discs editor field disables while `autoUpdateDiscTotal` is on.
- `Set Disc Total (0)` is disabled.

## Open Questions

- None.

## Product Behavior

### Settings

1. User opens Settings > Tags.
2. In `Track Total/Compilation Management`, user sees:
   - `Auto update Track Total`
   - `Auto update Track Total by Disc`
   - `Auto update Disc Total`
   - `Apply Compilation to all Tracks`
3. Toggling `Auto update Disc Total` persists to user defaults.
4. `Auto update Disc Total` is independent of `Auto update Track Total`.
5. `Auto update Disc Total` affects editor tag values only; actual FLAC
   writeback still obeys `Write Disc Total key`.

### Automatic Disc Total

1. If `Auto update Disc Total` is off, no automatic disc-total mutation occurs.
2. If `Auto update Disc Total` is on:
   - app calculates disc count as the maximum valid positive numeric
     `DISCNUMBER`.
   - deleted tracks do not affect the calculated disc count.
   - tracks without valid positive numeric `DISCNUMBER` do not affect the
     calculated disc count.
   - non-deleted unlocked tracks get disc total set to calculated disc count.
   - existing `TOTALDISCS` / `DISCTOTAL` alias shape is preserved.
   - locked tracks keep existing values.
   - if calculated count is `0`, automatic update no-ops.
3. Total-discs field is disabled while `Auto update Disc Total` is on.
4. Auto-update must run after imports, deletes, reloads, lock toggles, and any
   disc-number edit that changes maximum disc number.
5. Auto-update should no-op when target values are already correct to avoid
   needless view update loops.

### Manual File Menu Command

1. `File` menu shows existing `Set Track Total (...)`.
2. Immediately after it, `File` menu shows existing
   `Set Track Total by Disc (...)`.
3. Immediately after it, `File` menu shows `Set Disc Total (...)`.
4. Title suffix displays calculated disc count, for example
   `Set Disc Total (3)`.
5. Selecting command updates the focused key editor window.
6. Command applies to the whole key editor window, not selected rows.
7. Command is disabled when:
   - save operation is running
   - no tracks exist in the focused key editor window
   - calculated disc count is `0`
   - `autoUpdateDiscTotal` is on
8. Command skips locked and deleted-in-table tracks.
9. Command preserves existing `TOTALDISCS` / `DISCTOTAL` alias shape.

### Track Table Context Menu

1. Track-table context menu shows `Set Disc Total (...)` immediately after
   `Set Track Total by Disc (...)`.
2. Context-menu command title and enablement match the `File` menu command.
3. Context-menu command action uses the same view callback as the `File` menu
   command.

### AppleScript Setting

1. AppleScript exposes `auto update disc total` on `application`.
2. Property reads and writes the same user defaults key as the Settings toggle.
3. Scripts can set the preference without requiring an open editor window.

Example:

```applescript
tell application "SwiftTag"
    set auto update disc total to true
end tell
```

## Proposed Implementation

### 1. Settings Model

- Extend `SaveSettingsKey`:
  - `static let autoUpdateDiscTotal = "settings.autoUpdateDiscTotal"`
- Extend `SaveSettingsDefaults`:
  - `static let autoUpdateDiscTotal = false`
- Update `SwiftTagTests/SwiftTagTests.swift` default coverage.

### 2. Settings View

- Add `@AppStorage(SaveSettingsKey.autoUpdateDiscTotal)` to
  `TagWriteSettingsView`.
- Add toggle immediately after `Auto update Track Total by Disc`:
  - `Toggle("Auto update Disc Total", isOn: $autoUpdateDiscTotal)`
  - `.accessibilityIdentifier("settings.tags.autoUpdateDiscTotal")`
  - `.accessibilityValue(autoUpdateDiscTotal ? "On" : "Off")`
- Do not gate this toggle behind `autoUpdateTrackTotal`.

### 3. View Model Helpers

Add focused helpers in `TagEditorViewModel`:

- `calculatedDiscTotal()`:
  - returns maximum valid positive numeric `DISCNUMBER`, or `0`.
- `setDiscTotalToCurrentDiscCount()`:
  - calculates current disc count.
  - no-ops when count is `0`.
  - updates non-deleted unlocked tracks.
  - preserves existing `TOTALDISCS` / `DISCTOTAL` alias shape by reusing
    `setCurrentTotalDiscsValue(...)`.
  - clears external differences for `TOTALDISCS` / `DISCTOTAL`.
- `discTotalMenuSuffix()`:
  - returns `(<calculated count>)`, including `(0)`.
- `autoDiscTotalInputSnapshot`:
  - includes each track id, deletion state, lock state, and valid disc number.
  - drives automatic recalculation when disc-number inputs change.
- Optional mismatch/help variants:
  - `hasTotalDiscsMismatch(autoUpdateDiscTotal:)`
  - `totalDiscsHoverMessage(autoUpdateDiscTotal:)`

### 4. Content View Wiring

- Add `@AppStorage(SaveSettingsKey.autoUpdateDiscTotal)`.
- Add:
  - `setDiscTotalMenuTitle`
  - `canSetDiscTotal`
  - `setDiscTotalToCurrentDiscCount()`
  - `applyAutoDiscTotalIfNeeded()`
- Call `applyAutoDiscTotalIfNeeded()` from:
  - `.onChange(of: autoUpdateDiscTotal)`
  - `.onChange(of: viewModel.autoDiscTotalInputSnapshot)`
  - import completion paths where auto track total already runs
  - reload/delete paths where auto track total already runs
  - disc-number edit changes through snapshot updates
- Pass title, enablement, and action through:
  - `TagEditorView`
  - `TagEditorTrackFileView`
- Pass `isDiscTotalAutoUpdateEnabled` into `TagEditorView` and
  `TagEditorCoreTagsView`.
- Disable total-discs field when `!isAlbumMetadataEditable` or
  `isDiscTotalAutoUpdateEnabled`.
- Add focused scene values:
  - `setDiscTotalTitle`
  - `performSetDiscTotal`
  - `canPerformSetDiscTotal`

### 5. File Menu

In `SwiftTagApp.swift`, add after existing `Set Track Total by Disc` button:

- Button with `setDiscTotalTitle ?? "Set Disc Total (0)"`.
- Action calls `performSetDiscTotal?()`.
- Disabled when `!(canPerformSetDiscTotal ?? false)`.
- No keyboard shortcut unless requested.

### 6. Track Table Context Menu

In `TagEditorTrackFileView`:

- Add closure/title/can properties:
  - `onSetDiscTotal`
  - `setDiscTotalMenuTitle`
  - `canSetDiscTotal`
- Add button immediately after `Set Track Total by Disc (...)`.
- Wire through `TagEditorView`.

### 7. AppleScript Setting

In `SwiftTag.sdef`, add application property after
`auto update track total by disc`:

- name: `auto update disc total`
- recommended code: `audt`
- type: `boolean`
- access: `rw`
- cocoa key: `AutoUpdateDiscTotalSetting`

In `SwiftTagAppleScriptSupport.swift`, add:

- `@objc(AutoUpdateDiscTotalSetting)`
- getter via `boolSetting(key:defaultValue:)`
- setter writing `SaveSettingsKey.autoUpdateDiscTotal`

### 8. User Documentation

Update documentation if implementation proceeds:

- `Docs/UserDocumentation/workflows/settings.html`
  - add setting row and AppleScript link.
- `Docs/UserDocumentation/workflows/tags.html`
  - add manual command and auto-update behavior.
- `Docs/UserDocumentation/automation/applescript-application.html`
  - add application property.
- `Docs/UserDocumentation/automation/applescript.html`
  - include setting in property overview if listed there.
- `Docs/UserDocumentation/index.html`
  - update only if feature summary mentions tag-total commands.

## Destructive / Write-Back Behavior

- Existing data preserved:
  - all tags other than `TOTALDISCS` / `DISCTOTAL`
  - locked-track disc-total values
  - deleted-track disc-total values
  - existing `TOTALDISCS` / `DISCTOTAL` alias shape on updated tracks
  - picture data and picture metadata
- Existing data replaced:
  - current disc-total alias value on applicable non-locked, non-deleted tracks
- Existing data removed:
  - none, except existing total-disc aliases are both removed when setting an
    empty value through existing manual field behavior
- Save behavior:
  - tag-only saves write updated disc-total values according to
    `DiscCountKeyStrategy`
  - picture-only saves do not write tag changes
  - tags-and-pictures saves write updated disc-total values according to
    `DiscCountKeyStrategy`
- Selection behavior:
  - manual and automatic disc-total updates ignore current selection and apply
    to whole key editor window, while still skipping locked/deleted tracks
  - save scope remains independent and only affects later save commands

## High-Risk Concerns

### Product / Behavior Risks

- Auto update must react to maximum `DISCNUMBER` changes even when row count
  does not change.
- Disc-number gaps intentionally inflate count because maximum disc number is
  source of truth.
- `DiscCountKeyStrategy.none` can make in-editor `TOTALDISCS` changes not appear
  in FLAC writeback; documentation should state this.
- Disabled `Set Disc Total (0)` requires `canSetDiscTotal` to check both track
  presence and calculated disc count.
- Alias preservation means tests must cover both `TOTALDISCS` and `DISCTOTAL`
  source tracks.

### Tooling / Environment Risks

- Xcode MCP tests can time out; run targeted unit tests before broad tests.
- AppleScript end-to-end tests can be brittle; prefer in-process KVC/SDEF unit
  tests for setting exposure.
- FLAC fixture mutation should use copied fixtures only; this plan does not
  require mutating checked-in fixture files.
- Full UI automation should be avoided unless focused unit/source tests cannot
  prove command wiring.

## Test Strategy

### Unit Tests

In `SwiftTagTests/SwiftTagTests.swift`:

- Extend `saveSettingsDefaultsMatchPlan` for
  `SaveSettingsDefaults.autoUpdateDiscTotal == false`.
- Add `TagEditorViewModel` tests for:
  - calculated disc count uses maximum valid positive numeric `DISCNUMBER`.
  - invalid, blank, zero, and non-numeric disc numbers are ignored.
  - gaps use maximum disc number, for example discs `1` and `3` produce `3`.
  - manual setter updates expected non-deleted unlocked tracks.
  - setter preserves existing `TOTALDISCS` / `DISCTOTAL` alias shape.
  - no valid disc numbers produce count `0`, disabled menu state, and setter
    no-op.
  - locked and deleted tracks are skipped.
  - external differences clear for disc-total keys after mutation.
  - optional mismatch/help text if adjusted for auto mode.

### SwiftUI / Source-Order Tests

In `SwiftTagTests/TrackStatusViewInspectorTests.swift`:

- Update settings source-order test:
  - `Auto update Disc Total` exists.
  - accessibility id exists.
  - toggle appears after `Auto update Track Total by Disc` and before
    `Apply Compilation to all Tracks`.
- Update `SwiftTagApp` command-order source test:
  - `Set Disc Total` focused button appears after
    `Set Track Total by Disc`.
  - action and can-focused values are wired.
- Update `TagEditorTrackFileView` context menu source test:
  - `Set Disc Total` appears after `Set Track Total by Disc`.
  - action closure is called.
- Add `actualView()` forwarding tests for `TagEditorView` if constructor
  expansion makes source-order tests insufficient.
- Add total-disc field disabled-state coverage for `autoUpdateDiscTotal`.

### AppleScript Tests

In `SwiftTagTests/SwiftTagAppleScriptTests.swift`:

- Add `SaveSettingsKey.autoUpdateDiscTotal` to settings cleanup list.
- Add `AutoUpdateDiscTotalSetting` to boolean KVC setting matrix.
- Add SDEF/property code assertion for `auto update disc total` / `audt` if
  current helper supports property-code lookup.
- Add terminology compile coverage only if existing tests already compile
  application property examples without UI runner instability.

### Documentation Tests

In `SwiftTagTests/SwiftTagHelpDocumentationTests.swift`:

- Update expectations if documentation link validation or property lists change.

### Verification Order

1. `XcodeRefreshCodeIssuesInFile` on edited Swift files.
2. `BuildProject`.
3. Targeted tests:
   - `SwiftTagTests/SwiftTagTests`
   - `SwiftTagTests/TrackStatusViewInspectorTests`
   - `SwiftTagTests/SwiftTagAppleScriptTests`
   - `SwiftTagTests/SwiftTagHelpDocumentationTests` if docs change.
4. Full test suite only if targeted coverage exposes shared behavior risk or
   user requests it.

## Acceptance Criteria

- Settings > Tags shows `Auto update Disc Total` immediately after
  `Auto update Track Total by Disc`.
- Setting persists through `@AppStorage` and defaults to off.
- When setting is on, editor automatically sets applicable track disc-total
  aliases to calculated disc count from maximum valid `DISCNUMBER`.
- When setting is off, automatic disc-total calculation does not run.
- Total-discs field is disabled while `Auto update Disc Total` is on.
- `File` menu shows `Set Disc Total (<disc count>)` immediately after
  `Set Track Total by Disc (...)`.
- Track-table context menu shows `Set Disc Total (<disc count>)` immediately
  after `Set Track Total by Disc (...)`.
- Manual command is enabled only when `autoUpdateDiscTotal` is off, save is not
  running, the focused key editor window has tracks, and calculated disc count
  is greater than `0`.
- Manual command ignores selection and updates non-deleted unlocked tracks in
  the whole key editor window.
- Displayed disc count uses maximum valid positive numeric `DISCNUMBER`.
- Mutations preserve existing `TOTALDISCS` / `DISCTOTAL` alias shape.
- AppleScript can read and write `auto update disc total`.
- Tests cover defaults, calculation, mutation, menu/context-menu wiring, and
  AppleScript setting exposure.
- User documentation reflects the new setting, command, and AppleScript
  property.
