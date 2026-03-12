# Add Save Status View Plan

## Goal
Add a `SaveStatusView` overlay that appears (fading in) only while a track save operation is active for a given editor window, remains visible until the save finishes and any required minimum display duration is satisfied (fading out). The overlay shows the fish artwork over the current `ultraThinMaterial` plus blur background treatment, plus album and track-progress details for the current save.

## Scope
In scope:
- A new SwiftUI `SaveStatusView` for in-window save progress display.
- Save-lifecycle state needed to show and hide the overlay for each `ContentView` / editor window independently.
- Per-track progress reporting so the overlay can show the current track index and total tracks being saved.
- Timing behavior for minimum visible duration plus 0.25 second fade-in and fade-out transitions.
- Centered overlay presentation in the active `ContentView` associated with the current save operation.
- Save-time disabling of editable tag editor controls and album-art editing controls.
- Rendering the save-status overlay inside `AlbumArtSheetView` while the sheet is presented.
- Tests for save-status state transitions and targeted verification of save progress behavior.

Out of scope:
- Changing save-notification behavior after completion.
- Changing FLAC write semantics, save payload semantics, or save-scope semantics beyond the progress/status plumbing needed for this overlay.
- Adding cancelation, pause/resume, or user interaction inside the status view.
- Showing separate success or failure completion states after the save ends.

## Confirmed Decisions
- For all-tracks saves and picture-only saves, the left status label uses `Saving Album: …` with the current editor window’s `album` value from `TagEditorViewModel`.
- For selected-track saves, the left status label uses `Saving Track:` with the current track name shown in the adjacent value field.
- If a save fails or partially fails, the overlay is dismissed immediately and then the error alert is presented.
- The default minimum display duration is 1.5 seconds.
- Fade-in duration is 0.25 seconds.
- Fade-out duration is 0.25 seconds.
- The overlay is centered in the `ContentView` instance for the editor window that initiated the save.
- The overlay keeps the `Brightly_Colored_Fish-512-circle-alpha-full` artwork and uses the current `ultraThinMaterial` plus blur treatment underneath it.
- The bottom status row uses read-only `Text` views, not editable fields.
- The left side of the status row is split into a label view and a value view.
- The progress row reads, from left to right: label, album-or-track value, spacer, current track index, `of`, total track count.
- The status-row text uses appearance-aware color: white in Dark Mode and black in Light Mode.
- The status-row `Text` views are single-line and use the current middle truncation behavior when content exceeds the available width.
- During saves, editable tag editor controls and the main front-cover well are disabled and re-enabled when the save completes.
- If `AlbumArtSheetView` is open during a save, its editable album-art well interactions are disabled and the save overlay remains visible inside the sheet.

## Dependencies And Constraints
- Save execution is currently started in [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift) via `save(using:)`, while the per-track write loop currently lives in [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift). Progress display needs state from both layers.
- The current save API in [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift) is synchronous and returns only after the full save loop completes. Per-track overlay updates therefore require either a progress callback or a dedicated save-status model passed into that loop.
- Save failure handling currently happens back in [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift) by setting `saveErrorMessage` and toggling `isSaveErrorPresented`. The overlay dismissal rules must integrate cleanly with that path so failure does not leave the overlay onscreen.
- The save operation runs on the main actor today through `TagEditorViewModel`, so any timing or animation state added for the overlay must avoid blocking UI updates during multi-file saves.
- The plan should avoid introducing global cross-window overlay state. Each `ContentView` should own only the save-status state for its own editor session.
- The sheet overlay cannot rely on the editor-window `ZStack` alone because SwiftUI sheets render in a separate presentation layer; the sheet needs the same save-status data passed into it explicitly.

## High-Risk Concerns

### Product Or Behavioral Risks
- If progress state is updated only before the save loop starts or only after it ends, the overlay cannot correctly display the current track number during multi-track saves.
- If the minimum-display timer is enforced the same way for success and failure, the confirmed failure behavior would be violated by leaving the overlay visible while an error is waiting to appear.
- If the overlay is attached too high in the view tree or stored globally, one editor window could show another window’s save status.
- The status-row layout can become unstable if album titles are long or if single-digit and double-digit track counts are not given explicit width constraints.
- If the editor and album-art sheet do not share the same save-state source, one surface can remain interactive or lose the overlay while the other is saving.

### Tooling, Environment, Or Filesystem Risks
- The existing synchronous save path may make animation timing appear abrupt if write work monopolizes the main actor during file I/O. If that occurs, implementation may need a narrowly scoped async refactor or explicit main-actor progress hops.
- Full UI automation for fade timing can be fragile in Xcode. Most coverage should therefore live in unit tests for the status-state controller, with limited UI checks for presence and dismissal.
- The current `ultraThinMaterial` plus blur appearance can vary by macOS appearance and wallpaper, so the text color choice needs to remain legible in both Light and Dark Mode.

## Implementation Phases

### 1. Define a window-local save-status model
- Add a dedicated model to represent the overlay state for one editor window, for example:
  - visibility intent
  - currently displayed album string
  - current track index
  - total track count
  - save start time
  - pending minimum-display dismissal task, if needed
- Keep this model owned by `ContentView` or by a small helper type used only by `ContentView`, not by a global coordinator.
- Encode the rule that the overlay is hidden by default and only becomes visible at the start of a save operation.

### 2. Define the save-progress reporting contract
- Extend the save flow in [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift) so the caller can observe:
  - total tracks to be saved
  - the one-based index of the track currently being written
  - the display name of the track currently being written
- Recommended approach:
  - add a progress callback parameter to `save(...)`
  - invoke it once before each track write begins
  - keep the existing `SaveOperationResult` return shape unchanged unless implementation proves a richer result is necessary
- Ensure the callback reflects the actual save set after `scope` filtering, so selected-track saves show only the written subset.

### 3. Add minimum-duration and dismissal coordination
- Add logic in `ContentView` or a dedicated helper to:
  - show the overlay immediately when save starts
  - record the save start time
  - keep the overlay visible until either:
    - the save completes and the elapsed visible time is at least 1.5 seconds, or
    - the remaining time to reach 1.5 seconds has elapsed
- On successful save completion:
  - wait only for the remaining minimum-display interval, if any
  - then fade the overlay out
- On failure or partial failure:
  - dismiss the overlay immediately
  - do not wait for the minimum display duration
  - present the existing save error alert after dismissal state is applied

### 4. Build `SaveStatusView`
- Add a new SwiftUI view, likely under `SwiftTag/SwiftTag/Shared` or a focused feature/UI folder, named `SaveStatusView`.
- The view should:
  - use the current `ultraThinMaterial` plus blur treatment as the base background
  - render the `Brightly_Colored_Fish-512-circle-alpha-full` artwork above that background treatment
  - be sized intentionally around the 512x512 fish artwork rather than stretched arbitrarily
  - place the status row at the bottom of the view
  - render the row as read-only `Text` views
  - use appearance-aware text color: white in Dark Mode and black in Light Mode
  - constrain each status label to a single line with middle truncation
- The row layout should provide:
  - leftmost field:
  - `Saving Album:` for all-tracks saves
  - `Saving Track:` for selected-track saves
  - second field:
  - album value for all-tracks and picture-only saves
  - current track name for selected-track saves
  - spacer
  - center-aligned current-track field sized for 2 characters
  - centered `of` field
  - center-aligned total-track field sized for 2 characters

### 5. Present the overlay from `ContentView`
- Wrap the editor content in a presentation container such as `ZStack` so `SaveStatusView` can be centered over the current window’s content.
- Bind the overlay’s presence to the new save-status model instead of deriving it from general error or notification state.
- Apply `.transition(.opacity)` or equivalent fade behavior with 0.25 second animation for both appearance and disappearance.
- Pass the active save-status presentation into `AlbumArtSheetView` so the same overlay can render while the sheet is open.
- Keep existing alerts and file importer behavior intact unless the overlay integration requires a narrowly scoped layout adjustment.

### 6. Integrate with the existing save command flow
- Update `save(using:)` in [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift) to:
  - initialize the save-status model with the current album value, selected/all scope state, and computed total track count for the requested save scope
  - show the overlay before invoking the save loop
  - pass a progress callback into `viewModel.save(...)` that includes the current track display name
  - drive success dismissal timing after the save result returns
  - drive immediate failure dismissal in the `catch` path before presenting the alert
- Preserve existing notification scheduling and window registration after a successful save.
- Disable editable tag editor controls while `isSaveOperationRunning` is true.
- Disable the interactive album-art wells both in the main editor and in `AlbumArtSheetView` while `isSaveOperationRunning` is true.

### 7. Verify asset and sizing assumptions
- Confirm that `Brightly_Colored_Fish-512-circle-alpha-full` remains available in [Assets.xcassets](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Assets.xcassets).
- Verify that the fish artwork plus the current `ultraThinMaterial` and blur combination keeps the bottom text row legible in both Light and Dark Mode.
- Verify that the bottom text row remains legible over the image and does not overflow for longer album or track names at typical window sizes.

## Suggested File Updates
- Update [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift)
- Update [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift)
- Update [AlbumArtSheetView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/AlbumArt/AlbumArtSheetView.swift)
- Update [AlbumArtWellView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/AlbumArt/AlbumArtWellView.swift)
- Update [TagEditorAlbumView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorAlbumView.swift)
- Update [TagEditorView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorView.swift)
- Add or update `SaveStatusView` under `SwiftTag/SwiftTag/Shared` or a closely related UI folder
- Add a small save-status state/helper type if implementation benefits from separating timing logic from the view
- Update [SwiftTagTests.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTagTests/SwiftTagTests.swift) or split tests into focused files for save-status behavior

## Test Strategy
- Prefer unit tests first:
  - save-status timing rules for success
  - immediate dismissal on failure
  - correct current-track and total-track progress values for all-tracks and selected-tracks saves
  - minimum-duration enforcement when save completes faster than 1.5 seconds
  - no extra wait when save duration already exceeds 1.5 seconds
- Add service or view-model tests where practical:
  - `TagEditorViewModel.save(...)` invokes progress updates in one-based order for the actual saved track set
  - selected-track saves report the filtered count, not the full imported count
- Add limited UI verification:
  - the overlay appears centered during a save-triggered test seam
  - the overlay remains visible when `AlbumArtSheetView` is open during a save
  - the overlay disappears after success
  - the overlay dismisses before the save error alert appears on failure
  - the main editor controls are disabled during save and re-enabled afterward
  - album-art well interactions are disabled during save both in the main editor and in `AlbumArtSheetView`
  - `AlbumArtSheetView` album-art interactions should be re-enabled after the simulated save completes
  - Note: direct targeted UI verification of that sheet re-enable transition proved difficult because of repeated stumbling blocks in the current UI test harness; treat it as a follow-up TODO unless the harness is improved
- Use `BuildProject` for compile validation and prefer targeted tests over full UI automation if animation timing makes UI tests unstable.

## Open Questions
- No open questions at this time. Implementation should proceed with the confirmed decisions above.

## Acceptance Criteria
- A `SaveStatusView` exists and is hidden by default.
- Starting a save in an editor window shows the overlay centered in that window’s `ContentView`.
- The overlay uses the current `ultraThinMaterial` plus blur treatment underneath the `Brightly_Colored_Fish-512-circle-alpha-full` artwork.
- The overlay fades in over 0.25 seconds and fades out over 0.25 seconds.
- The overlay remains visible until the save ends and at least 1.5 seconds of display time has elapsed on successful saves.
- On save failure or partial failure, the overlay dismisses immediately and the existing save error alert is then shown.
- The bottom status row displays a left label (`Saving Album:` or `Saving Track:`), a left-aligned album-or-track value, the current track index, `of`, and the total track count with the requested alignment and styling.
- The album label/value pair is used for all-tracks saves and picture-only saves, and the track label/value pair is used for selected-track saves.
- The track progress values reflect the actual save scope for that save operation.
- Long status labels stay on one line and use middle truncation when needed.
- Text remains legible in both Light and Dark Mode.
- While saving, editable tag editor controls are disabled and then re-enabled when the save completes.
- While saving with `AlbumArtSheetView` open, the album-art editing well interactions are disabled and the save-status overlay remains visible inside the sheet.
- While saving with `AlbumArtSheetView` open, the album-art editing well interactions should be re-enabled after the save completes.
- Direct targeted UI verification of the sheet re-enable transition is deferred for now because the current UI test harness made that state change difficult to assert reliably; this remains a reasonable follow-up TODO if the harness is improved.
- The implementation is covered by unit tests for timing/progress behavior plus targeted compile and UI verification.
