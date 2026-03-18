# Add UI Feedback Settings Plan

## Goal
Deliver configurable UI feedback for theme, save notifications, and tag-diff formatting, while migrating
editor behavior to selection-scoped metadata editing with explicit multi-state diff precedence.

## Status
Implemented.

This plan now reflects the current implemented behavior and nomenclature.

## Scope
In scope:
- Add `Feedback` settings tab with persisted controls for save notifications, theme, and diff colors.
- Add `Diff Tools` utility window with persisted formatting toggles.
- Migrate album-related editor fields to selection-scoped editing (`album`, `albumArtist`, `totalTracks`).
- Make `totalTracks` editable and mismatch-aware.
- Make `totalDiscs` selection-scoped editable (per-track tag values), including mixed-selection marker behavior.
- Centralize diff presentation via a shared style resolver/modifier with explicit precedence.
- Preserve existing external-file difference detection as source of truth for externally modified state.
- Add targeted test coverage for settings defaults and key diff/model behaviors.

Out of scope:
- FLAC bridge C-layer behavior changes.
- Filename deleted-file strikethrough behavior changes.
- Full UI redesign of settings windows.
- Full-suite test runs as part of this implementation plan.

## Implemented Behavior

### 1. Settings And Persistence
- `Feedback` tab exists after `Tags` in `SettingsView`.
- Save notification mode is persisted:
  - `Always`
  - `When Not Frontmost`
  - `Never`
- Theme is persisted:
  - `System`
  - `Light`
  - `Dark`
- Diff colors are persisted:
  - `Track to Track Diff Color` (default orange)
  - `Track to File Diff Color` (default system/default text color)
  - `Externally Modified Diff Color` (default red)
  - `Track/Disc Total Mismatch Color` (default red)

### 2. Diff Tools Toggles (Current Names)
- `Format on Track to File Diff`
- `Format on Track to Track Diff`
- `Format on Externally Modified Diff`
- `Format on Track Total Mismatch`
- `Format on Disc Total Mismatch`

All toggles are persisted in `@AppStorage`.

### 3. Key/Default Nomenclature
Implemented nomenclature uses `formatOn...` for mismatch toggles:
- `FeedbackSettingsKey.formatOnTrackTotalMismatch`
- `FeedbackSettingsKey.formatOnDiscTotalMismatch`
- `FeedbackSettingsDefaults.formatOnTrackTotalMismatch`
- `FeedbackSettingsDefaults.formatOnDiscTotalMismatch`

### 4. Diff State Model
The shared style resolver models:
- Track-to-track difference
- Track-to-file difference
- Externally modified difference
- Mismatch warning
- Invalid state (for misc key validation)

### 5. Diff Precedence
Current precedence in the shared resolver:
1. Invalid state (foreground red)
2. Mismatch warning foreground/background uses `Track/Disc Total Mismatch Color`
3. Externally modified foreground (if enabled)
4. Track-to-file foreground (if enabled)
5. Track-to-track foreground/background (if enabled)
6. Default foreground

Notes:
- Externally modified still controls italic/bold when active.
- Track-to-file controls bold when active.
- Track-to-track applies background and foreground color when active.
- Mismatch warning color intentionally overrides other text colors to remain globally visible.

### 6. Track Metadata Ownership
- `album`, `albumArtist`, and `totalTracks` are selection-scoped editable and can differ by track.
- Mixed selection values render `*`.
- Editing writes to selected unlocked tracks only.

### 7. Total Tracks / Total Discs Behavior
- `totalTracks`:
  - Editable in core tags view.
  - Mismatch warning shown when enabled and write strategy is not `.none`.
- `totalDiscs`:
  - Editable as selection-scoped per-track tag value (`TOTALDISCS`/`DISCTOTAL`), not global editor-only value.
  - Mixed selection displays `*`.
  - Editing updates selected unlocked tracks only.
  - Mismatch warning shown when enabled and disc-count write strategy is not `.none`.

### 8. Mismatch Logic
- Track total mismatch:
  - True when any loaded track has non-empty total-tracks value that differs from loaded track count.
- Disc total mismatch:
  - True when loaded tracks disagree on total-discs values, or
  - Any track has `discNumber > max(totalDiscs)` among tracks that have total-discs values.

### 9. Misc Tags Behavior
- Track-to-track formatting applies to misc **value** field only.
- Mixed misc values show `*`.
- Track-to-file misc diff detection accounts for missing snapshot values.

### 10. Date Field Behavior
- Date editing uses text-based selection binding to allow mixed marker (`*`) display and diff styling visibility.

## Dependencies And Constraints
- Selection-based editing must continue to skip locked tracks.
- External diff source of truth remains file snapshot comparisons and tracked external-difference state.
- Write mapping must continue to honor save settings (`TrackCountKeyStrategy`, `DiscCountKeyStrategy`,
  padding rules).
- FLAC fixture tests should continue to use copied fixtures.

## Destructive / Write-Back Behavior
- Preserved:
  - Existing non-target tags still round-trip via write mapper merge behavior.
  - Save payload semantics (`tags`, `pictures`, both) are preserved.
  - Filename deleted-file styling is unchanged.
- Replaced:
  - Album/artist/track-count writing now follows selection-scoped per-track state.
  - Total-discs editing is selection-scoped per-track behavior.
- Removed:
  - Deprecated mismatch nomenclature based on `warnOn...` keys/defaults.

## Verification Summary
Implemented verification included:
- Targeted compiler diagnostics on touched files.
- Repeated successful `BuildProject` runs.
- Targeted tests for:
  - Feedback settings defaults
  - Selected album mixed-marker binding behavior
  - Fixture import bindings via ViewInspector
  - Additional targeted per-track/misc diff tests (noting intermittent `No result` behavior in this environment)

## Acceptance Criteria (Implemented State)
- Feedback settings and Diff Tools toggles persist and apply.
- Theme/save notification preferences are persisted and consumed.
- Diff formatting reflects track-to-track, track-to-file, externally modified, and mismatch states with
  documented precedence.
- Total-tracks and total-discs mismatch formatting uses the dedicated mismatch color for foreground and
  background when mismatch formatting is enabled.
- Album/artist/total-tracks are selection-scoped editable with mixed-marker behavior.
- Total-discs editing is per-track/selection-scoped and no longer treated as one global editor-only value.
- Misc/date edge cases above are handled.

## Follow-Up Notes
- Keep window-scene theme application centralized to avoid conflicting `preferredColorScheme` applications
  between scene roots and leaf views.
- Consider adding a small deterministic test surface around `TagDiffPresentation.resolve(...)` if runner
  instability (`No result`) continues for isolated tests.
