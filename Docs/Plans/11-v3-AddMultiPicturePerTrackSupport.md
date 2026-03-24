# Add Multi Picture Per Track Support Plan

## Goal
Revise the multi-picture album-art implementation so album-level pinning directly controls persistent per-type pin state, remove the sheet-level track-scope picker and all transient pin-restoration behavior, and keep duplicate-reference add/navigation behavior unchanged.

## Scope
In scope:
- Remove the sheet toolbar `Track Picture Scope` control identified as `albumArt.sheet.trackPictureScopePicker`.
- Change `Pin Album Pictures` so it becomes the source of truth for all `Pin Track Pictures` values instead of a temporary effective override.
- Remove all transient pin-state preservation and restoration logic.
- Keep `Pin Track Pictures` initialization tied to the `Save all Pictures to all Tracks` setting only at creation/instantiation time.
- Preserve the existing pooled-picture and duplicate-reference behavior when adding an image that already exists in the pool or is already referenced in the destination slot.
- Update plan coverage for model behavior, UI behavior, save/write behavior, and regression tests affected by the new pin semantics.

Out of scope:
- Unrelated tag-editing flows, settings redesign unrelated to the two existing picture-save toggles, or FLAC bridge format changes.
- Changing the existing `Type Picture Scope` browser control unless implementation review proves it is incompatible with the requested pin semantics.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/11-v2-AddMultiPicturePerTrackSupport.md`.
- Current implementation files reviewed:
- `SwiftTag/Features/AlbumArt/AlbumArtSheetView.swift`
- `SwiftTag/Features/AlbumArt/AlbumArtViewModel.swift`
- `SwiftTag/Features/AlbumArt/AlbumArtTypes.swift`
- `SwiftTag/Features/Settings/TagWriteSettingsView.swift`
- `SwiftTag/Shared/Models/SaveSettings.swift`
- `SwiftTag/SwiftTagTests/TrackStatusViewInspectorTests.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Fixture-first check: not required for this planning revision because the requested behavior change is centered on album-art editor state and settings semantics rather than FLAC import/write mapping changes. Fixture-backed verification remains part of the downstream implementation strategy where save/write behavior is touched.
- Constraints accounted for:
- Existing implementation already contains both scope pickers and a stored-vs-effective pin model, so this revision requires explicit removal/simplification rather than additive work.
- Locked-track protections and selection-based behavior already exist and must be reconciled with the new destructive album-pin behavior before implementation.
- Save settings currently persist only the two app-level defaults; per-slot pin state is editor-session state and must remain coherent across import, reload, selection changes, and save.

## Current Implementation Snapshot
- `AlbumArtSheetView` currently renders both `albumArt.sheet.trackPictureScopePicker` and `albumArt.sheet.typePictureScopePicker`.
- `AlbumArtViewModel` currently stores:
- `pinAlbumPictures`
- `trackPictureScope`
- `typePictureScopeBySlot`
- `unpinnedReferenceKeysByTrackID`
- forced/effective pin helpers that allow temporary UI override while preserving underlying state
- `setAlbumPicturesPinned(_:)` currently behaves like a temporary override, not a destructive reset of per-slot pin values.
- `isCurrentPicturePinned`, `setCurrentPicturePinned`, and `forcedTrackPinState` currently distinguish stored state from effective state.
- `configurePinSettings(saveFrontCoverToAllTracks:saveAllPicturesToAllTracks:)` currently updates runtime forced behavior, not just per-slot default initialization.
- Duplicate add behavior already has pooled-reference checks and current-picture navigation behavior that should remain intact.

## Confirmed Decisions
- Remove `albumArt.sheet.trackPictureScopePicker`.
- “pinned to all in type slot” means all loaded and unlocked tracks.
- `Pin Album Pictures` On:
- disables `Pin Track Pictures`
- sets all `Pin Track Pictures` to On/pinned
- does not preserve transient prior pin values for later restoration
- makes newly added pictures pinned to all in their type slot
- `Pin Album Pictures` Off:
- enables `Pin Track Pictures`
- sets all `Pin Track Pictures` to Off/unpinned
- does not preserve transient prior pin values for later restoration
- makes newly added pictures unpinned by default
- If a picture is added that already has a reference, do not modify its reference/pin state.
- If a picture is added to a slot that already references it, navigate to that picture and do not modify reference/pin state.
- Remove all pin-related transient state logic.
- Locked tracks are excluded from destructive pin rewrites triggered by `Pin Album Pictures`.
- `Save all Pictures to all Tracks` sets the default initial value of `Pin Track Pictures`:
- On means newly instantiated `Pin Track Pictures` starts On
- Off means newly instantiated `Pin Track Pictures` starts Off
- After initial instantiation, toggling `Save all Pictures to all Tracks` does not mutate existing `Pin Track Pictures` values
- Initial instantiation of `Pin Track Pictures` means first `AlbumArtViewModel` creation.
- `Save Front Cover to all Tracks` is not removed; it becomes a specialized initialization/default-plus-live-behavior rule for the `Front Cover` slot:
- It can be toggled On or Off at any time.
- When On:
- `Pin Track Pictures` for `Front Cover` is set On and disabled.
- `albumArt.sheet.typePictureScopePicker` for `Front Cover` is set to `allTrackPictures` and disabled.
- Any picture added to `Front Cover` is pinned.
- No other setting overrides this behavior except locked tracks.
- Locked tracks never have pin settings changed or picture data written to them.
- When Off:
- `Pin Track Pictures` for `Front Cover` is set Off unless `Pin Album Pictures` is On.
- `Pin Track Pictures` for `Front Cover` is enabled when `Pin Album Pictures` is Off.
- `albumArt.sheet.typePictureScopePicker` for `Front Cover` is set to `selectedTrackPictures` and enabled.
- Any picture added to `Front Cover` is not pinned unless `Pin Album Pictures` is On.
- When `Save Front Cover to all Tracks` is toggled Off, `Pin Track Pictures` and `albumArt.sheet.typePictureScopePicker` for `Front Cover` are treated like any other slot and immediately follow `Pin Album Pictures`.

## Dependencies And Constraints
- `AlbumArtViewModel` currently uses per-track reference sets plus `unpinnedReferenceKeysByTrackID`; the new behavior may allow that structure to be simplified or replaced, but the plan should avoid assuming a full storage redesign until implementation confirms the minimum change.
- `Type Picture Scope` currently influences visible pictures and manual track-pin target resolution. The requested behavior changes album-level pin semantics, but it does not explicitly redefine per-type scope behavior.
- Locked tracks, selected-track semantics, and save-scope semantics remain a likely source of ambiguity because album-level pinning now sounds destructive rather than temporary.
- Locked tracks remain excluded from both destructive pin rewrites and picture-data writeback.
- The save pipeline still needs to produce per-track picture payloads and respect existing multi-picture ordering constraints.
- `Save Front Cover to all Tracks` now has slot-specific live UI and scope behavior that must coexist with `Pin Album Pictures` without reintroducing transient-state restoration.

## High-Risk Concerns
### Product / Behavioral Risks
- Destructive album-level pinning can silently wipe nuanced per-track pin choices unless the model and UI copy are explicit.
- `Save Front Cover to all Tracks` now mixes initialization semantics with live forced behavior for the front-cover slot only; precedence with `Pin Album Pictures` must stay explicit and testable.
- Removing transient pin logic may require a more direct representation of per-slot pin intent so that save output and visible UI stay aligned.

### Tooling / Environment / Sandbox Risks
- Simplifying pin logic will touch UI and model code that already has ViewInspector coverage; tests should prefer stable binding/state assertions over brittle toolbar traversal.
- Save/write verification may still require fixture-backed tests if implementation changes alter how per-track pinned references are materialized at write time.

## Destructive / Write-Back Behavior
- Preserved:
- Duplicate pooled-picture detection and "navigate instead of mutate" behavior for already-referenced additions.
- Existing picture-only vs tag-only save entry points, unless implementation finds coupling that must be adjusted to keep pin behavior consistent.
- Existing bridge-level rewrite behavior that rewrites picture blocks from Swift-generated payloads.
- Replaced:
- Album-level pinning no longer acts as a temporary effective override; it directly resets all current `Pin Track Pictures` state.
- `Save all Pictures to all Tracks` no longer forcibly changes live `Pin Track Pictures` state after those controls have been instantiated.
- Removed:
- Temporary/effective pin UI state that differs from stored editor-session pin state.
- Restoration of prior pin values when `Pin Album Pictures` or settings toggles change.

## Implementation Phases
1. Pin-State Model Simplification
- Audit the current stored-vs-effective helpers in `AlbumArtViewModel`.
- Remove the model paths that preserve prior pin values for later restoration.
- Refactor album-level pinning so `setAlbumPicturesPinned(_:)` directly updates persistent editor-session `Pin Track Pictures` state for every slot across all loaded unlocked tracks.
- Reconcile `unpinnedReferenceKeysByTrackID` and related helpers with the simpler destructive semantics.

2. Sheet Toolbar And UI Behavior Update
- Remove `albumArt.sheet.trackPictureScopePicker` and any supporting sheet-level scope label logic that exists only for that control.
- Keep `Pin Album Pictures` in the toolbar, but make its On/Off action destructive to all slot pin values.
- Ensure `Pin Track Pictures` is disabled while `Pin Album Pictures` is On and enabled when it is Off.
- Retain any UI needed for `Type Picture Scope` only if it still has a clear responsibility after the pin-model simplification.

3. Add/Import Behavior Alignment
- When `Pin Album Pictures` is On, newly added pictures should enter as pinned across all loaded unlocked tracks for their slot.
- When `Pin Album Pictures` is Off, newly added pictures should enter unpinned by default.
- For `Front Cover`, `Save Front Cover to all Tracks` On forces new additions to be pinned and forces type scope to `allTrackPictures` unless the affected tracks are locked.
- For `Front Cover`, `Save Front Cover to all Tracks` Off forces new additions to be unpinned and forces type scope to `selectedTrackPictures` unless `Pin Album Pictures` is On.
- Preserve the no-op behavior when adding a picture that is already referenced, and preserve navigation-only behavior when the destination slot already references that picture.

4. Settings Initialization Behavior
- Change `Save all Pictures to all Tracks` handling so it only provides the default initial `Pin Track Pictures` value for newly instantiated slot state.
- Define first instantiation as first `AlbumArtViewModel` creation and ensure later `Save all Pictures to all Tracks` changes do not retroactively mutate existing slot state.
- Rework `Save Front Cover to all Tracks` so it:
- can be toggled live
- forces `Front Cover` pin On + disabled and type scope `allTrackPictures` + disabled when On
- forces `Front Cover` pin Off and type scope `selectedTrackPictures` immediately when Off
- then lets `Front Cover` pin and type scope behave like any other slot, including immediate `Pin Album Pictures` control if album pin is On
- never mutates locked tracks

5. Save Pipeline And Regression Alignment
- Verify that the simplified pin model still produces correct per-track picture payloads.
- Remove any save-time reliance on temporary effective pin state.
- Review reload/discard flows to ensure they rebuild pin defaults and live state predictably under the new rules.

6. Validation And Hardening
- Refresh diagnostics for touched Swift files.
- Build the project.
- Add targeted tests for destructive album-pin transitions, slot default initialization, duplicate add/no-op behavior, and any save-path regressions.

## Test Strategy
Order:
1. Unit tests for `AlbumArtViewModel` behavior:
- `Pin Album Pictures` On sets all slot pin states On and disables per-slot toggles.
- `Pin Album Pictures` Off sets all slot pin states Off and re-enables per-slot toggles.
- No prior pin state is restored after toggling album pin back Off.
- Locked tracks are excluded from album-pin destructive rewrites.
- Newly added pictures inherit pinned/unpinned default from current album-pin state.
- Adding an already-referenced pooled picture does not change pin/reference state.
- Adding a picture to a slot that already references it navigates to it without mutation.
- `Save all Pictures to all Tracks` only affects slot pin default at first `AlbumArtViewModel` instantiation.
- `Save Front Cover to all Tracks` On forces front-cover pin On and disabled, forces front-cover type scope to `allTrackPictures` and disabled, and pins new front-cover additions for unlocked tracks.
- `Save Front Cover to all Tracks` Off switches front-cover type scope back to `selectedTrackPictures` immediately and then lets front-cover pin/scope behavior follow `Pin Album Pictures` like any other slot.
2. Fixture/service tests if implementation changes save payload generation:
- verify per-track write payloads still match current pinned state
- verify locked tracks are excluded from forced front-cover and album-pin write behavior
- verify no hidden transient restoration path remains in save output
3. ViewInspector tests:
- `albumArt.sheet.trackPictureScopePicker` is absent.
- `Pin Track Pictures` disabled-state follows `Pin Album Pictures`.
- Front-cover `albumArt.sheet.typePictureScopePicker` disabled-state and bound value follow `Save Front Cover to all Tracks`.
- Toolbar and metadata remain inspectable after removing the sheet scope picker.
- Settings UI still exposes `Save all Pictures to all Tracks` with unchanged accessibility identifiers.
4. XCUI only if toolbar/menu behavior cannot be asserted reliably with ViewInspector.

## Acceptance Criteria
- The album-art sheet no longer contains `albumArt.sheet.trackPictureScopePicker`.
- Turning `Pin Album Pictures` On sets every current `Pin Track Pictures` state to On, disables those controls, and does not preserve previous values for restoration.
- Turning `Pin Album Pictures` Off sets every current `Pin Track Pictures` state to Off, enables those controls, and does not restore previous values.
- Locked tracks are excluded from those On/Off destructive pin rewrites.
- Newly added pictures default to pinned when `Pin Album Pictures` is On and default to unpinned when it is Off.
- Adding an already-referenced picture remains a no-op with respect to pin/reference state.
- Adding a picture to a slot that already references it navigates to the existing picture and remains a no-op with respect to pin/reference state.
- No pin-related transient/effective-state restoration logic remains in the implementation.
- `Save all Pictures to all Tracks` only sets the default initial `Pin Track Pictures` value at first `AlbumArtViewModel` creation and does not rewrite existing slot pin states when toggled later.
- `Save Front Cover to all Tracks` On forces front-cover pin On + disabled, forces front-cover type scope to `allTrackPictures` + disabled, and causes new front-cover additions to pin across loaded unlocked tracks only.
- `Save Front Cover to all Tracks` Off switches front-cover type scope to `selectedTrackPictures` immediately and then front-cover pin/scope follow `Pin Album Pictures` the same as any other slot.
- Locked tracks never have pin settings changed or picture data written to them due to album-pin or front-cover setting behavior.
- Save output follows the live current pin state, not a hidden effective override layer.

## Open Questions
- None currently.
