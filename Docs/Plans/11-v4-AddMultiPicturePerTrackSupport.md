# Add Multi Picture Per Track Support Plan

## Goal
Revise album-art multi-picture behavior so `Save all Pictures to all Tracks` and `Save Front Cover to all Tracks` become the live source of truth for pinning and type-scope behavior, remove the sheet-level album pin and track-scope controls, and add an `Add` front-cover drop action that appends instead of replacing.

## Scope
In scope:
- Add a third `chooseFrontCoverDropAction` result, `add`, exposed by a new `Add` button, so front-cover drops can append to the existing front-cover list.
- Remove `Pin Album Pictures`.
- Remove `albumArt.sheet.trackPictureScopePicker`.
- Make `Save all Pictures to all Tracks` a live behavior controller:
- when On, force `Pin Track Pictures` On for every slot, force `albumArt.sheet.typePictureScopePicker` to `allTrackPictures`, and pin all existing and newly added pictures for unlocked tracks regardless of current selection.
- when Off, force `Pin Track Pictures` Off, force `albumArt.sheet.typePictureScopePicker` to `selectedTrackPictures`, and preserve existing unlocked pinned references as-is.
- Keep `Save Front Cover to all Tracks` as a higher-precedence front-cover-only live rule:
- when On, force Front Cover pin On and disabled, force Front Cover type scope to `allTrackPictures` and disabled, and pin all Front Cover additions for unlocked tracks.
- when Off, Front Cover immediately falls back to the same rules as other slots under `Save all Pictures to all Tracks`.
- Ensure locked tracks never have pin state changed and never receive picture writes from these forced behaviors.
- Update plan coverage for model behavior, UI behavior, add/import behavior, save/write behavior, and regression tests affected by the new setting-driven semantics.

Out of scope:
- Unrelated tag-editing flows, FLAC bridge format changes, or redesign of settings unrelated to the two picture-save toggles.
- Changing duplicate pooled-picture detection or navigation-only behavior except where the new front-cover `Add` action explicitly requires a different outcome.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/11-v3-AddMultiPicturePerTrackSupport.md`.
- Current implementation files reviewed:
- `SwiftTag/Features/AlbumArt/AlbumArtSheetView.swift`
- `SwiftTag/Features/AlbumArt/AlbumArtViewModel.swift`
- `SwiftTag/Features/AlbumArt/AlbumArtTypes.swift`
- `SwiftTag/Features/Settings/TagWriteSettingsView.swift`
- `SwiftTag/Shared/Models/SaveSettings.swift`
- `SwiftTag/ContentView.swift`
- `SwiftTag/SwiftTagTests/SwiftTagTests.swift`
- `SwiftTag/SwiftTagTests/TrackStatusViewInspectorTests.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Fixture-first check: direct fixture inspection was not required to draft this revision because the requested changes are primarily album-art editor state, settings precedence, and save-target behavior. Fixture-backed verification remains part of implementation because writeback and locked-track exclusions are in scope.
- Constraints accounted for:
- Current implementation still has three competing pin mechanisms: `Pin Album Pictures`, `Save all Pictures to all Tracks`, and `Save Front Cover to all Tracks`.
- Current implementation still contains transient/effective pin behavior through `forcedTrackPinState`, `isTrackPinForced`, and `effectivePinnedReferences`.
- Current front-cover drop alert supports only `Cancel` and `Replace Existing`, so append behavior requires explicit ordering and save-write validation.
- `SaveSettingsDefaults.saveFrontCoverToAllTracks` currently defaults to `true`, so any default change for that setting must be explicit rather than assumed.

## Current Implementation Snapshot
- `AlbumArtSheetView` still renders `Pin Album Pictures`, `albumArt.sheet.trackPictureScopePicker`, and per-slot `albumArt.sheet.typePictureScopePicker`.
- `AlbumArtViewModel` still stores `pinAlbumPictures`, `trackPictureScope`, and `typePictureScopeBySlot`.
- `configurePinSettings(saveFrontCoverToAllTracks:saveAllPicturesToAllTracks:)` currently updates runtime forced behavior instead of acting only as a persistence/default source.
- `saveAllPicturesToAllTracks` currently affects `isPinAlbumPicturesOn`, `isPinAlbumPicturesDisabled`, manual pin targets, forced pin display, and effective save payload generation.
- `saveFrontCoverToAllTracks` currently has front-cover-specific forced behavior in both manual pin targeting and save payload generation.
- `chooseFrontCoverDropAction()` currently supports only `cancel` and `replace`, and `applyFrontCoverDrop` currently replaces all front-cover references in targeted unlocked tracks.
- `flacPictures(for:albumArtTypes:)` currently relies on `effectivePinnedReferences`, so forced settings can affect saved output without fully mutating stored per-track references.

## Confirmed Decisions
- Remove `Pin Album Pictures`.
- Remove `albumArt.sheet.trackPictureScopePicker`.
- Add an `Add` choice to `chooseFrontCoverDropAction` for front-cover drops.
- `Save all Pictures to all Tracks` defaults to Off.
- `albumArt.sheet.typePictureScopePicker` defaults to `selectedTrackPictures`.
- When `Save all Pictures to all Tracks` turns On:
- `Pin Track Pictures` for every slot is set On.
- `albumArt.sheet.typePictureScopePicker` for every slot is set to `allTrackPictures`.
- Existing and new pictures for each slot are pinned across all loaded unlocked tracks regardless of selection.
- Locked tracks are excluded from those pin mutations and writes.
- When `Save all Pictures to all Tracks` turns Off:
- For every non-front-cover-forced slot, `Pin Track Pictures` is re-enabled with its current state preserved.
- For every non-front-cover-forced slot, `albumArt.sheet.typePictureScopePicker` is re-enabled with its current value preserved.
- No automatic pin-state mutation, no automatic scope reset, and no automatic reference cleanup occurs only because the setting turned Off.
- Any all-track pinned references created while the forcing setting was On remain in place exactly as created after the setting turns Off.
- When `Save Front Cover to all Tracks` is On:
- Front Cover `Pin Track Pictures` is set On and disabled.
- Front Cover `albumArt.sheet.typePictureScopePicker` is set to `allTrackPictures` and disabled.
- Any picture added to the Front Cover slot is pinned for all loaded unlocked tracks.
- No other setting overrides this behavior except locked tracks.
- When `Save Front Cover to all Tracks` is Off:
- Front Cover controls are merely re-enabled unless `Save all Pictures to all Tracks` is still On.
- No automatic pin-state mutation, no automatic scope reset, and no automatic reference cleanup occurs only because the setting turned Off.
- When both settings are Off, Front Cover default add/load pinning follows the current `albumArt.sheet.typePictureScopePicker` value like any other slot.
- Front Cover `Add` appends and stays appended in both UI browsing order and FLAC write order.
- Locked tracks never have pin settings changed and never receive picture data writes.
- Precedence order is:
- `Save Front Cover to all Tracks` On overrides all other picture-scope behavior for Front Cover.
- Otherwise `Save all Pictures to all Tracks` On controls all slots.
- Otherwise per-slot behavior follows the current `albumArt.sheet.typePictureScopePicker`.
- In non-forced mode with `albumArt.sheet.typePictureScopePicker == .allTrackPictures`, add/load attaches immediately to all unlocked loaded tracks.
- In non-forced mode with `albumArt.sheet.typePictureScopePicker == .selectedTrackPictures`, add/load attaches to explicitly selected unlocked tracks only.
- When no tracks are explicitly selected and `selectedTrackPictures` is active, newly added/loaded tracks keep their own original pictures pinned to themselves as though individually selected, so tag-only editing and save flows do not drop existing pictures.

## Dependencies And Constraints
- The current model separates stored reference state from effective save-time state. The requested behavior sounds more destructive and setting-driven, so implementation must decide whether to fully mutate stored references or keep a narrower forced-output layer without reintroducing hidden state that conflicts with the UI.
- Removing `Pin Album Pictures` means `ContentView`, `AlbumArtSheetView`, and `AlbumArtViewModel` all need coordinated simplification to avoid dead bindings and mismatched disabled-state logic.
- Front-cover append behavior affects both on-screen browsing order and per-track FLAC write order. Current code inserts new front-cover references at index `0` for normal adds and preserves special write ordering for front covers.
- Locked-track exclusions apply both to in-memory pin/reference mutation and to writeback payload generation, so tests need to verify both levels.

## High-Risk Concerns
### Product / Behavioral Risks
- Front-cover `Add` requires a defined append order for both browsing and save output, otherwise the app may append visually but still reorder on write.

### Tooling / Environment / Sandbox Risks
- This change spans model logic, sheet UI, settings propagation, and save payload behavior, so targeted unit tests plus a project build are needed; full UI automation should stay a fallback because SwiftUI toolbar inspection is more stable through ViewInspector/source assertions here.
- Save/write verification may require fixture-backed tests if the implementation changes how forced settings materialize per-track picture records.

## Destructive / Write-Back Behavior
- Preserved:
- Duplicate pooled-picture detection and “focus existing picture instead of duplicating” behavior unless the new Front Cover `Add` path explicitly requires a different result for an existing pool item that is not yet referenced in the destination slot.
- Locked tracks remain read-only for pin-state mutation and picture writeback.
- Existing picture-only, tag-only, and combined save entry points remain.
- Replaced:
- `Pin Album Pictures` is removed as a runtime editor control and model concept.
- `Save all Pictures to all Tracks` becomes a live runtime controller for per-slot pin and scope behavior instead of a partial forced-save overlay.
- `albumArt.sheet.trackPictureScopePicker` is removed; type-scope becomes per-slot only.
- Added:
- Front Cover drops may append via an explicit `Add` action instead of only cancelling or replacing.

## Implementation Phases
1. Remove Album-Level Pin And Sheet Scope Controls
- Delete `Pin Album Pictures` bindings and UI from `AlbumArtSheetView`, `ContentView`, and `AlbumArtViewModel`.
- Delete `trackPictureScope`, `setTrackPictureScope`, and any helper logic that only existed for `albumArt.sheet.trackPictureScopePicker`.
- Revisit `scopeLabelText` so any remaining label meaning is still coherent after the sheet-level scope picker is removed.

2. Reframe Settings As Live Source Of Truth
- Refactor `configurePinSettings(saveFrontCoverToAllTracks:saveAllPicturesToAllTracks:)` and dependent helpers so the two settings directly drive per-slot pin/scope state and disabled-state behavior.
- Define precedence:
- Front Cover setting On overrides slot behavior for Front Cover only.
- Otherwise `Save all Pictures to all Tracks` drives every slot.
- Otherwise each slot behaves normally with its current `typePictureScopeBySlot` value, which starts at `selectedTrackPictures` for initial model state.
- Remove or simplify helpers whose only job was to preserve effective-vs-stored pin divergence.

3. Update Pinning And Scope Mutation Rules
- When `Save all Pictures to all Tracks` turns On, force every non-locked slot reference set into the all-tracks scope for unlocked tracks.
- When it turns Off, restore the controls to normal non-forced enabled state only; do not auto-reset scope values or pin states.
- Preserve all materialized pinned references created during forced-all-tracks operation when the forcing setting later turns Off.
- Apply the same model to Front Cover when the front-cover-specific setting is Off.
- Keep Front Cover pinned/all-tracks and disabled while its dedicated setting is On.

4. Add Front Cover Append Behavior
- Extend `FrontCoverDropAction` with `add`.
- Update the alert/debug path to surface `Add`.
- Update `applyFrontCoverDrop` so:
- `replace` preserves current replacement semantics for unlocked targeted tracks.
- `add` appends a new front-cover reference instead of replacing existing front-cover references, and preserves appended order through browsing and save output.
- Validate duplicate-reference/no-op rules so `add` does not create duplicate references when the same picture is already referenced in the targeted slot.

5. Align Save Pipeline And Reload Behavior
- Update `flacPictures(for:albumArtTypes:)` and related helpers so saved output matches the visible forced settings behavior without mutating locked tracks.
- Verify selection changes, track reloads, and newly imported track files inherit the correct pinning rules:
- all unlocked tracks when `Save all Pictures to all Tracks` is On
- front-cover-only all unlocked tracks when only `Save Front Cover to all Tracks` is On
- slot-specific `typePictureScopeBySlot` behavior when neither forcing rule applies
- Keep the default initial non-forced type scope at `selectedTrackPictures`.
- When non-forced `selectedTrackPictures` is active and there is no explicit selection, track load/import must still preserve each loaded track’s own pictures as pinned to that track.

6. Validation And Hardening
- Refresh diagnostics for touched Swift files.
- Add targeted unit tests first, then ViewInspector/source assertions for sheet/settings UI, then fixture-backed write tests if save output changes materially.
- Build the project.

## Test Strategy
Order:
1. Unit tests for `AlbumArtViewModel` behavior:
- `Save all Pictures to all Tracks` On forces every slot to pinned/all-tracks for unlocked tracks only.
- `Save all Pictures to all Tracks` Off merely re-enables every non-front-cover-forced slot control without auto-resetting scope or pin state.
- `Save all Pictures to all Tracks` Off preserves concrete all-track references created while forced mode was active.
- Turning `Save all Pictures to all Tracks` Off does not mutate locked tracks.
- Front Cover setting On forces Front Cover pinned/all-tracks and disabled regardless of the global setting.
- Front Cover setting Off merely re-enables Front Cover controls unless the global setting is still forcing them.
- Newly added pictures inherit forced all-track pinning when the relevant setting is On.
- Newly added pictures follow the slot’s current type-scope behavior when the relevant forcing setting is Off.
- Non-forced `.allTrackPictures` adds/loads attach to all unlocked loaded tracks.
- Non-forced `.selectedTrackPictures` adds/loads attach to selected unlocked tracks only.
- Non-forced `.selectedTrackPictures` with no explicit selection still preserves each newly loaded track’s own pictures pinned to itself.
- Front Cover `Add` appends instead of replacing.
- Front Cover `Replace Existing` still replaces targeted unlocked front-cover references.
- Existing-picture add/drop remains a no-op when the destination slot already references that pool item.
2. Fixture/service tests if save payload behavior changes:
- verify locked tracks never receive picture writes from global or front-cover forcing
- verify all unlocked tracks receive forced picture writes when `Save all Pictures to all Tracks` is On
- verify front-cover-only forcing when only `Save Front Cover to all Tracks` is On
- verify appended front-cover ordering is stable in both presented navigation order and saved output
3. ViewInspector/source assertions:
- `albumArt.sheet.trackPictureScopePicker` is absent.
- `Pin Album Pictures` is absent.
- `albumArt.sheet.typePictureScopePicker` value/disabled state follows the active forcing setting.
- settings toggles retain their accessibility identifiers.
- the front-cover alert path includes the new `Add` choice.
4. XCUI only if the front-cover alert interaction cannot be covered reliably through unit seams or source assertions.

## Acceptance Criteria
- `Pin Album Pictures` is removed from the album-art sheet and from the runtime model path.
- `albumArt.sheet.trackPictureScopePicker` is removed.
- `Save all Pictures to all Tracks` defaults to Off.
- `albumArt.sheet.typePictureScopePicker` defaults to `selectedTrackPictures`.
- When `Save all Pictures to all Tracks` is On, every non-locked slot behaves as pinned to all loaded tracks and newly added pictures are pinned across unlocked tracks regardless of selection.
- When `Save all Pictures to all Tracks` is Off, every non-front-cover-forced slot simply becomes user-editable again, no locked-track pin state is changed, and newly added/loaded pictures follow the slot’s current `typePictureScopeBySlot`.
- Front Cover respects `Save Front Cover to all Tracks` as a higher-precedence forced behavior and, when that setting turns Off, only becomes user-editable again unless the global setting is still forcing it.
- Locked tracks never have pin settings changed and never receive picture writes from any forcing rule.
- Front Cover drops present `Cancel`, `Replace Existing`, and `Add`.
- Choosing `Add` appends a front-cover picture instead of replacing existing front-cover pictures for targeted unlocked tracks, and that appended order persists in both browsing and FLAC write order.
- Save output reflects the active setting-driven behavior and excludes locked tracks.
- Concrete all-track references created during forced mode remain after forced mode is later disabled.
- In non-forced `.allTrackPictures`, add/load writes to all unlocked loaded tracks immediately.
- In non-forced `.selectedTrackPictures`, add/load writes only to explicitly selected unlocked tracks, except that track load/import with no explicit selection still preserves each loaded track’s own pictures on that track.

## Open Questions
- None currently.
