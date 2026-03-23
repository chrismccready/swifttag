# Add Multi Picture Per Track Support Plan

## Goal
Implement per-track multi-picture album-art management with shared in-memory picture pooling, selection-aware pinning controls, picture browser navigation/commands, save-setting overrides, and writeback behavior that supports multiple pictures per type while preserving lock protections and explicit UI feedback.

## Scope
In scope:
- Replace single-picture-per-type editor state with a pooled picture model that supports:
- Multiple pictures per type per track.
- Shared image references across tracks without duplicating image bytes in memory.
- Per-track ordered references to pooled pictures.
- Type-level constraints for FLAC type `1` (single picture, PNG only).
- Add album-art browser behavior updates in `AlbumArtSheetView`:
- Type list labels show `Name (count)` where `count` is unique picture count for the active track scope.
- Duplicate cross-type warning presentation using the configured mismatch color and italicized type labels.
- Accessory toolbar for album-level pinning (`Pin Album Pictures`) with scope text (`All Tracks` or `Selected Tracks (count)`).
- Destination accessory toolbar for per-picture pinning (`Pin Track Pictures`), picture navigation controls, import/remove/export controls, and enablement rules.
- Add settings toggles in `TagWriteSettingsView`:
- `Save Front Cover to all Tracks` (default On).
- `Save all Pictures to all Tracks` (default Off).
- Enforce setting precedence:
- `Save all Pictures to all Tracks` forces album-level pinning behavior.
- `Save Front Cover to all Tracks` forces per-picture front-cover pinning behavior and disables conflicting controls.
- Update main album-art well behavior:
- Replace single-click sheet open with double-click.
- Add context menu action `Show Picture Browser`.
- Add View menu command `Show Picture Browser` / `Hide Picture Browser` with `Command-1` toggle behavior.
- Update import/reload/remove/save state handling:
- Import merges pictures into a deduplicated pool.
- Track removal removes references and garbage-collects unreferenced pooled pictures.
- Save writes per-track picture lists (ordered) and keeps existing bridge-level picture rewrite semantics.
- Add locked-track guardrails and alerts for pin/edit actions that cannot execute because one or more selected tracks are locked.
- For remove-picture with out-of-scope references, remove from selected affected tracks and present a mismatch-color informational overlay instead of an alert.

Out of scope:
- FLAC bridge C-layer format changes unless required to satisfy ordering rules not achievable from Swift-side record ordering.
- Unrelated tag-editing flows, diff formatting outside picture-specific UI states, or unrelated settings redesign.
- Multi-window/global shared picture state across editor sessions.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/10-AddTrackManagement.md`.
- Current implementation files reviewed:
- `SwiftTag/ContentView.swift`
- `SwiftTag/SwiftTagApp.swift`
- `Features/AlbumArt/AlbumArtTypes.swift`
- `Features/AlbumArt/AlbumArtViewModel.swift`
- `Features/AlbumArt/AlbumArtSheetView.swift`
- `Features/AlbumArt/AlbumArtWellView.swift`
- `Features/TagEditor/TagEditorAlbumView.swift`
- `Features/TagEditor/TagEditorViewModel.swift`
- `Features/FlacImport/FlacImportMapper.swift`
- `Features/FlacImport/FlacWriteMapper.swift`
- `Shared/Models/Track.swift`
- `Shared/Models/TrackStatus.swift`
- `Shared/Models/SaveSettings.swift`
- `FlacMetadataService.swift`
- `SwiftTagTests/SwiftTagTests.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Fixture-first check completed:
- `SwiftTagTestFiles/test.flac`
- `SwiftTagTestFiles/test-with_padding.flac`
- Constraints accounted for:
- Security-scoped bookmark requirements for import/reload/save.
- Existing save/diff pipeline currently compares a global `[Int: Data]` picture map and must be made track-specific.
- Existing FLAC write path removes all picture blocks before appending new picture blocks.
- Existing `AlbumArtViewModel` and `Track.flacPicturesByType` are single-picture-per-type and require structural replacement.

## Dependencies And Constraints
- `FlacMetadataService.readTags` already returns ordered `[FlacPictureRecord]`; order-sensitive behavior must preserve this order through import and write.
- Bridge currently enforces type-1 PNG icon legality and removes all picture blocks before write; Swift-side payload generation must satisfy this invariant.
- Existing save eligibility and diff logic (`TagEditorViewModel`) assumes one shared picture set for all tracks; per-track picture payloads and diffing must be refactored without regressing tag-only saves.
- Selection semantics are centralized in `TagEditorViewModel.selectedTrackIDs`; all pinning actions must use that as source of truth.
- Locked tracks are currently excluded from saves and most edits; new pinning/edit controls must use equivalent lock gating and explicit alerting.
- Command routing uses `FocusedValues`; new View menu picture-browser command should follow existing focused command patterns.

## High-Risk Concerns
### Product / Behavioral Risks
- Ambiguity between "de-pin in UI" and "remove from source file on save" can cause accidental picture loss expectations.
- Shared pooled-image references can produce unexpected bulk changes if track association boundaries are unclear in UI, especially with bytes-only dedupe identity.
- Cross-type duplicate detection and warning overlays may confuse users if duplicate definition is not exact and deterministic.
- Front-cover write-order override ("first front cover written last") can be easy to violate during refactor.

Risk mitigation (in-scope):
- Mutating actions must target `(trackID, pictureReferenceID)` by default, not `poolItemID`, unless explicitly running an all-tracks pin action.
- Always display active scope text near controls (`All Tracks` or `Selected Tracks (N)`), and include affected-track count in destructive or partial-removal messaging.
- Keep remove/partial-visibility overlay copy explicit that out-of-scope references remain and re-pin can restore selected-track references.

### Tooling / Environment / Sandbox Risks
- Large image pools can increase memory pressure; dedupe must avoid unnecessary data copies and avoid retain cycles in observable state.
- SwiftUI table/sheet + toolbar accessory behavior can be fragile under ViewInspector traversal; tests should emphasize behavior checks over brittle hierarchy assertions.
- Security-scoped bookmark refresh/write and reload flows may mask picture-pool bugs when file access fails.

## Destructive / Write-Back Behavior
- Preserved:
- Save scope (`selected` vs `all`) and locked-track save exclusions remain unchanged unless explicitly overridden by confirmed decisions.
- FLAC bridge behavior that removes all existing picture blocks before writing new ones.
- Replaced/extended:
- Replace global album-art dictionary behavior with per-track ordered picture-reference lists backed by a shared pool.
- Save picture payload is now computed per target track from pool references, not one global picture set.
- Removed:
- Implicit "single image per picture type" model from import, editor state, diffing, and write payload generation.

Write-back specifics to enforce:
- Picture-only save rewrites each target track with exactly its current pinned picture references in pool order.
- For type `3` (front cover), the first pinned front-cover reference for that track is emitted last in final write order.
- Type `1` validation must reject non-PNG or multiple type-1 entries per track before write attempt (with user-facing error).
- De-pinning from selected tracks removes those in-memory references; underlying file content changes only when save runs.
- `Save all Pictures to all Tracks` overrides save scope for picture pinning targets and applies to all loaded unlocked tracks.

## Implementation Phases
1. Picture Data Model Refactor
- Introduce pooled picture identity model (e.g., `PicturePoolItem` + stable ID + immutable image bytes + metadata).
- Replace `[AlbumArtSlot: AlbumArtImageAsset]` and `[Int: Data]` maps with:
- Ordered pool collection of unique pictures.
- Per-track ordered references (`trackID -> [pictureReference]`) with type and pool ID.
- Update `Track` / snapshot structures to represent ordered per-track picture state.

2. Import / Reload / Remove Integration
- Update `FlacImportMapper` picture mapping to retain ordered arrays, not first-per-type dictionaries.
- On import/add/reload, merge pictures into pool by bytes-only dedupe key and rebuild per-track references.
- On track removal, remove references and garbage-collect unreferenced pool entries.
- Keep `importedFlacPicturesByType` replacement aligned with new pool model (rename to avoid old semantics).

3. Save And Diff Pipeline Refactor
- Replace global `albumArtPictures` usage in `ContentView` + `TagEditorViewModel` with per-track payload generation closures/data providers.
- Update diff/status methods (`editorDifferencesForTrack`, external differences, unsaved counts, reload eligibility) to compare track-level ordered picture lists.
- Generate ordered `FlacWritablePictureRecord` payload per track, including front-cover reorder caveat.
- Keep tag-only behavior unaffected.

4. Album Art Browser UI Upgrade
- Replace slot-based singleton rendering with per-type picture collections and current index per type/scope.
- Implement list label counts and duplicate-cross-type mismatch styling/overlay messaging.
- Add accessory toolbar controls and enablement rules for:
- Album-level pinning toggle.
- Track-level pinning toggle.
- First/previous/next/last navigation.
- Import/remove/export commands.
- Scope text and disabled states based on selection, lock state, and setting overrides.
- Include concise metadata presentation for the currently displayed picture reference (at minimum type name and description; MIME type where available).

5. Main Editor + Commands + Settings
- Change album-art well interaction to double-click sheet open.
- Add album-art well context menu action `Show Picture Browser`.
- Add View menu command with `Command-1` to show/hide browser and wire through `FocusedValues`.
- Extend `SaveSettings` with new toggle keys/defaults and add UI controls in `TagWriteSettingsView` at required positions.
- Apply setting precedence rules to pinning controls and drag/drop behavior.

6. Alerts, Lock Handling, And UX Rules
- Add explicit alerts for:
- Blocked pin/edit operations due to locked tracks.
- Front-cover drop conflict resolution dialog (`replace`, `add as first`, `add as last`, default cancel) with singular/plural wording.
- Replace remove-picture alert with mismatch-color overlay behavior when picture remains visible due to out-of-scope references.
- Ensure mismatch-color and duplicate warning messages are consistent with existing formatting settings.

7. Validation And Hardening
- Run fast diagnostics for touched files.
- Build project.
- Run targeted tests for new model, mapper/save behavior, and UI control gates.
- Confirm no regressions in existing album-art import/export and save-status flows.
- Add model-layer assertions (debug-only) that detect unintended cross-track mutations for selected-track actions.

## Test Strategy
Order (per guide):
1. Unit tests (`SwiftTagTests`) for:
- Pool dedupe and reference garbage collection behavior.
- Ordered per-track picture mapping from import records.
- Type-1 validation rules.
- Front-cover write-order override behavior.
- Per-track diff logic and save eligibility for picture-only/tag-only/tag+picture payloads.
- Scope-isolation rules: selected-track remove/reorder/pin must not mutate out-of-selection references, even when bytes are pooled.
- Per-reference metadata retention when pooled bytes are identical but MIME/description differ by track reference.
2. Service/fixture tests with copied FLAC fixtures for:
- Importing multiple pictures of same type and preserving order.
- Writing per-track divergent picture sets.
- Confirming no unintended writes for unaffected tracks in selected-scope saves.
3. ViewInspector tests for:
- `AlbumArtSheetView` type count labels.
- Pin toggles and navigation button enablement gates.
- Lock-driven disablement and alert trigger wiring.
- Main well double-click/context-menu open action exposure.
- Active scope text and partial-removal overlay messaging include re-pin hint.
4. Targeted UI tests only if needed for:
- View menu `Show/Hide Picture Browser` command toggle with keyboard shortcut.
- Sheet visibility interactions that ViewInspector cannot reliably assert.

Validation tools:
- `XcodeRefreshCodeIssuesInFile` on modified Swift files.
- `BuildProject` for compile validation.
- `RunSomeTests` for targeted test groups.

## Acceptance Criteria
- A track can reference zero or more pictures per type, including multiple entries of the same type (except type `1` limits).
- Picture bytes are pooled uniquely across tracks; removing last reference removes pool entry.
- Browser type list displays `Name (count)` for the active scope.
- Duplicate cross-type state is visibly signaled with mismatch styling and overlay message.
- Album-level and track-level pin controls behave as specified for scope, lock gating, and toggle precedence.
- Destination navigation controls move within per-type ordered picture sets and disable correctly.
- Remove/export/import actions in browser behave according to selected/all scope semantics plus confirmed overlay behavior when out-of-scope references remain.
- `Save Front Cover to all Tracks` (default On) and `Save all Pictures to all Tracks` (default Off) are present and enforce precedence rules.
- Main album-art well opens browser on double-click and offers `Show Picture Browser` context menu action.
- View menu contains `Show Picture Browser`/`Hide Picture Browser` toggle command with `Command-1`.
- Save writes per-track ordered picture payloads and writes first front-cover reference last for each written track.
- Locked-track restrictions prevent pin/edit actions with explicit user feedback.
- Front-cover drop `Replace existing image(s)` behavior applies only to front-cover entries and follows confirmed affected-track rules.

## Confirmed Decisions
- Picture pool dedupe identity is based on exact data bytes only.
- `Save Front Cover to all Tracks` does not apply front-cover in-memory pin changes to locked tracks.
- `Save all Pictures to all Tracks` applies to all loaded tracks regardless of save scope (while still respecting lock protections for editability).
- Remove-picture behavior when unselected tracks still reference a picture:
- Remove references from selected affected tracks.
- Do not show an alert for this condition.
- Draw a `0.25` opacity overlay using `Track/Disc Total Mismatch Color` with text indicating:
- The picture will be removed from selected tracks.
- The picture remains displayed because tracks outside selection still reference it.
- It can be added back to selected tracks by pinning again.
- Front-cover drop dialog `Replace existing image(s)` updates front-cover references only.
- If dropped picture is already pooled and all affected tracks already have it as first front cover, no change is made and dialog should not be shown.
- If dropped picture is already pooled and one or more affected tracks do not have it as first front cover, add first-front-cover reference for those tracks.
- This may coexist with other references to the same pooled picture under different picture types.
- Affected tracks are:
- Selected tracks, or all tracks when no selection, or all tracks when `Save Front Cover to all Tracks` is On.
- Intersected with unlocked tracks only.
- View menu command is inserted at the top of View menu and reserves `Command-1` exclusively for `Show/Hide Picture Browser`.
- For bytes-only dedupe collisions with differing MIME/description values, metadata is stored per track-reference (not canonicalized in the pool).
- For `Save all Pictures to all Tracks` On, locked tracks remain excluded from in-memory pin mutations.
- Remove-picture informational overlay text may use equivalent wording, but must include a hint that the picture can be added back by pinning again.

## Open Questions
- None currently.

## TODO
- Consider a follow-up UI enhancement to expose richer picture metadata in the browser (for example MIME type, description, dimensions, and byte size) in a compact inspector panel or inline detail row.
