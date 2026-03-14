# Add Track Status Plan

## Goal
Add a leftmost `Status` column to the tracks table that displays a square status icon for each loaded track file, backed by file-change monitoring and editor-vs-file difference detection, so the Tag Editor can show track state accurately and gate save behavior accordingly, including a read-only load mode.

## Scope
In scope:
- Add a new `Status` table column to the track list in `TagEditorTrackFileView`.
- Position the new column as the leftmost column in the tracks table.
- Size the column so its width matches the rendered row height, allowing a square icon per row.
- Show a status icon only for rows backed by an associated track file.
- Add hover help for the status icon based on per-track status state.
- Monitor loaded track files for macOS file-system changes that affect status.
- Detect editor-vs-file differences for tags and pictures separately.
- Gate `Save`, `Save Tags...`, and `Save Pictures...` availability based on the relevant difference state and read-only mode.
- Add a read-only FLAC load path and propagate read-only behavior through the editor UI.
- Define the status/data contracts needed so the table, save commands, and file-monitoring logic share one source of truth.
- Add targeted tests for status visibility, difference-state mapping, save gating, and read-only behavior.

Out of scope:
- Changing FLAC write semantics beyond save enablement rules.
- Adding status icons to views outside the tracks table.
- Adding non-icon status text into the table cells.
- Implementing conflict resolution or merge UI after file changes are detected.
- Adding background directory-wide file watching beyond the currently loaded track files.

## Confirmed Decisions
- Loaded track files should be monitored for macOS file changes, primarily to determine per-track status and the icon shown in the `Status` column.
- The implementation should most likely use `DispatchSourceFileSystemObject` to observe file modification, delete, and rename events for loaded track files.
- Unless later design instructions change it, the default status icon is `fish.fill`.
- When the Tag Editor contains user-made tag or picture differences relative to the source file, the status icon is `fish`.
- When macOS-side file changes create differences between the editor state and the source file, the status icon is `exclamationmark.triangle`.
- When a track/editor session is loaded read-only, the status icon is `lock.fill`.
- `Save Tags...` is unavailable when there are no editor/file differences in tags.
- `Save Pictures...` is unavailable when there are no editor/file differences in pictures.
- `Save` via Command-S is unavailable when there are no editor/file differences relevant to the current save settings and selected payload behavior.
- The File menu should add `Load FLAC files (read-only)...` after `Load FLAC files...` with shortcut Shift-Command-L.
- In read-only mode, editable fields are disabled, album image wells are disabled, and save/write operations are not allowed.
- Rows without an associated track file should render a fully blank status cell.
- The status column can start without an explicit fixed width or height rule; initial implementation should rely on the system image drawing/containment behavior and refine sizing later only if needed.
- The status column should intentionally use no header text (empty string) instead of `Status`.
- When a macOS file change is detected, the app should immediately re-read the file to classify the resulting differences.
- If a loaded file has been deleted, the corresponding filename text in the tracks table should render strikethrough and red.
- If one or more tags differ from the file after a macOS-side change, the associated editor field text should render italic and red.
- If the track title differs from the file, the track title text for that track row should render italic and red.
- If pictures differ from the file, a red overlay should be drawn in the album-art image well.
- Status-icon hover help for macOS-side differences should list the differences as newline-separated `tag: value` entries, where `value` is the current file value.
- Mixed writable and read-only tracks in one editor window should be supported.
- The tracks table should keep the current lock labels: `Lock Selected Track` / `Lock Selected Tracks`, `Unlock Selected Track` / `Unlock Selected Tracks`, and `Toggle Selected Tracks Lock` for mixed locked/unlocked selections.
- Activating that context-menu item flips the lock state of each selected row.
- The lock/unlock action should use shortcut Control-L.
- When a locked row is unlocked, its icon returns to the appropriate non-locked status icon.
- When a row is locked, `lock.fill` replaces its current status icon.
- Locked rows are disabled, but the lock icon for a locked row remains enabled except during save operations.

## Dependencies And Constraints
- The tracks table currently lives in [TagEditorTrackFileView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorTrackFileView.swift) and only renders `Title` and `Filename` columns today.
- `TagEditorView` passes only `trackItems`, selection, and title bindings into the track table, so any status UI will require additional per-track status data or a closure-based lookup passed down from [TagEditorView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorView.swift).
- The current `Track` model in [Track.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Shared/Models/Track.swift) exposes `sourceFileURL`, which is the current reliable indicator of whether a row has an associated track file.
- Save command availability is currently driven in [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift) by `canSave(payload:)`, which today checks only whether the selected scope has imported FLAC tracks. The new status/difference rules must replace or extend that gating.
- The menu commands are currently defined in [SwiftTagApp.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/SwiftTagApp.swift), so adding a read-only load command and refining save enablement requires command-layer integration as well as editor-state integration.
- The editor already has a broad `.disabled(isSaveOperationRunning)` path in [TagEditorView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorView.swift). Read-only mode needs to coexist cleanly with save-in-progress disabling without obscuring the source of truth.
- The current editor layout assumes broad view-level enable/disable behavior in places. Supporting mixed locked and unlocked rows in one window means disabling likely needs to move to row-scoped and field-scoped conditions instead of a single editor-wide read-only flag.
- File monitoring must work with security-scoped file access and file URLs that were originally imported through the existing FLAC import flow.
- `DispatchSourceFileSystemObject` monitoring works from open file descriptors. The implementation must manage descriptor lifecycle carefully so per-track watchers are created, updated, and torn down with the loaded session instead of leaking across editor windows.
- The latest design decision defers explicit row-height sizing work for now. The initial table-column implementation should rely on the system icon’s natural containment and revisit exact sizing only if rendering proves unacceptable.
- Hover help should exist only when an icon exists, which means rows without an associated file should not expose misleading blank-cell help text.
- Difference tracking needs to distinguish tags from pictures so save-command enablement can reflect the chosen payload correctly.
- Read-only load mode must preserve import/read behavior while preventing subsequent writes, including keyboard shortcuts and menu-triggered save flows.
- Immediate file re-read after a watcher event means the app needs a reliable mapping from file values back to editor fields so red/italic difference styling can be applied to the correct controls.
- Per-track lock state and per-track external-difference state can overlap in one window, so precedence rules for icon choice, field disablement, and context-menu labeling need to be centralized.

## High-Risk Concerns

### Product Or Behavioral Risks
- If status state is inferred only from whether a title field changed, the column will drift from the required source of truth for tag differences, picture differences, macOS file changes, and read-only state.
- If rows without `sourceFileURL` still reserve visible icon affordances or help text, the table will imply file-backed state that does not exist.
- If the status-column width is chosen independently from row height, icons can render non-square or appear visually off-center relative to the row.
- If tag differences and picture differences are collapsed into one boolean too early, `Save Tags...`, `Save Pictures...`, and `Save` cannot be enabled correctly.
- If external file changes are not re-read or reconciled carefully, the app can show `exclamationmark.triangle` without a reliable basis for whether tags, pictures, or both diverged.
- If read-only mode is treated as only a UI disable flag, write commands may still remain reachable through menu items or keyboard shortcuts.
- If mixed locked and unlocked rows are not handled per row, locking one track could incorrectly disable unrelated editable tracks in the same editor window.
- If file-difference styling is applied only at a coarse editor level, users will not be able to see which specific tags, titles, filenames, or pictures diverged.

### Tooling, Environment, Or Filesystem Risks
- SwiftUI `Table` behavior on macOS can make exact row metrics awkward to verify through unit tests alone, so some sizing verification may need compile-time inspection plus lightweight manual/UI confirmation.
- UI test assertions on hover help are often more brittle than view-model or helper tests; most automated coverage should live in status-mapping helpers rather than pointer-driven UI automation.
- File-system event delivery can be noisy or incomplete across rename/delete/update combinations, so watcher logic should treat events as invalidation signals and re-evaluate track state rather than assuming one event maps to one exact status.
- Security-scoped bookmarks and file-descriptor-backed watchers can be awkward to exercise in tests, so monitoring coverage will likely rely on helper abstractions and copied fixtures rather than direct end-to-end sandbox assertions.

## Implementation Phases

### 1. Define the track-status and difference-state model
- Introduce a dedicated per-track status model that can represent at least:
  - default synced/file-backed state
  - user-made differences between editor and file
  - macOS-side file changes that invalidate the editor/file match
  - locked/read-only state
  - no-associated-file state
- Represent tag differences and picture differences separately so command enablement can answer:
  - are there tag changes to write?
  - are there picture changes to write?
  - does the currently configured general save action have anything to write?
- Model per-track lock state independently so one editor window can contain both locked and unlocked rows.
- Define precedence rules for presentation and behavior when a track is both locked and externally different:
  - icon shown
  - whether the row is editable
  - whether difference styling remains visible
- Introduce a UI-facing `TrackStatusPresentation` or equivalent mapping payload that centralizes:
  - icon identity
  - hover/help string
  - accessibility label if useful
- Encode the confirmed icon mapping:
  - default: `fish.fill`
  - user differences: `fish`
  - macOS file differences: `exclamationmark.triangle`
  - read-only: `lock.fill`
- Encode the rule that rows without an associated track file return no status icon or help.

### 2. Add file monitoring for loaded track files
- Add a file-monitoring layer for currently loaded track files, most likely using `DispatchSourceFileSystemObject`.
- Observe at least modification, delete, and rename events for each loaded file.
- Scope monitoring to the currently loaded editor session and tear it down when tracks change, windows close, or sessions reload.
- Treat file-system events as signals to immediately re-read the affected file and refresh track/file comparison state.
- Ensure the monitoring layer can operate with the file-access model already used for imported FLAC files, including security-scoped access where needed.
- Classify at least these outcomes after re-read:
  - file deleted
  - tag differences
  - title difference
  - picture differences
- Preserve the latest file-side values needed for hover help and difference styling.

### 3. Add the leftmost status-icon column
- Update [TagEditorTrackFileView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorTrackFileView.swift) to insert a new leftmost status `TableColumn` before `Title`, with an intentionally empty header string.
- Render a square icon cell for rows whose status presentation is non-`nil`.
- Keep the cell visually minimal so the column functions as a status indicator rather than a secondary content column.
- Preserve existing title editing and filename display behavior.

### 4. Make the status cell square to the row
- Start with a simple system-image cell without explicit width or height constraints.
- Verify that the icon renders cleanly and remains visually contained within the row.
- If the natural layout proves insufficient, follow up by introducing a shared sizing rule in implementation rather than blocking the first version on exact square metrics.

### 5. Thread status data and read-only state through the editor stack
- Update [TagEditorView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorView.swift) to pass a status-presentation lookup into the track table.
- Add the corresponding status, difference, and read-only lookup points in [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift) or adjacent helpers.
- Propagate lock/read-only state at the row and field level so locked tracks can be disabled without disabling unrelated unlocked tracks in the same window.
- Keep session-level read-only loads supported as a convenience path that initializes all imported tracks as locked/non-writable.
- Keep the view-model contract aligned with one source of truth for track edit/file status instead of deriving status separately inside the SwiftUI view.
- Add data needed to style externally changed values:
  - track filename strike/red state
  - track title italic/red state
  - tag-field italic/red state
  - album-art red-overlay state for picture differences

### 6. Add hover help behavior
- Attach `.help(...)` to the rendered status icon using the status presentation’s hover text.
- Do not attach help to empty placeholder cells for tracks without associated files.
- For macOS-side differences, build hover help from newline-separated `tag: value` entries using the current file values.
- Map each supported state to its chosen icon and exact hover/help message in one centralized place so the table and any future command/UI surfaces stay synchronized.

### 7. Gate save commands from actual differences
- Replace the current save enablement checks in [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift) so command availability reflects:
  - read-only mode blocks all save/write actions
  - `Save Tags...` requires tag differences in the active save scope
  - `Save Pictures...` requires picture differences in the active save scope
  - `Save` requires differences that match the current save settings and payload behavior
- Ensure the same rules drive menu-item enablement and command-handler guards so disabled actions cannot still execute through shortcuts.
- Keep the scope logic aligned with existing selected-track vs all-tracks save behavior.
- Exclude locked tracks from writable save scopes unless a later design explicitly states otherwise.

### 8. Add read-only load flow
- Update [SwiftTagApp.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/SwiftTagApp.swift) to add `Load FLAC files (read-only)...` after `Load FLAC files...` with Shift-Command-L.
- Add the corresponding `ContentView` import path so a session can be initialized as read-only from the start.
- Preserve existing FLAC import behavior for metadata and picture loading while marking the resulting editor session as non-writable.
- Ensure read-only sessions show `lock.fill`, disable editable fields, disable album-art wells, and disallow all save/write commands.
- Implement mixed lock support so the same internal mechanism can back both full read-only loads and per-row lock/unlock toggles.

### 9. Add track-table lock/unlock controls
- Add a context menu to the tracks table with a lock toggle item derived from the current selection.
- Use these labels:
  - `Lock Selected Track` or `Lock Selected Tracks` when all selected rows are unlocked
  - `Unlock Selected Track` or `Unlock Selected Tracks` when all selected rows are locked
  - `Toggle Selected Tracks Lock` when the selection contains a mix of locked and unlocked rows
- Apply the action to each selected row, flipping its current lock state.
- Bind the action to Control-L.
- Ensure locked rows are disabled while keeping the lock icon itself active unless save-in-progress state disables the whole interaction path.

### 10. Apply difference styling to affected UI
- Draw deleted filenames in the tracks table with red strikethrough styling.
- Draw externally changed title text in the tracks table italicized and red.
- Draw externally changed editor tag-field text italicized and red for the affected controls.
- Draw a red overlay in the album-art image well when picture differences are detected.
- Keep user-made unsaved differences visually distinguishable from macOS-side differences if the design later requires both to be visible at once.

### 11. Verify and refine behavior
- Confirm that the new column remains leftmost after selection, editing, import, and read-only load flows.
- Confirm that rows with `sourceFileURL == nil` render an empty status cell without broken layout.
- Confirm that editable fields remain enabled for writable rows and disabled for locked rows.
- Confirm that album-art wells remain enabled for writable rows/sessions and disabled for locked or read-only tracks as designed.
- Confirm that save-command availability changes as editor/file differences appear or disappear.
- Confirm that file-monitoring events transition status as intended for modified, renamed, and deleted loaded files.
- Confirm that deleted files render filename strike/red styling.
- Confirm that externally changed title and tag fields render italic/red styling.
- Confirm that picture differences render the album-art red overlay.
- Confirm that lock/unlock context-menu labeling matches selected-row state.

## Suggested File Updates
- Update [TagEditorTrackFileView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorTrackFileView.swift)
- Update [TagEditorView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorView.swift)
- Update [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift)
- Update [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift)
- Update [SwiftTagApp.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/SwiftTagApp.swift)
- Possibly update [Track.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Shared/Models/Track.swift) if per-track monitoring or read-only metadata belongs on the model
- Add a focused file-monitoring helper/service if descriptor lifecycle management should be kept out of the view model
- Update album-art well related views such as [TagEditorAlbumView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorAlbumView.swift) and possibly [AlbumArtWellView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/AlbumArt/AlbumArtWellView.swift) for picture-difference overlay and lock-state disablement
- Update [SwiftTagTests.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTagTests/SwiftTagTests.swift) or split focused tests into a dedicated track-status test file

## Test Strategy
- Prefer unit tests first:
  - rows with `sourceFileURL` produce the expected status presentation for synced, user-dirty, external-change, and read-only states
  - rows without `sourceFileURL` produce no status presentation
  - tag differences and picture differences are tracked independently
  - save gating returns the expected answers for `Save`, `Save Tags...`, and `Save Pictures...`
  - read-only mode blocks all save actions regardless of differences
  - file-monitoring helper logic translates modification, rename, and delete invalidations into the expected refresh behavior
  - immediate file re-read classifies deleted files, changed tag values, changed titles, and picture differences correctly
  - mixed lock/unlock selections yield the expected context-menu label and lock-toggle results
- Add targeted view-model or helper tests where practical:
  - the track-status lookup uses the intended source of truth rather than recomputing unrelated edit heuristics in the view
  - editor edits flip tag or picture difference state as appropriate
  - file reload or invalidation updates status after external file changes
  - read-only imports initialize editor state correctly
  - row-level locking disables only the intended tracks
- Add limited UI verification:
  - the `Status` column appears as the leftmost table column
  - writable file-backed rows show an icon
  - non-file-backed rows show no icon
  - read-only loads disable fields and album-art wells
  - save menu items disable when no relevant differences exist
  - deleted filenames render strikethrough and red
  - externally changed title and tag fields render italic and red
  - picture differences render a red album-art overlay
  - the tracks-table context menu shows `Lock Selected Track` / `Lock Selected Tracks`, `Unlock Selected Track` / `Unlock Selected Tracks`, or `Toggle Selected Tracks Lock` as appropriate
  - hover help appears for a status icon once a test seam or stable state fixture exists
- Use `BuildProject` for compile validation and prefer targeted tests over broad UI automation.

## Current Implementation Status (2026-03-14)
- Implemented:
  - Per-track status model types are in place in `TrackStatus.swift` (`TrackFileSnapshot`, `TrackExternalDifferences`, `TrackStatusPresentation`, `TrackFileMonitorEvent`).
  - `Track` now carries status-related state (`latestFileSnapshot`, `externalDifferences`, `isLocked`) in `Track.swift`.
  - `DispatchSourceFileSystemObject` monitoring exists in `TrackFileMonitor.swift` with write/delete/rename handling and security-scoped URL support.
  - `TagEditorViewModel` now computes status icon/help (`fish.fill`, `fish`, `exclamationmark.triangle`, `lock.fill`), refreshes file state on monitor events, and tracks external tag/picture differences.
  - The tracks table has a new leftmost icon column, lock context menu wiring, title/file external-difference styling, and lock-driven row disablement in `TagEditorTrackFileView.swift`.
  - Read-only import flow is wired end-to-end (`Load FLAC files (read-only)...`, Shift-Command-L, locked import path) across `SwiftTagApp.swift` and `ContentView.swift`.
  - Save enablement now uses difference-aware gating in `ContentView.canSave(payload:)` via `TagEditorViewModel.canSave(...)`.
  - External-difference visuals are in place for title, filename (red + strikethrough on delete), tag fields (italic + red), and album art overlay.
  - Unit coverage for status mapping, save gating, lock behavior, and file-monitor refresh logic has been added in `SwiftTagTests.swift`.
- Partially implemented:
  - No additional partial implementation gaps identified for header/label wording after formalizing current behavior as intended.
- Not fully covered yet:
  - UI automation coverage for the new status column/icon/help behaviors and lock-menu label variants is still limited.

## Open Questions
- No new product-behavior questions identified during this review.

## Acceptance Criteria
- The tracks table includes a leftmost status-icon column with an intentionally empty header.
- The status column width matches the intended row height closely enough for the rendered icon area to be square.
- Only rows with an associated track file can display a status icon.
- Rows without an associated track file do not display a status icon or misleading hover help.
- Loaded track files are monitored for modification, rename, and delete events for status purposes.
- Default tracked rows use `fish.fill` unless another confirmed state overrides it.
- Rows with user-made editor/file differences use `fish`.
- Rows with macOS-side file differences use `exclamationmark.triangle`.
- Read-only sessions use `lock.fill`.
- The title and filename columns continue to function as before.
- Hover help is shown for displayed status icons and is driven by centralized status presentation data.
- Rows without an associated track file render a fully blank status cell.
- The initial status-column implementation works without requiring explicit width or height sizing for the system icon.
- `Save Tags...` is unavailable when there are no tag differences in the active save scope.
- `Save Pictures...` is unavailable when there are no picture differences in the active save scope.
- `Save` is unavailable when there are no differences relevant to the current save settings or when the session is read-only.
- The File menu contains `Load FLAC files (read-only)...` after `Load FLAC files...` with Shift-Command-L.
- Read-only loads disable editable fields and album-art wells and prevent all write/save actions.
- Mixed locked and unlocked tracks are supported in one editor window.
- The tracks-table context menu exposes `Lock Selected Track` / `Lock Selected Tracks`, `Unlock Selected Track` / `Unlock Selected Tracks`, or `Toggle Selected Tracks Lock` based on selected-row lock state and toggles each selected row with Control-L.
- Locked rows are disabled while their lock icons remain enabled except during save operations.
- On macOS-side file deletion, the corresponding filename renders red with strikethrough.
- On macOS-side tag or title differences, the affected editor text renders italic and red.
- On picture differences, the album-art image well renders a red overlay.
- Status-icon hover help for macOS-side differences lists newline-separated `tag: value` entries using the current file values.
- The implementation is covered by targeted tests for status visibility, difference tracking, save gating, read-only behavior, and compile verification.

## Remaining Implementation Steps
1. Add command-handler guard logic so save actions short-circuit when no relevant differences exist, ensuring behavior matches enablement rules even if a command path is invoked while menu state is stale.
2. Add targeted UI verification for:
   - leftmost status-icon column visibility and icon presence/absence by row type,
   - lock-menu label variants for unlocked/locked/mixed selections using current implemented wording,
   - read-only import command discoverability and disabled editing state.
3. Run `BuildProject` and the affected targeted tests after the final behavior-alignment changes above.
