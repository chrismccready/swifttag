# Set Track Numbers And Sort Tracks Plan

## Goal

Add whole-table track-number commands, a visible track-table sort toggle, and an
AppleScript `track sort order` editor-window property that all use the same
current table-order logic.

## Scope

### In Scope

- Add `Set Track Numbers` to the `File` menu before `Set Track Total (...)`.
- Add `Set Track Numbers by Disc` immediately after `Set Track Numbers`.
- Add both track-number commands to the track-table context menu before
  `Set Track Total (...)`.
- Add `Sort Tracks by Filename` / `Sort Tracks by Number` below
  `Toggle Selected Tracks Lock` in the `File` menu and track-table context
  menu.
- Add a two-mode track-table sort state:
  - number mode, current default behavior
  - filename mode
- Make track-number commands use a snapshot of the current visible table order.
- Make track-number commands skip locked tracks.
- Make by-disc numbering skip tracks with no valid `DISCNUMBER`.
- Add AppleScript `track sort options` enumeration and `track sort order`
  editor-window property to `SwiftTag/SwiftTag.sdef`.
- Route AppleScript sorting through the same model behavior as the UI sort
  command.
- Keep AppleScript track index specifiers aligned with current table sort mode.
- Add focused unit, source-order/ViewInspector, and AppleScript tests.
- Update user documentation for menu and AppleScript behavior.

### Out Of Scope

- Persisting track-table sort mode across app launches or `.swifttag` documents.
- Adding AppleScript commands for setting track numbers.
- Changing FLAC parser, writer, padding, or picture behavior.
- Changing save scope or payload behavior.
- Changing existing `Set Track Total (...)` or `Set Track Total by Disc (...)`
  semantics except for menu placement around new items.

## Plan Input Checklist Coverage

- Latest numbered plan reviewed:
  - `Docs/Plans/30-AutoUpdateTrackTotalByDisc.md`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
  - `Docs/AppleDocsIndex/apple-docs-scout-agent.md`
- Apple Docs Scout review completed:
  - Cocoa scripting still supports `.sdef` commands/enumerations dispatched to
    `NSScriptCommand` handlers.
  - `NSScriptCommand.evaluatedArguments` is right input source for command
    parameters.
  - enum arguments should be parsed by Apple event descriptor/FourChar code, not
    display strings.
  - Primary evidence: Foundation `NSScriptCommand`,
    `NSScriptCommandDescription`, `NSScriptClassDescription`,
    `NSScriptSuiteRegistry`, and `NSAppleEventDescriptor` docs/headers.
- Relevant app files reviewed:
  - `SwiftTag/SwiftTagApp.swift`
  - `SwiftTag/ContentView.swift`
  - `SwiftTag/SwiftTag.sdef`
  - `SwiftTag/Shared/Models/Track.swift`
  - `SwiftTag/Shared/Models/TagKey.swift`
  - `SwiftTag/Features/TagEditor/TagEditorView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorTrackFileView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorCoreTagsView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagAppleScriptSupport.swift`
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

- `TagEditorTrackFileView` currently sorts rows via
  `trackItems.sortedForTrackTableDisplay()`.
- `sortedForTrackTableDisplay()` sorts by numeric `TRACKNUMBER`, then filename.
- `ContentView` owns menu labels, enablement, focused scene values, and action
  wrappers for existing track-total commands.
- `SwiftTagApp.AppCommands` consumes focused values for `File` menu commands.
- Track-table context menu already contains:
  - add commands
  - `Toggle Selected Tracks Lock`
  - `Set Track Total (...)`
  - `Set Track Total by Disc (...)`
  - reload/remove commands
  - optional column commands
- `TagEditorViewModel.setTrackTotal(...)` skips deleted and locked tracks.
- `TagEditorViewModel.setTrackTotalToCurrentDiscCounts()` skips deleted,
  locked, and invalid-disc tracks.
- `SwiftTagAppleScriptController.tracks(forSessionID:)`,
  `selectedTrackObjects(forSessionID:)`, and `indexOfTrack(...)` currently sort
  with `sortedForTrackTableDisplay()`.
- AppleScript command handlers already use `NSScriptCommand.evaluatedArguments`
  and parse enum-like options from FourChar values for save/close commands.
- `SwiftTagAppleScriptSessionBridge` is the live-window seam for mutating an
  editor session from AppleScript.

## Confirmed Decisions

- Initial sort mode is number mode, matching current table behavior.
- Track-table sort mode is scoped per editor window.
- New/opened editor windows always default to number mode: numeric
  `TRACKNUMBER`, then filename.
- Sort command changes visible table ordering only; it does not rewrite tags or
  reorder the stored `trackItems` array.
- `Sort Tracks by Filename` appears while current sort mode is number mode.
- `Sort Tracks by Number` appears while current sort mode is filename mode.
- `Set Track Numbers` acts on all tracks in the key editor window, not selected
  tracks.
- Track table visible order is source of truth for new numbering commands.
- Numbering commands snapshot visible order before mutating `TRACKNUMBER`, so
  row re-sorting during mutation cannot change assigned values mid-command.
- Locked tracks keep their existing values but still occupy visible positions.
- For by-disc numbering, locked tracks with valid `DISCNUMBER` still occupy
  their disc sequence positions.
- Tracks with missing, blank, zero, or non-numeric `DISCNUMBER` are not modified
  by `Set Track Numbers by Disc` and do not occupy any disc sequence.
- Deleted-in-table tracks remain visible table rows, so the planned behavior is
  to include them in visible position calculations and allow non-locked deleted
  rows to receive editor-state `TRACKNUMBER` changes. Saving still cannot write
  deleted file-backed rows.

## Product Behavior

### File Menu

1. Existing `Toggle Selected Tracks Lock` stays in place.
2. Immediately below it, show:
   - `Sort Tracks by Filename` when current sort mode is number.
   - `Sort Tracks by Number` when current sort mode is filename.
3. After a divider, show:
   - `Set Track Numbers`
   - `Set Track Numbers by Disc`
   - existing `Set Track Total (...)`
   - existing `Set Track Total by Disc (...)`
4. `Set Track Numbers` and `Set Track Numbers by Disc` are disabled when:
   - save operation is running
   - there are no tracks in the editor window
5. Sort command is disabled when there are no tracks in the editor window.

### Track Table Context Menu

1. Existing add commands stay first.
2. Existing lock command remains before table-management commands.
3. Sort command appears immediately below lock command.
4. Track-number commands appear before existing track-total commands.
5. Enablement and labels match the `File` menu.

### Set Track Numbers

1. Build current visible row order using active sort mode.
2. Assign `TRACKNUMBER` to each non-locked track as `visibleIndex + 1`.
3. Keep locked track values unchanged.
4. Clear external differences for `TRACKNUMBER` on changed non-locked tracks,
   matching existing tag-edit patterns.

### Set Track Numbers By Disc

1. Build current visible row order using active sort mode.
2. Walk rows in visible order.
3. Maintain per-disc counters keyed by valid positive integer `DISCNUMBER`.
4. Skip tracks with invalid or missing `DISCNUMBER`.
5. Increment a disc counter for each visible valid-disc row, including locked
   rows.
6. Assign `TRACKNUMBER` to each non-locked valid-disc row using that disc
   counter.
7. Keep locked and invalid-disc track values unchanged.
8. Clear external differences for `TRACKNUMBER` on changed non-locked tracks.

### Sort Tracks

1. Number mode sorts by numeric `TRACKNUMBER`, then filename, matching current
   behavior.
2. Filename mode sorts by filename, then numeric `TRACKNUMBER`.
3. Missing/non-numeric track numbers sort after numeric values in number mode.
4. Filename comparison uses `localizedStandardCompare`, matching current
   filename tie-break behavior.
5. Sort mode is per editor window; changing sort in one editor window does not
   affect any other open editor window.
6. New or opened editor windows always start in number mode, using numeric
   `TRACKNUMBER`, then filename.
7. Active sort mode affects:
   - table display
   - `Set Track Numbers`
   - `Set Track Numbers by Disc`
   - AppleScript `tracks` element order
   - AppleScript index specifier resolution

### AppleScript

1. Add requested `track sort options` enumeration to `SwiftTag Suite`.
2. Add requested read-write `track sort order` property to `editor window`.
3. Property examples:

```applescript
tell application "SwiftTag"
    set track sort order of front editor window to filename order
    set track sort order of front editor window to track number order
end tell
```

4. Invalid property values return script error when AppleScript supplies them.
5. Sorting is non-mutating tag behavior, so it can run during save unless
   implementation finds a concrete UI consistency issue.

## Destructive / Write-Back Behavior

- Existing data preserved:
  - all tags other than `TRACKNUMBER`
  - all locked-track `TRACKNUMBER` values
  - invalid-disc track values for by-disc numbering
  - picture data and picture metadata
- Existing data replaced:
  - `TRACKNUMBER` editor value on applicable non-locked tracks
- Existing data removed:
  - none
- Save behavior:
  - tag-only saves write new `TRACKNUMBER` values for saved, editable tracks
  - picture-only saves do not write tag changes
  - tags-and-pictures saves write new `TRACKNUMBER` values for saved, editable
    tracks
- Selection behavior:
  - track-number commands ignore current selection and operate on whole editor
    table
  - lock command continues to use selected track IDs
  - save scope remains independent and only affects later save commands

## High-Risk Concerns

### Product / Behavior Risks

- Numbering while sorted by number can change sort keys; implementation must
  snapshot ordered IDs first.
- Locked tracks must keep values while still occupying visible positions.
- Filename sort needs deterministic tie-breaks to keep AppleScript index
  specifiers stable.
- Deleted-row semantics are editor-state only; users may see changed values on
  rows that cannot save back because source file is deleted.
- Sorting during save is low risk but should not disturb save progress or track
  save-status presentation.

### Tooling / Environment Risks

- AppleScript UI tests can be brittle because Apple events depend on runner
  entitlements and timing.
- Prefer unit tests for SDEF parsing, enum-code parsing, and bridge routing.
- Use targeted in-process `NSAppleScript` UI tests only if unit coverage cannot
  prove command integration.
- Xcode MCP test runs can time out; run targeted tests before broader suites.
- No FLAC fixture mutation is needed for pure table-sort and numbering logic.

## Proposed Implementation

### 1. Sort Model

- Add `TrackTableSortMode` with cases:
  - `.number`
  - `.filename`
- Add display helpers:
  - `nextSortMenuTitle`
  - target mode for toggle command
- Replace `Array<Track>.sortedForTrackTableDisplay()` with overload:
  - `sortedForTrackTableDisplay(sortMode:)`
- Keep no-argument overload as `.number` compatibility shim if it reduces test
  churn.

### 2. View Model

- Add `@Published` or stored `trackTableSortMode` in `TagEditorViewModel`.
- Add helpers:
  - `sortedTrackItemsForTable()`
  - `orderedTrackIDsForCurrentSortMode()`
  - `canSortTracks`
  - `sortTracks(by:)`
  - `toggleTrackTableSortMode()`
  - `setTrackNumbersToCurrentTableOrder()`
  - `setTrackNumbersByDiscToCurrentTableOrder()`
- Track-number setters should:
  - snapshot ordered IDs
  - mutate by ID lookup
  - skip locked rows
  - clear `TRACKNUMBER` external differences for changed rows

### 3. SwiftUI Table And Menus

- Pass current sort mode or sorted rows into `TagEditorTrackFileView`.
- Keep `TagEditorTrackFileView` display logic simple; avoid duplicating sort
  rules in view code.
- Add track-number and sort closures/titles/enablement through:
  - `ContentView`
  - `TagEditorView`
  - `TagEditorTrackFileView`
- Add focused values for:
  - `performSetTrackNumbers`
  - `setTrackNumbersTitle`
  - `canPerformSetTrackNumbers`
  - `performSetTrackNumbersByDisc`
  - `setTrackNumbersByDiscTitle`
  - `canPerformSetTrackNumbersByDisc`
  - `performSortTracks`
  - `sortTracksTitle`
  - `canPerformSortTracks`
- Add matching `@FocusedValue` reads and `Button`s in `SwiftTagApp.AppCommands`.

### 4. AppleScript SDEF

- Insert requested `track sort options` enumeration in `SwiftTag Suite`.
- Insert requested `track sort order` property in `editor window`.
- Do not expose `sort tracks` command.

### 5. AppleScript Runtime

- Add `SwiftTagAppleScriptTrackSortOption` parser:
  - accepts `NSAppleEventDescriptor.enumCodeValue`
  - accepts FourChar `NSNumber`
  - maps `tnum` to `.number`
  - maps `tfil` to `.filename`
- Add `invalidTrackSortOptionValue` command error.
- Extend `SwiftTagAppleScriptSessionSnapshot` with current sort mode.
- Extend `SwiftTagAppleScriptSessionBridge` with `sortTracks` closure.
- In `ContentView.configureWindowRouting`, route `sortTracks` to the view-model
  sort method.
- Add controller method:
  - `trackSortOrder(forSessionID:)`
  - `sortTracks(forSessionID:by:)`
- Add script property:
  - `TrackSortOrder`
- Update AppleScript track ordering:
  - `tracks(forSessionID:)`
  - `selectedTrackObjects(forSessionID:)`
  - `indexOfTrack(trackID:forSessionID:)`
  to use snapshot sort mode.

### 6. Documentation

- Update `Docs/UserDocumentation/workflows/tags.html`:
  - track-number commands
  - sort command
  - locked-track behavior
  - current-sort-order effect
- Update AppleScript docs:
  - `automation/applescript-enumerations.html`
  - `automation/applescript-windows.html`
  - `automation/applescript-application.html`
  - remove command page for `sort tracks`
  - update examples to set `track sort order`

## Test Strategy

### Unit Tests

- `TrackTableSortMode` sorting:
  - number mode preserves current numeric ordering and filename tie-break
  - filename mode sorts by filename and uses number tie-break
  - nil/non-numeric track numbers are deterministic
- `TagEditorViewModel.setTrackNumbersToCurrentTableOrder()`:
  - assigns 1-based visible positions in number mode
  - assigns 1-based visible positions after sorting by filename
  - skips locked tracks but counts their visible positions
- `TagEditorViewModel.setTrackNumbersByDiscToCurrentTableOrder()`:
  - assigns per-disc visible positions
  - skips invalid/missing disc tracks
  - skips locked tracks but counts them within disc sequence
- Combination test:
  - start in number mode
  - switch to filename mode
  - set track numbers
  - verify assigned `TRACKNUMBER` values match filename order
  - switch back to number mode and verify table order follows new numbers

### SwiftUI / Source-Order Tests

- `SwiftTagApp.swift` source-order test:
  - lock command before sort command
  - sort command before track-number commands
  - track-number commands before track-total commands
- `TagEditorTrackFileView.swift` source-order test with same context-menu order.
- ViewInspector/actual-view tests for:
  - passed sort title
  - enablement during save
  - no-track disablement
  - closure forwarding for track-number and sort actions

### AppleScript Tests

- SDEF/class-description tests:
  - editor window exposes read-write `track sort order`
  - `sort tracks` command is not exposed
- Parser tests:
  - `tnum` maps to number
  - `tfil` maps to filename
  - invalid FourChar throws script error
- Controller/bridge tests:
  - property setter calls bridge sort closure with target session and requested mode
  - missing editor window returns existing no-window style error
  - sort during save does not mutate tags or save state
- Track ordering tests:
  - AppleScript `tracks` order follows number mode
  - after sort by filename, `tracks` order and index specifiers follow filename
    mode

### Verification Commands

Prefer Xcode MCP:

1. `XcodeRefreshCodeIssuesInFile` for changed Swift files.
2. `BuildProject`.
3. `RunSomeTests` for:
   - `SwiftTagTests/SwiftTagTests`
   - `SwiftTagTests/TrackStatusViewInspectorTests`
   - `SwiftTagTests/SwiftTagAppleScriptTests`
4. Targeted `SwiftTagUITests` AppleScript harness only if unit/SDEF coverage is
   not enough for command integration.

## Acceptance Criteria

- `File` menu has requested labels and ordering.
- Track-table context menu has requested labels and ordering.
- Track-number commands are disabled during save and when table is empty.
- Sort command is disabled when table is empty.
- `Set Track Numbers` uses current visible table order.
- `Set Track Numbers by Disc` uses current visible table order per valid disc.
- Locked tracks are never modified by new numbering commands.
- Sort mode toggles visible table order between number and filename.
- AppleScript `track sort order` values `track number order` and `filename order`
  match UI sort behavior.
- AppleScript track element order and index specifiers match current table sort
  mode.
- Tests cover sort plus numbering combination.
- Build passes.

## Open Questions

- None. Deleted-in-table semantics are explicitly planned above; adjust before
  implementation if deleted rows should instead be skipped like existing
  track-total commands.
