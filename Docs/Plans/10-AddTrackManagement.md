# Add Track Management Plan

## Goal
Implement track-table and editor command enhancements for track numbering display, additive FLAC import, bulk track total management, destructive reload/remove safeguards, drag and drop add flows, and File menu parity/shortcuts.

## Scope
In scope:
- Add a read-only track number column labeled `#` in the tracks table (after status icon, before `Title`) and make it default ascending sort.
- Add `Auto update Track Total` setting in `TagWriteSettingsView` after `Zero pad Disc Number/Total`.
- Add `Update Track Total on Locked Tracks` setting in `TagWriteSettingsView` after `Auto update Track Total`.
- When auto-update is on:
- Disable total-tracks editor field.
- Keep total-tracks field synced to loaded track count excluding deleted tracks still present in table.
- Apply track-total value across tracks based on `Update Track Total on Locked Tracks`.
- Add `Set Track Total (*)` command (table context menu, total-tracks field context menu, File menu).
- Add additive import commands:
- `Add FLAC files...`
- `Add FLAC files (read-only)...`
- Context menu access in track table and main editor window.
- File menu entries after load commands.
- Duplicate-file prevention before add using bookmark-resolution identity.
- Add drag and drop `.flac` support to table and editor container with additive behavior.
- Option-key drop variant always imports as locked, even with other modifiers.
- Add `Reload Selected Track(s)` command with selection-aware label and guarded destructive behavior.
- Add `Remove Selected Track(s)` command with selection-aware label and guarded destructive behavior.
- Disable reload/remove selected-track commands when no tracks are selected.
- Add File menu entries for reload/remove with required separators and enablement parity.
- Update File menu shortcuts:
- `Load FLAC files (read-only)...` -> Option+Command+L
- `Add FLAC files...` -> Shift+Command+L
- `Add FLAC files (read-only)...` -> Shift+Option+Command+L
- Introduce/extend shared destructive-change confirmation flow for load/reload/remove/close/quit paths.

Out of scope:
- FLAC bridge C-layer changes.
- Album art editing behavior changes unrelated to reload/remove protection.
- Save pipeline semantics beyond new total-track management and destructive-action guard integration.
- Broad settings UI redesign.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/9-AddUIFeedbackSettings.md`.
- Current implementation files reviewed:
- `SwiftTag/ContentView.swift`
- `Features/TagEditor/TagEditorView.swift`
- `Features/TagEditor/TagEditorTrackFileView.swift`
- `Features/TagEditor/TagEditorCoreTagsView.swift`
- `Features/TagEditor/TagEditorViewModel.swift`
- `Features/Settings/TagWriteSettingsView.swift`
- `SwiftTagApp.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Fixture-first check completed for FLAC behavior:
- `SwiftTagTestFiles/test.flac`
- `SwiftTagTestFiles/test-with_padding.flac`
- Constraints accounted for:
- Security-scoped bookmark handling for import/save/reload flows.
- Existing external file monitoring (`TrackFileMonitor`) behavior.
- Existing focused command routing and File menu command model.

## Dependencies And Constraints
- Add/import commands must preserve security-scoped bookmark creation and later re-resolution.
- Duplicate detection must use bookmark-resolution identity for already-loaded tracks and incoming files.
- Track table currently uses `Table(trackItems, selection:)`; default sort and column order must stay stable.
- Command enablement must be exposed through `FocusedValues` so File menu mirrors focused editor state.
- Destructive operation guard must work for:
- In-view actions (load/reload/remove).
- App lifecycle close/quit behaviors.
- Selection semantics must be explicit when selection is empty vs non-empty.

## High-Risk Concerns
### Product / Behavioral Risks
- Conflicting assumptions around total-tracks scope and deleted-track exclusion can cause silent metadata overwrites.
- Reload and remove operations can destroy local unsaved edits if guard criteria are incorrect.
- Additive import with duplicate detection can accidentally skip valid files if bookmark identity matching is incomplete.
- Drag-and-drop target scoping can interfere with text drag/drop in editors if drop handlers are attached too broadly.

### Tooling / Environment / Sandbox Risks
- macOS modifier-key detection during drop (`Option`) can differ by event source and needs deterministic fallback behavior.
- App/window close interception for custom discard alerts may require AppKit integration points not yet centralized.
- Security-scoped bookmark edge cases (stale bookmark or move/rename) can affect reload/add duplicate checks.

## Destructive / Write-Back Behavior
- Preserved:
- Existing save format/padding behavior and FLAC write mapper canonicalization rules.
- Existing locked-track editing protections except where the new locked-track total-update setting explicitly permits updates.
- Replaced/extended:
- `importFlacFiles` currently replaces all loaded tracks; additive import path will append non-duplicate tracks.
- New reload/remove commands introduce explicit destructive guard flow.
- Removed:
- No existing persisted data removal by default; remove action only affects in-memory editor track list unless separately saved.

Write-back specifics to enforce in implementation:
- `Set Track Total (*)` and auto-update behavior must honor `Update Track Total on Locked Tracks` (default Off).
- Auto-update track-total count must exclude tracks whose source file is currently deleted/unavailable and marked as deleted in table state.
- Reload overwrites current in-memory tag/picture edits from file for eligible tracks with diffs.
- Remove deletes selected tracks from current editor session state (not from disk).

## Implementation Phases
1. Track Table Data/Presentation
- Add `#` read-only column after status icon and before `Title`.
- Bind display to normalized `trackNumber` tag value for each row.
- Set default table sort to `trackNumber` ascending with deterministic fallback for empty/non-numeric values.
- Add/adjust tests for column order and displayed values.

2. Settings + Track Total Automation
- Add new `@AppStorage` key/default for `Auto update Track Total` (default Off).
- Add new `@AppStorage` key/default for `Update Track Total on Locked Tracks` (default Off).
- Add toggle UI in `TagWriteSettingsView` after zero-pad disc toggle.
- Add ContentView/ViewModel wiring so auto mode:
- Disables total-tracks text field.
- Recomputes total-tracks on load/add/remove operations using non-deleted track count only.
- Applies track-total key value per strategy/formatting rules, including locked tracks only when enabled by the new setting.
- Add explicit command `Set Track Total (*)` with enablement and placements.

3. Additive Import Commands And Duplicate Prevention
- Split import behavior into:
- Replace (existing load)
- Additive append (new add commands/context menu/drop)
- Add focused actions for add and add-read-only commands.
- Add File menu entries and shortcuts.
- Implement duplicate guard before import add using bookmark-resolution identity strategy.
- Add context menu entries in table and editor container.

4. Drag & Drop Add Flows
- Add `.flac` drop handlers to track table container and approved editor-surface container.
- Ensure drop handlers are not attached to tag-edit text controls.
- Implement option-key-detected drop path that always forces locked add.
- Reuse additive import and duplicate filtering logic.

5. Reload/Remove Commands + Destructive Guard
- Add selection-aware command labels for reload/remove in context menus and File menu.
- Enable only when command preconditions are satisfied and disable when selection is empty.
- Add reload behavior to refresh selected tracks from file only when diffs exist.
- Add remove behavior for selected tracks.
- Create centralized destructive confirmation model that:
- Reuses for load/reload/remove/close/quit destructive transitions.
- Suppresses alert for external-only diffs with no in-editor edits.
- Shows pending unsaved counts (`N tag edits`, `M picture edits`) when applicable.
- Supports context-specific confirm button labels (`Quit`, `Close Window`, `Reload File(s)`, `Load File(s)`, etc.).

6. Command Plumbing And Menu Structure
- Extend `FocusedValues` with new action/title/enablement entries.
- Update `AppCommands` File menu ordering and separators exactly as requested.
- Update keyboard shortcuts and resolve conflicts.

7. Validation And Hardening
- Verify compile/build.
- Run targeted tests for modified areas.
- Add new tests for additive import, bookmark-based duplicate prevention, reload/remove enablement, and total-tracks automation behavior.

## Test Strategy
Order (per guide):
1. Unit tests (`SwiftTagTests`) for:
- Duplicate detection rules (bookmark-resolution identity).
- Auto total-tracks recomputation/apply logic (including deleted-track exclusion and locked-track-setting behavior).
- Reload eligibility logic (diff-aware, selection-aware, external-only bypass conditions).
- Destructive guard decision model (when to show prompt, edit counts, confirm button title).
2. Service/fixture tests with copied FLAC fixtures for:
- Additive import append behavior and lock-on-add path.
- Reload behavior replacing in-memory tags/pictures from file snapshots.
3. ViewInspector tests (`TrackStatusViewInspectorTests` or new focused file) for:
- Table column order includes `#` between status and `Title`.
- Total-tracks field disabled when auto-update enabled.
- Context menu command presence/enablement based on selection and state.
4. Targeted UI tests only if needed for:
- File menu keyboard shortcuts and routed command execution.
- Drag/drop integration if ViewInspector cannot validate reliably.

Validation tools:
- `XcodeRefreshCodeIssuesInFile` on touched files.
- `BuildProject` for compile validation.
- `RunSomeTests` for targeted tests.

## Acceptance Criteria
- Track table shows read-only `#` column after status and before `Title`, default-sorted ascending by track number.
- `Auto update Track Total` toggle exists in settings and defaults to Off.
- `Update Track Total on Locked Tracks` toggle exists after auto-update toggle and defaults to Off.
- Auto-update keeps total track value in sync with non-deleted track count and updates track-total values according to formatting/key rules.
- Locked tracks are included/excluded from total-track updates based on `Update Track Total on Locked Tracks`.
- `Set Track Total (*)` appears in required context menus and File menu, with required enablement gating.
- Additive import commands exist in context menus and File menu; add-read-only variant imports locked tracks.
- Add commands append without replacing existing tracks and skip already loaded files using bookmark-resolution duplicate detection.
- Drag/drop `.flac` on table/main editor performs additive import; option-key drop always adds locked.
- Reload selected and remove selected commands exist with singular/plural labels and are disabled when no tracks are selected.
- Destructive confirmation is shown for in-editor unsaved edit loss scenarios and reused for load/reload/remove/close/quit flows, with action-specific confirm labels.
- Destructive confirmation includes `N tag edits` and `M picture edits` counts when applicable.
- Required menu separators and keyboard shortcuts are updated as specified.

## Confirmed Decisions
- `Auto update Track Total` defaults to Off.
- Add `Update Track Total on Locked Tracks` after `Auto update Track Total`; default Off.
- Auto-update and `Set Track Total (*)` honor `Update Track Total on Locked Tracks` to decide locked-track inclusion.
- Duplicate detection for add flows is based on bookmark resolution identity.
- `Reload Selected Track(s)` and `Remove Selected Track(s)` are disabled when no tracks are selected.
- Destructive alerts display counts (`N tag edits`, `M picture edits`).
- Destructive protection scope is limited to load/reload/remove/close/quit.
- Option key always forces locked import for drag/drop add even when combined with other modifiers.
- Deleted files that remain in the track table are excluded from auto-update track-total counting and resulting updates.

## Open Questions
- None currently.
