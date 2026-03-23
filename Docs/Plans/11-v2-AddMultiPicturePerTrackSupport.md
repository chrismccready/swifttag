# Add Multi Picture Per Track Support Plan

## Goal
Implement per-track multi-picture album-art management with shared in-memory picture pooling, selection-aware pinning controls, picture browser navigation and commands, save-setting overrides, writeback behavior that supports multiple pictures per type, and the additional scope-driven browser/pinning behavior described below while preserving lock protections and explicit UI feedback.

## Scope
In scope:
- Replace single-picture-per-type editor state with a pooled picture model that supports:
- Multiple pictures per type per track.
- Shared image references across tracks without duplicating image bytes in memory.
- Per-track ordered references to pooled pictures.
- Type-level constraints for FLAC type `1` (single picture, PNG only).
- Add album-art browser behavior updates in `AlbumArtSheetView`:
- Type list labels show `Name (count)` where `count` is unique picture count for the active picture scope.
- Duplicate cross-type warning presentation using the configured mismatch color and italicized type labels.
- Accessory toolbar for album-level pinning (`Pin Album Pictures`) with scope text (`All Tracks` or `Selected Tracks (count)`).
- Add a segmented `Track Picture Scope` picker after `Pin Album Pictures` with icon-only choices:
- `All Track Pictures` (`photo.stack.fill`) as the default.
- `Selected Track Pictures` (`photo.on.rectangle.angled.fill`).
- When `Track Picture Scope` is `All Track Pictures`, type list counts use all pooled pictures available for that type.
- When `Track Picture Scope` is `Selected Track Pictures`, type list counts use pooled pictures for that type that are referenced by the current selected tracks.
- Destination accessory toolbar for per-type picture pinning (`Pin Track Pictures`), per-type picture-scope selection, picture navigation controls, import/remove/export controls, metadata/status text, and enablement rules.
- Add a segmented `Type Picture Scope` picker after `Pin Track Pictures` with icon-only choices:
- `All Track Pictures` (`photo.stack.fill`) as the default.
- `Selected Track Pictures` (`photo.on.rectangle.angled.fill`).
- When `Type Picture Scope` is `All Track Pictures`, the destination list/browser for that type exposes all pooled pictures of that type.
- When `Type Picture Scope` is `Selected Track Pictures`, the destination list/browser for that type exposes only pooled pictures of that type referenced by the current selected tracks.
- `Pin Track Pictures` toggles write targets based on `Type Picture Scope`:
- `All Track Pictures` means pin/unpin against all tracks.
- `Selected Track Pictures` means pin/unpin against selected tracks.
- Add settings toggles in `TagWriteSettingsView`:
- `Save Front Cover to all Tracks` (default On).
- `Save all Pictures to all Tracks` (default Off).
- Enforce setting precedence:
- `Save all Pictures to all Tracks` forces album-level pinning behavior and per-type pinning behavior for all picture types.
- `Save Front Cover to all Tracks` forces per-type front-cover pinning behavior only.
- Forced controls show effective temporary values in the UI while preserving stored state for later restoration.
- If save runs while a control is forced, the effective forced state determines write output.
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
- Remove `addFirst` and `addLast` from `chooseFrontCoverDropAction` and simplify associated front-cover drop logic.
- Extend current picture metadata text to include `In file: Yes|Mixed|No`, followed by the current presented picture index, ` of `, and the presented picture count for the active type scope.

Out of scope:
- FLAC bridge C-layer format changes unless required to satisfy ordering rules not achievable from Swift-side record ordering.
- Unrelated tag-editing flows, diff formatting outside picture-specific UI states, or unrelated settings redesign.
- Multi-window/global shared picture state across editor sessions.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/11-AddMultiPicturePerTrackSupport.md`.
- Current implementation files reviewed:
- `SwiftTag/ContentView.swift`
- `SwiftTag/Features/AlbumArt/AlbumArtSheetView.swift`
- `SwiftTag/Features/AlbumArt/AlbumArtViewModel.swift`
- `SwiftTag/Features/Settings/TagWriteSettingsView.swift`
- `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
- `SwiftTag/Features/FlacImport/FlacWriteMapper.swift`
- `SwiftTag/Shared/Models/Track.swift`
- `SwiftTag/Shared/Models/SaveSettings.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Fixture-first check completed:
- `SwiftTagTestFiles/test.flac`
- `SwiftTagTestFiles/test-with_padding.flac`
- Constraints accounted for:
- Security-scoped bookmark requirements for import/reload/save.
- Existing save/diff pipeline still contains legacy global picture assumptions alongside the newer pooled/reference model.
- Existing FLAC write path removes all picture blocks before appending new picture blocks.
- Existing browser UI currently has pooled multi-picture basics but not the new scope pickers or effective-state override presentation.

## Current Implementation Snapshot
- `AlbumArtViewModel` already contains a pooled picture store (`picturePool`, `trackReferencesByTrackID`, per-slot current index state, per-track unpinned state, save-setting configuration, export/import/drop handling, and per-track write payload generation).
- `Track` already carries ordered `flacPictureRecords` while retaining a legacy `flacPicturesByType` compatibility view.
- `SaveSettings` and `TagWriteSettingsView` already expose `Save Front Cover to all Tracks` and `Save all Pictures to all Tracks`.
- `AlbumArtSheetView` already shows type counts, duplicate styling, album-level pin control, per-type pin control, picture navigation, import/remove/export actions, and metadata text.
- `SwiftTagTests/TrackStatusViewInspectorTests.swift` already provides a working ViewInspector harness for `TagEditorTrackFileView`, `TagEditorAlbumView`, and `AlbumArtSheetView`, so browser/UI behavior coverage should extend that harness before introducing XCUI for inspectable cases.
- `AlbumArtViewModel` still contains front-cover drop-choice machinery with `cancel`, `replace`, `addFirst`, and `addLast`.
- `AlbumArtSheetView` does not yet expose `Track Picture Scope` or `Type Picture Scope`.
- The current browser count logic is global across all loaded tracks (`uniquePictureCount(for:)`) and is not yet scope-aware.
- The current `Pin Album Pictures` behavior only supports forcing pinning on across unlocked tracks; it does not present temporary effective states or scope-sensitive disablement rules.
- The current `Pin Track Pictures` behavior is based on existing target-track resolution and does not yet use a user-selected type picture scope as the write-target source of truth.
- `currentPictureMetadataText` currently reports description, MIME type, byte size, type count, and displayed-reference count, but not the requested `In file` status or active-position text.
- `TagEditorViewModel` still retains `importedFlacPicturesByType`, which is a remaining legacy compatibility seam to keep in mind during save/diff cleanup.

## Dependencies And Constraints
- `FlacMetadataService.readTags` already returns ordered `[FlacPictureRecord]`; order-sensitive behavior must preserve this order through import and write.
- Bridge currently enforces type-1 PNG icon legality and removes all picture blocks before write; Swift-side payload generation must satisfy this invariant.
- Existing save eligibility and diff logic (`TagEditorViewModel`) still carries one shared picture-set assumptions in some paths; per-track picture payloads and diffing must be refactored without regressing tag-only saves.
- Selection semantics are centralized in `TagEditorViewModel.selectedTrackIDs`; all selection-aware picture-scope logic must use that as source of truth.
- Locked tracks are currently excluded from saves and most edits; new pinning/edit controls must use equivalent lock gating and explicit alerting.
- Command routing uses `FocusedValues`; new View menu picture-browser command should follow existing focused command patterns.
- Forced-state UI must preserve underlying stored pin state while separately computing effective UI state and effective save output state.

## High-Risk Concerns
### Product / Behavioral Risks
- Ambiguity between visible scope, pinning target scope, and final write scope can cause accidental picture propagation or omission unless the UI remains explicit.
- Shared pooled-image references can produce unexpected bulk changes if track association boundaries are unclear in UI, especially with bytes-only dedupe identity.
- Cross-type duplicate detection and warning overlays may confuse users if duplicate definition is not exact and deterministic.
- Effective temporary forced states can drift from stored state if model helpers are not separated cleanly into stored-state vs effective-state queries.
- Front-cover write-order override and front-cover forced-pin precedence can be easy to violate during refactor.

Risk mitigation (in-scope):
- Make `Track Picture Scope` and `Type Picture Scope` explicit, independent model values with dedicated helper methods for counts, presented references, and write-target resolution.
- Keep stored pin state and effective pin state separate in the model API.
- Always display active scope text near controls and metadata, and include affected-track count in destructive or partial-removal messaging where practical.
- Keep remove/partial-visibility overlay copy explicit that out-of-scope references remain and re-pin can restore selected-track references.

### Tooling / Environment / Sandbox Risks
- Large image pools can increase memory pressure; dedupe must avoid unnecessary data copies and avoid retain cycles in observable state.
- SwiftUI table/sheet and toolbar accessory behavior can be fragile under ViewInspector traversal; tests should emphasize behavior checks over brittle hierarchy assertions.
- Security-scoped bookmark refresh/write and reload flows may mask picture-pool bugs when file access fails.

## Destructive / Write-Back Behavior
- Preserved:
- Save scope (`selected` vs `all`) and locked-track save exclusions remain unchanged unless explicitly overridden by confirmed decisions.
- FLAC bridge behavior that removes all existing picture blocks before writing new ones.
- Replaced/extended:
- Replace global album-art dictionary behavior with per-track ordered picture-reference lists backed by a shared pool.
- Save picture payload is computed per target track from pool references and effective forced pin state, not from one global picture set.
- Removed:
- Implicit `single image per picture type` model from import, editor state, diffing, and write payload generation.
- Front-cover drop `addFirst` and `addLast` action modes and associated branching.

Write-back specifics to enforce:
- Picture-only save rewrites each target track with exactly its current effective pinned picture references in pool order.
- For type `3` (front cover), the first pinned front-cover reference for that track is emitted last in final write order.
- Type `1` validation must reject non-PNG or multiple type-1 entries per track before write attempt (with user-facing error).
- De-pinning from selected/all tracks removes those in-memory references or effective inclusion as defined by the relevant scope and force rule; underlying file content changes only when save runs.
- `Save all Pictures to all Tracks` overrides save scope for picture pinning targets and applies to all loaded unlocked tracks.
- `Save Front Cover to all Tracks` overrides front-cover track pinning targets only and uses effective forced state during save even if stored state remains different.

## Implementation Phases
1. Scope And Effective-State Model Refactor
- Introduce explicit browser scope state for:
- `Track Picture Scope` at the sheet level for type-count/list scope.
- `Type Picture Scope` at the destination level for picture presentation and track pin-target resolution.
- Add helpers that separately compute:
- Stored pin state.
- Effective pin state.
- Effective disabled state.
- Active track set for metadata/status evaluation.
- Active picture pool set for counts and presented references.
- Preserve stored pin state while allowing forced overrides from album-level and settings-level rules.

2. Browser UI Upgrade
- Add `Track Picture Scope` segmented picker after `Pin Album Pictures`.
- Update type list labels to use the active sheet-level scope count.
- When `Pin Album Pictures` is On and `Track Picture Scope` is `All Track Pictures`, disable every destination `Pin Track Pictures` toggle, render them visually On, but preserve stored state.
- When `Pin Album Pictures` is On and `Track Picture Scope` is `Selected Track Pictures`, disable every destination `Pin Track Pictures` toggle for the selected-track scope, render them visually On, but preserve stored state.
- Add `Type Picture Scope` segmented picker after `Pin Track Pictures`.
- Update destination picture presentation, navigation bounds, and metadata counts to use the active destination-level scope.

3. Settings Override Integration
- Apply `Save Front Cover to all Tracks` only to the front-cover type:
- When a front cover exists, `Pin Track Pictures` is effectively On and disabled.
- When no front cover exists, `Pin Track Pictures` is effectively Off and disabled.
- Apply `Save all Pictures to all Tracks` globally:
- `Pin Album Pictures` is effectively On and disabled.
- Each `Pin Track Pictures` is effectively On and disabled when that type has at least one picture available.
- Each `Pin Track Pictures` is effectively Off and disabled when that type has no picture available.
- Ensure subsequently imported or dropped pictures immediately update effective forced states.

4. Pinning And Save Pipeline Alignment
- Make `Type Picture Scope` the source of truth for `Pin Track Pictures` pin/unpin targets.
- Keep the `Pin Track Pictures` On/Off mechanism otherwise consistent with current save semantics:
- When On, pinned pictures of that type are written to all/selected track files based on the active type scope or effective force rule.
- When Off, those pictures are not written to the targeted tracks at save time unless a stronger forced setting applies.
- Update save payload generation to use effective forced states, not merely stored/restorable states.
- Validate front-cover and all-pictures forced modes against target availability transitions.

5. Front Cover Drop Simplification
- Remove `addFirst` and `addLast` cases from `chooseFrontCoverDropAction`.
- Simplify front-cover drop resolution logic so only the remaining supported behaviors are represented in model state and any user-facing decision flow.
- Update related tests and any debug-only drop-action hooks.

6. Metadata, Counts, And Messaging
- Extend `currentPictureMetadataText` to report:
- `In file: Yes` when the current picture is present in all active tracks.
- `In file: Mixed` when it is present in some but not all active tracks.
- `In file: No` when it is present in none of the active tracks.
- Active tracks means selected tracks, or all tracks when there is no selection.
- Append the current presented index and total presented count for the active type scope.
- Keep existing description, MIME type, and byte-size text unless simplification is warranted during implementation.

7. Save/Diff/Legacy Cleanup
- Replace remaining global picture assumptions in `ContentView` and `TagEditorViewModel` with per-track/effective-state providers.
- Review `importedFlacPicturesByType` and related compatibility seams; remove or constrain legacy paths where they would conflict with scope-aware picture behavior.
- Confirm no regression in tag-only behavior, reload logic, track removal, and save-status flows.

8. Validation And Hardening
- Run fast diagnostics for touched files.
- Build project.
- Run targeted tests for new model behavior, scope resolution, override precedence, metadata text, simplified front-cover drop handling, and ViewInspector-based browser UI gates.
- Add assertions or focused helpers where useful to catch stored-state/effective-state divergence bugs.

## Test Strategy
Order (per guide):
1. Unit tests (`SwiftTagTests`) for:
- Pool dedupe and reference garbage collection behavior.
- Ordered per-track picture mapping from import records.
- Type-1 validation rules.
- Front-cover write-order override behavior.
- Per-track diff logic and save eligibility for picture-only/tag-only/tag+picture payloads.
- Scope-isolation rules: selected-track remove/reorder/pin must not mutate out-of-selection references, even when bytes are pooled.
- Stored-state vs effective-state precedence for:
- `Pin Album Pictures`.
- `Save Front Cover to all Tracks`.
- `Save all Pictures to all Tracks`.
- Scope-picker count and target resolution behavior.
- Metadata `In file: Yes|Mixed|No` calculation for selected vs no-selection cases.
- Front-cover drop simplification after removing `addFirst` and `addLast`.
2. Service/fixture tests with copied FLAC fixtures for:
- Importing multiple pictures of same type and preserving order.
- Writing per-track divergent picture sets.
- Confirming no unintended writes for unaffected tracks in selected-scope saves.
- Confirming forced save modes use effective state during write even when stored state differs.
3. ViewInspector tests for UI behavior whenever the behavior is inspectable:
- Extend `SwiftTagTests/TrackStatusViewInspectorTests.swift` as the first-choice harness for `AlbumArtSheetView`, `TagEditorAlbumView`, and album-art browser UI gates.
- `AlbumArtSheetView` type count labels under both track picture scopes.
- `Track Picture Scope` and `Type Picture Scope` picker wiring and binding propagation.
- Pin toggle effective On/Off rendering and disabled-state gates.
- Setting-driven and album-pin-driven precedence behavior, including effective temporary values while stored state remains unchanged underneath.
- Metadata/status text includes `In file` and active-position text.
- Browser navigation control enablement/disablement at first/last bounds under each scope.
- Overlay visibility is tied to the currently presented picture reference rather than the slot alone.
- Main well double-click/context-menu open action exposure through inspectable seams in `TagEditorAlbumView` / `AlbumArtWellView` where stable.
4. Prefer non-UI model/service tests instead of XCUI when the behavior can be proven without rendering:
- Effective save payload selection.
- Reload/transient-state discard behavior.
- Pool dedupe, unpin, and garbage-collection semantics.
5. Targeted UI tests only if needed for:
- View menu `Show/Hide Picture Browser` command toggle with keyboard shortcut.
- Sheet visibility interactions that ViewInspector cannot reliably assert.
- Segmented-picker or toolbar cases only after a focused ViewInspector attempt using `find`/`findAll`, `actualView()`, binding inspection, and lifecycle hooks proves insufficient.

Validation tools:
- `XcodeRefreshCodeIssuesInFile` on modified Swift files.
- `BuildProject` for compile validation.
- `RunSomeTests` for targeted test groups.

## Acceptance Criteria
- A track can reference zero or more pictures per type, including multiple entries of the same type (except type `1` limits).
- Picture bytes are pooled uniquely across tracks; removing the last reference removes the pool entry.
- Browser type list displays `Name (count)` for the active `Track Picture Scope`.
- Destination picture list/navigation uses the active `Type Picture Scope`.
- `Pin Track Pictures` target resolution follows `Type Picture Scope`.
- `Pin Album Pictures` plus `Track Picture Scope` forces the effective destination pin state On and disabled without losing stored state.
- `Save Front Cover to all Tracks` forces only front-cover `Pin Track Pictures` effective state and disabled-state behavior, including the no-front-cover effective Off case.
- `Save all Pictures to all Tracks` forces effective album pinning and effective per-type pinning for all current and newly added picture types, including effective Off for types with no pictures.
- If save runs while a control is forced, the written payload follows the effective forced state rather than the stored restorable state.
- Duplicate cross-type state is visibly signaled with mismatch styling and overlay message.
- Main album-art well opens browser on double-click and offers `Show Picture Browser` context menu action.
- View menu contains `Show Picture Browser`/`Hide Picture Browser` toggle command with `Command-1`.
- Save writes per-track ordered picture payloads and writes the first front-cover reference last for each written track.
- Locked-track restrictions prevent pin/edit actions with explicit user feedback.
- `currentPictureMetadataText` reports `In file: Yes|Mixed|No` against selected tracks, or all tracks when nothing is selected, and includes current index of total presented count for the active type scope.
- Front-cover drop behavior no longer exposes `addFirst`/`addLast`.

## Confirmed Decisions
- Picture pool dedupe identity is based on exact data bytes only.
- `Save Front Cover to all Tracks` does not apply front-cover in-memory pin changes to locked tracks.
- `Save all Pictures to all Tracks` applies to all loaded tracks regardless of save scope, while still respecting lock protections for editability.
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
- For bytes-only dedupe collisions with differing MIME/description values, metadata is stored per track-reference, not canonicalized in the pool.
- For `Save all Pictures to all Tracks` On, locked tracks remain excluded from in-memory pin mutations.
- Remove-picture informational overlay text may use equivalent wording, but must include a hint that the picture can be added back by pinning again.
- `Type Picture Scope` is the source of truth for `Pin Track Pictures` write targets.
- `Save Front Cover to all Tracks` forced `Pin Track Pictures` behavior applies only to `Front Cover`.
- When controls are forced by `Pin Album Pictures`, `Save Front Cover to all Tracks`, or `Save all Pictures to all Tracks`, the UI shows an effective temporary value while preserving underlying stored pin state for restoration later.
- If a save occurs while a control is forced, the effective forced state determines what is written.
- `currentPictureMetadataText` evaluates `In file: Yes|Mixed|No` against the selected tracks, or against all tracks when there is no selection.

## Open Questions
- None currently.

## TODO
- Consider a follow-up UI enhancement to expose richer picture metadata in the browser (for example MIME type, description, dimensions, and byte size) in a compact inspector panel or inline detail row.
