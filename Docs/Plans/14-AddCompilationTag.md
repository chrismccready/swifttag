# Add Compilation Tag Plan

## Goal
Add `COMPILATION` tag support so SwiftTag can read, edit, diff, and save a `Compilation` toggle in the core tag editor.

## Scope
In scope:
- Add a `Compilation` toggle to `TagEditorCoreTagsView` after total discs and before genre.
- Add a canonical `TagKey.compilation = "COMPILATION"` and update explicit-tag handling so the key is editor-owned instead of misc-tag-only.
- Remove `Update Track Total on Locked Tracks` and all related functionality so locked tracks are no longer editable through that path.
- Replace that removed setting with an `Apply Compilation to all Tracks` toggle that defaults to Off.
- Read `COMPILATION` values into editor state using the requested boolean mapping:
- absent key -> toggle Off
- empty string -> toggle Off
- any non-empty string -> toggle On
- Save `COMPILATION` using the requested write rules:
- toggle Off -> do not write the key
- toggle On -> write `COMPILATION = "1"`
- Apply compilation edits using the requested scope rules:
- `Apply Compilation to all Tracks` Off -> update only the currently selected unlocked tracks
- `Apply Compilation to all Tracks` On -> update all loaded unlocked tracks like an album-level field
- Add targeted tests for mapping, editor state, save serialization, and core-tags view wiring.

Out of scope:
- Adding a separate settings option for compilation-tag serialization.
- Supporting alternate write values such as `0`, `true`, or `yes`.
- Adding non-FLAC-specific compilation behavior outside the existing tag editor and FLAC read/write flows.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/13-AddFLACFingerprintSupport.md`.
- Current implementation files reviewed:
- `SwiftTag/SwiftTag/Features/TagEditor/TagEditorCoreTagsView.swift`
- `SwiftTag/SwiftTag/Features/TagEditor/TagEditorView.swift`
- `SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
- `SwiftTag/SwiftTag/Features/FlacImport/FlacImportMapper.swift`
- `SwiftTag/SwiftTag/Features/FlacImport/FlacWriteMapper.swift`
- `SwiftTag/SwiftTag/Shared/Models/TagKey.swift`
- `SwiftTag/SwiftTag/Shared/Utilities/TagNormalization.swift`
- `SwiftTag/SwiftTag/Shared/Models/Track.swift`
- `SwiftTag/SwiftTag/Shared/Models/TrackStatus.swift`
- `SwiftTag/SwiftTag/Shared/Models/FeedbackSettings.swift`
- `SwiftTag/SwiftTag/Shared/Models/SaveSettings.swift`
- `SwiftTag/SwiftTag/ContentView.swift`
- `SwiftTag/SwiftTag/Features/Settings/TagWriteSettingsView.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Relevant fixtures inspected:
- `SwiftTagTestFiles/test.flac`
- `SwiftTagTestFiles/test-with_padding.flac`
- Constraints accounted for:
- `TagEditorCoreTagsView` currently accepts only `Binding<String>?` core-tag inputs, so `Compilation` will need a new boolean or toggle-specific seam instead of reusing the existing text-field API unchanged.
- `TagEditorViewModel.selectedTagBinding(tagName:)` currently exposes mixed selection with the `*` marker, which does not directly answer how a toggle should behave when selected tracks disagree.
- `FlacWriteMapper.makeTags(...)` starts from trimmed current `track.tags`, then removes/rebuilds explicit keys. `COMPILATION` must be treated as an explicit key so turning the toggle Off removes an existing file value instead of writing it back accidentally.
- External-difference and snapshot comparisons already operate on normalized tag dictionaries, so once `COMPILATION` is part of the expected-file tag set it should participate in save-status and reload flows consistently.
- `TagEditorCoreTagsView` constructor churn affects `TagEditorView`, `ContentView`, and `TrackStatusViewInspectorTests`, so the plan should include UI wiring updates and test fixture updates together.
- `TagWriteSettingsView`, `SaveSettings`, and `ContentView` currently expose `Update Track Total on Locked Tracks`, so the plan must explicitly remove the setting key, defaults, UI toggle, and the `setTrackTotalToCurrentCount(includeLockedTracks:)` behavior that bypasses lock protection.

## Current Implementation Snapshot
- `TagKey` and `TagNormalization.explicitTagKeys` do not include `COMPILATION`.
- FLAC import mapping leaves unknown keys in `track.tags`, but there is no dedicated editor-facing compilation state or toggle binding.
- Core-tag editing currently uses text fields for number, disc, genre, artist, composer, location, date, and description, with no existing boolean tag control in `TagEditorCoreTagsView`.
- Selected-tag editing for per-track fields flows through `selectedTagBinding(tagName:)`, which returns a string and uses the mixed-selection marker when values differ.
- Save serialization in `FlacWriteMapper` rebuilds track/disc explicit keys but does not currently special-case `COMPILATION`.
- Diff formatting identifiers include genre/artist/composer/location/date/description but not compilation.
- `TagWriteSettingsView` currently shows `Update Track Total on Locked Tracks`, backed by `SaveSettingsKey.updateTrackTotalOnLockedTracks`, and `ContentView` still passes that setting into `setTrackTotalToCurrentCount(includeLockedTracks:)`.

## Confirmed Decisions
- Add the `Compilation` toggle to `TagEditorCoreTagsView` after total discs and before genre.
- The `Compilation` toggle defaults to Off.
- Add canonical support for `TagKey.compilation = "COMPILATION"`.
- When reading tags, absent `COMPILATION` means the toggle is Off.
- When reading tags, empty-string `COMPILATION` means the toggle is Off.
- When reading tags, any non-empty `COMPILATION` value means the toggle is On.
- When the toggle is Off, `COMPILATION` is not written at save.
- When the toggle is On, `COMPILATION` is written at save with the value `"1"`.
- When selected tracks disagree on `COMPILATION`, the control should show an indeterminate/mixed state.
- The mixed state should use `trackToTrackDiffColor` for emphasis if practical, preferring the control itself and falling back to the label if the control cannot be styled directly.
- Remove `Update Track Total on Locked Tracks` and all of its current functionality.
- Locked tracks should no longer be editable through that removed track-total path.
- Add an `Apply Compilation to all Tracks` setting in place of the removed toggle, defaulting to Off.
- When `Apply Compilation to all Tracks` is Off, changing `Compilation` updates only the currently selected unlocked tracks.
- When `Apply Compilation to all Tracks` is On, changing `Compilation` updates all loaded unlocked tracks like an album-level field.
- When `Apply Compilation to all Tracks` is On and no tracks are selected, the `Compilation` control remains enabled and reflects all loaded unlocked tracks.

## Dependencies And Constraints
- `COMPILATION` must be treated as an explicit editor-owned tag so it disappears from misc-tag editing and participates in expected-file tag generation.
- The compilation-scope behavior depends on a persisted settings source of truth that replaces `updateTrackTotalOnLockedTracks`.
- Save behavior must preserve the current tag-only and picture-only split:
- tag-only saves may add/remove `COMPILATION` while leaving pictures unchanged
- picture-only saves must leave `COMPILATION` unchanged on disk
- Existing tag-save behavior replaces destination Vorbis comments with the generated non-empty tag set when tag writing is requested, so the plan must make the remove-vs-preserve behavior explicit.
- “Selected items” means the current track-table selection in `TagEditorTrackFileView`.
- Locked tracks must remain excluded from both track-total auto-updates and compilation edits.
- Toggle enablement should align with the existing save-running and lock gates, while remaining enabled without a selection when `Apply Compilation to all Tracks` is On.

## High-Risk Concerns
### Product / Behavioral Risks
- Mixed selected values now need a true indeterminate state. If the visual treatment is too subtle, users may not realize they are overwriting differing track values.
- If `COMPILATION` is not removed from the explicit-key rebuild path, turning the toggle Off could still write back a stale non-empty value from `track.tags`.
- If import/read logic and expected-file serialization use different boolean rules, save-status indicators could show false differences or miss real ones.
- If the removed locked-track setting leaves behind code paths in `ContentView` or `TagEditorViewModel`, locked tracks could still be mutated despite the new rule.

### Tooling / Environment / Sandbox Risks
- Verification should prefer copied FLAC fixtures and targeted tests because save-path changes touch file I/O and Xcode MCP SwiftUI tests can be slow or brittle.
- `TagEditorCoreTagsView` initializer changes will fan out into multiple preview/test call sites, so compile validation should happen early with `BuildProject` before deeper testing.

## Implementation Phases
1. Add Explicit Tag, Settings, And Diff Identifier Support
- Add `TagKey.compilation`.
- Add `COMPILATION` to `TagNormalization.explicitTagKeys`.
- Extend `DiffTagIdentifier` with `.compilation` and display text if the toggle will use `tagDiffStyle`.
- Replace `SaveSettingsKey.updateTrackTotalOnLockedTracks` and its default with a new `applyCompilationToAllTracks` setting that defaults to Off.
- Update `TagWriteSettingsView` to replace the removed toggle with `Apply Compilation to all Tracks`.

2. Add View-Model Compilation Semantics
- Remove any `includeLockedTracks` behavior used by track-total updates so locked tracks can no longer be mutated by that feature.
- Introduce a toggle-friendly selection API in `TagEditorViewModel`, likely separate from `selectedTagBinding(tagName:)`, that maps selected track values to On/Off/mixed and writes back `"1"` or removal according to the confirmed rules.
- Resolve the edited track set from `Apply Compilation to all Tracks`:
- Off -> selected unlocked tracks
- On -> all loaded unlocked tracks
- Keep the `Compilation` control enabled without a selection when `Apply Compilation to all Tracks` is On, and derive its displayed state from all loaded unlocked tracks in that mode.
- Define how the view model detects internal, file, and externally modified differences for `COMPILATION`.
- Ensure locked selected tracks remain unchanged and existing difference-clearing behavior still applies.

3. Wire The Core Tags UI
- Update `TagEditorCoreTagsView` to accept the compilation binding/state and render a `Toggle("Compilation", ...)` between total discs and genre.
- Add indeterminate-state presentation and apply `trackToTrackDiffColor` to the control or label when the value is mixed.
- Update `TagEditorView`, `ContentView`, and any helper computed properties to pass the new binding, scope setting, and difference flags through.

4. Update Read, Snapshot, And Save Serialization
- Ensure imported/reloaded track tags preserve or normalize `COMPILATION` so the toggle reflects the requested absent/non-empty rules.
- Update `FlacWriteMapper.makeTags(...)` so `COMPILATION` is rebuilt explicitly:
- omit the key when the toggle state is Off
- write `COMPILATION = "1"` when the toggle state is On
- Confirm expected-file snapshots and external-difference comparison pick up the same generated value so save-status behavior stays consistent after write/reload cycles.

5. Add Targeted Tests And Verification
- Add settings tests for the replacement toggle default and persistence seam.
- Add unit tests for read mapping and serialization rules:
- absent key -> Off
- empty string -> Off
- non-empty values such as `"1"` or `"0"` -> On
- toggle On serializes as `"1"`
- toggle Off omits `COMPILATION`
- Add view-model tests covering selected-track propagation, apply-all propagation, lock gating, and mixed-state behavior.
- Update `TrackStatusViewInspectorTests` or similar targeted view tests for the new `TagEditorCoreTagsView` initializer and toggle placement/wiring.
- Add a copied-fixture save/re-read test if implementation touches the live FLAC write path beyond mapper-only serialization.

## Test Strategy
Order:
1. Pure unit tests:
- `TagNormalization` treats `COMPILATION` as explicit
- replacement setting defaults `Apply Compilation to all Tracks` to Off
- toggle-state read mapping follows absent/empty/non-empty rules
- `FlacWriteMapper` writes `"1"` when On and omits the key when Off
2. View-model tests:
- selected unlocked tracks receive the compilation change
- apply-all mode updates all loaded unlocked tracks
- apply-all mode remains editable and derives its displayed state even when no tracks are selected
- locked selected tracks do not change
- track-total updates no longer mutate locked tracks through the removed setting path
- diff detection includes `COMPILATION`
- mixed-selection behavior matches the confirmed decision
3. Targeted SwiftUI/ViewInspector tests:
- `TagEditorCoreTagsView` exposes `Compilation` between total discs and genre
- the toggle respects enabled/disabled state
- the mixed state uses the chosen highlight approach
- settings show `Apply Compilation to all Tracks` instead of `Update Track Total on Locked Tracks`
4. Copied-fixture bridge/service test if needed:
- write tags to a copied FLAC fixture, re-read, and verify `COMPILATION` is present when On and absent when Off
5. Verification workflow:
- `BuildProject`
- targeted `RunSomeTests`
- avoid full-suite runs unless a broader regression demands it

## Acceptance Criteria
- The core tags area shows a `Compilation` toggle after total discs and before genre.
- When selected tracks disagree on `COMPILATION`, the control shows an indeterminate state highlighted with `trackToTrackDiffColor` or the documented fallback styling.
- Import/read behavior maps absent or empty `COMPILATION` to Off.
- Import/read behavior maps any non-empty `COMPILATION` value to On.
- `COMPILATION` is treated as an explicit editor-owned tag and is not managed as a misc tag.
- Saving tags with the toggle On writes `COMPILATION = "1"`.
- Saving tags with the toggle Off omits `COMPILATION`.
- Picture-only saves do not change `COMPILATION`.
- Settings no longer expose `Update Track Total on Locked Tracks`.
- Settings expose `Apply Compilation to all Tracks`, default Off.
- When `Apply Compilation to all Tracks` is Off, compilation edits affect only selected unlocked tracks.
- When `Apply Compilation to all Tracks` is On, compilation edits affect all loaded unlocked tracks.
- When `Apply Compilation to all Tracks` is On and no tracks are selected, the `Compilation` control stays enabled and reflects all loaded unlocked tracks.
- Locked tracks are no longer editable through the removed track-total-on-locked path.
- Save-status and external-difference behavior stay consistent with the generated `COMPILATION` value.
- Targeted automated tests cover mapping, serialization, and the toggle wiring.

## Open Questions
- None currently.
