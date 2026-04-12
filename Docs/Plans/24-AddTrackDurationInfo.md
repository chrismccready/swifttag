# Add Track Duration Info Plan

## Goal
Add derived FLAC track duration support throughout SwiftTag so that:
- imported FLAC tracks expose a `duration` value derived from STREAMINFO metadata
- the track table can optionally show a `Duration` column formatted as `MM:SS` for durations under one hour and `HH:MM:SS` when hours are present
- `.swifttag` documents persist `Duration` so Quick Look can render duration without reopening live FLAC files
- Quick Look track rows show the duration trailing after the title with a spacer pushing the value to the right edge

## Scope
In scope:
- Extend the libFLAC bridge / Swift service layer to read STREAMINFO sample rate and total samples.
- Add `duration` to `Track` and propagate it through all FLAC-import and document-load paths.
- Add a hidden-by-default `Duration` table column with AppStorage-backed visibility state and context-menu toggle.
- Persist `Duration` in `.swifttag` manifests and restore it on read.
- Update Quick Look snapshot and view models to display a trailing formatted duration.
- Add targeted tests for bridge extraction, table visibility/ordering, manifest round-tripping, and Quick Look formatting.

Out of scope:
- Editing duration manually in the UI.
- Recomputing duration from audio frames in Swift without libFLAC.
- Adding a Settings screen control for the Duration column preference.
- Treating duration changes as user-editable diffs or unsaved tag changes.
- Changing FLAC writeback behavior for tags or pictures.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed:
  - `Docs/Plans/23-AddSwiftTagDocumentQuickLook.md`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
- Relevant implementation files reviewed:
  - `SwiftTag/FLACBridge/include/FlacMetadataBridge.h`
  - `SwiftTag/FLACBridge/src/FlacMetadataBridge.c`
  - `SwiftTag/FlacMetadataService.swift`
  - `SwiftTag/Shared/Models/Track.swift`
  - `SwiftTag/Shared/Models/FeedbackSettings.swift`
  - `SwiftTag/Features/TagEditor/TagEditorView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorTrackFileView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentSupport.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackageManifest.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackageReader.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackageWriter.swift`
  - `SwiftTag/Shared/QuickLook/SwiftTagDocumentQuickLookSnapshot.swift`
  - `SwiftTag/Shared/QuickLook/SwiftTagDocumentQuickLookView.swift`
  - `SwiftTagTests/SwiftTagDocumentTests.swift`
  - `SwiftTagTests/SwiftTagQuickLookTests.swift`
  - `SwiftTagTests/TrackStatusViewInspectorTests.swift`
- Relevant fixtures inspected:
  - `SwiftTagTestFiles/test.flac`
  - `SwiftTagTestFiles/test-with_padding.flac`
- Constraints accounted for:
  - The current FLAC service reads tags, pictures, and fingerprint, but does not expose STREAMINFO duration data.
  - `TagEditorViewModel` reads FLAC metadata in more than one path: initial import, selected-track reload, post-write snapshot refresh, and live file-state refresh.
  - The track table already has a column-visibility pattern via `showsFingerprintColumn` backed by `@AppStorage` in `ContentView` and `FeedbackSettings`.
  - Quick Look currently renders each track row as a single combined string, so trailing duration alignment requires a row-model shape change rather than a string-format tweak.
  - `.swifttag` manifest decoding is strict on version equality but tolerant of additive optional fields, so this feature can remain backward compatible if the new duration field is optional on read.

## FLAC Duration Reference
Consulted sources:
- RFC 9639 Section 8.2 (`STREAMINFO`)
- libFLAC format/API documentation for `FLAC__StreamMetadata_StreamInfo`

Confirmed format facts to drive implementation:
- `STREAMINFO.sample_rate` is the stream sample rate in Hz.
- `STREAMINFO.total_samples` is the total number of interchannel samples in the stream.
- RFC 9639 explicitly notes that where sample counts are mentioned, interchannel samples are meant, so duration is `total_samples / sample_rate` with no channel-count adjustment.
- RFC 9639 also states `total_samples == 0` means the total sample count is unknown, and `sample_rate == 0` can occur for non-audio content.

Implementation implication:
- SwiftTag should derive duration from STREAMINFO only and should not divide by channel count.
- When either source value is unusable for a timed audio duration, SwiftTag should store `nil` and render an empty string per the confirmed decisions below.

## Current Implementation Snapshot
- `FlacMetadataService.readTags(for:)` currently performs three bridge reads:
  - Vorbis comments via `flac_read_tags`
  - pictures via `flac_read_pictures`
  - MD5 fingerprint via `flac_read_fingerprint`
- `Track` currently stores editor-facing metadata, pictures, file references, snapshots, and fingerprint, but no duration.
- `TagEditorViewModel.importFlacFiles(...)` creates new `Track` values from `FlacMetadataService.readTags(for:)`.
- `TagEditorViewModel` also re-reads FLAC metadata in live refresh paths, which means duration must be updated in those paths as well:
  - selected-track reload
  - post-write snapshot refresh
  - file-monitor refresh / external change reload
- `TagEditorTrackFileView` already supports one optional column (`Fingerprint (ffp)`) with a context-menu toggle and source-order tests.
- `.swifttag` manifests currently persist tags, pictures, file URLs/bookmarks, and FLAC fingerprint, but not duration.
- The current `.swifttag` writer persists `flacFingerprint` as a separate field, but existing per-track and document manifest fingerprints are derived only from normalized tags and picture metadata.
- Quick Look snapshot rows are currently modeled as one `text` field plus an ellipsis flag, which cannot express title-left/duration-right layout.

## Confirmed Decisions
- `duration` is optional on `Track`. Missing or unusable STREAMINFO duration metadata is stored as `nil`.
- Formatting uses whole-second truncation, not rounding.
- Displayed duration is:
  - `MM:SS` when the truncated duration is under one hour
  - `HH:MM:SS` when the truncated duration is one hour or more
- Missing or unknown duration metadata displays as an empty string in the track table and in Quick Look.
- Quick Look should always reserve the trailing duration slot in each track row.
- The `Duration` column is hidden by default.
- The `Duration` column sits between `Title` and `Filename`.
- `.swifttag` should persist `Duration` with full decimal precision when the value is known.
- `Duration` should not participate in the existing tag-and-picture manifest fingerprint calculation.

## Data Persistence Behavior
- Preserved data:
  - Existing tag, picture, bookmark, file-reference, and fingerprint persistence remains unchanged.
  - Existing `.swifttag` documents without duration remain readable.
- Replaced data:
  - On each `.swifttag` save, the saved `Duration` value for each exported track is overwritten with the current in-memory derived `duration` value for that track when known, or omitted when unknown.
- Removed data:
  - None.
- Save-scope source of truth:
  - SwiftTag document export continues to use `validatedSwiftTagDocumentExportTracks()`, which exports the current `trackItems` list rather than a selection subset.
- Partial-save behavior:
  - No new partial-save mode is introduced. Any track included in a SwiftTag document export also persists its current `duration`.

## Dependencies And Constraints
- Prefer a single STREAMINFO bridge accessor over separate fingerprint-only logic so duration and fingerprint stay derived from the same metadata read.
- Keep duration as derived technical metadata, not a user-editable tag, so it should not participate in tag diff styling, misc-tag editing, or unsaved-change comparisons.
- The track table and Quick Look both need the same duration formatting rules; a shared formatter utility is preferable to duplicating string math.
- Because the document-format change is additive, the manifest duration field should be optional on decode to preserve old document compatibility.
- Persist duration with full `Double` / `TimeInterval` precision in the manifest rather than pre-formatting or rounding for storage.
- Keep the existing manifest fingerprint semantics scoped to tags and pictures only; do not add either `Duration` or `flacFingerprint` to the current track/document fingerprint calculation unless a later document-format change explicitly redefines that fingerprint.
- Quick Look must continue to rely only on saved `.swifttag` contents and must not attempt live FLAC access for duration.
- Existing tests already validate table source order and context-menu source declarations in `TrackStatusViewInspectorTests`; duration-column checks should follow the same low-fragility pattern.

## High-Risk Concerns
### Product / Behavioral Risks
- If duration is updated only on initial import, the table and saved documents will become stale after selected-track reloads or external file refreshes.
- If the formatter uses locale-aware or date-based APIs without strict control, `MM:SS` / `HH:MM:SS` output may drift from the requested zero-padded format.
- If Quick Look continues to model rows as a single string, it will not be able to right-align duration independently from the title.
- If `duration` is accidentally fed into diff/dirty-state logic, metadata-only UI could start showing unrelated change noise for a derived field users cannot edit.
- If unknown duration is collapsed to `0` instead of `nil`, legacy `.swifttag` documents will show fabricated zero-length tracks and may persist those fabricated values on later saves.

### Tooling / Environment / Filesystem Risks
- STREAMINFO values are read from metadata, not decoded frames, so malformed FLAC metadata could report unusable values; the bridge and Swift layer need explicit `nil` fallback behavior.
- Padded FLAC files should still yield the same duration as equivalent non-padded files; fixture coverage should confirm the bridge path is insensitive to padding layout.
- The Quick Look extension uses shared code but separate rendering context, so any new formatter/helper used there must remain available to both the app target and the preview target.

## Implementation Phases
1. Extend STREAMINFO Access And Track Model
- Add a bridge result type that exposes at least:
  - `sample_rate`
  - `total_samples`
  - `md5sum` or equivalent fingerprint payload
- Replace or supersede `flac_read_fingerprint` with a STREAMINFO-oriented accessor so `FlacMetadataService` reads fingerprint and duration-related metadata in one pass.
- Update `FlacMetadataRecord` to include raw or derived duration data with full precision.
- Add `duration` to `Track` as a non-editable derived value, preferably `TimeInterval?` / `Double?`.
- Update every `Track` construction and metadata-refresh path to populate `duration`:
  - FLAC import
  - SwiftTag document load
  - selected-track reload
  - post-write metadata refresh
  - live file-monitor refresh

2. Add Shared Duration Formatting
- Introduce a shared helper, for example `TrackDurationFormatter`, that:
  - accepts raw seconds or `TimeInterval?`
  - truncates to whole seconds
  - returns zero-padded `MM:SS` for durations under one hour
  - returns zero-padded `HH:MM:SS` when hours are present
  - returns an empty string for `nil` or otherwise invalid/unusable values
- Keep the formatter deterministic and non-localized so the table and Quick Look match exactly.

3. Add Duration Column And Visibility Preference
- Add a new AppStorage key and default in `FeedbackSettingsKey` / `FeedbackSettingsDefaults`, following the existing fingerprint-column pattern.
- Add `@AppStorage` backing in `ContentView` and pass a new binding through `TagEditorView` into `TagEditorTrackFileView`.
- Add a `Duration` `TableColumn` between `Title` and `Filename`.
- Render the displayed value with the shared duration formatter.
- Add a context-menu item whose title flips between:
  - `Show Duration` when hidden
  - `Hide Duration` when visible
- Do not make the column visible by default.

4. Persist Duration In SwiftTag Documents
- Extend `SwiftTagDocumentExportTrack` and `SwiftTagDocumentImportTrack` with `duration`.
- Add an additive manifest field on each track record named `Duration`, encoded as raw seconds with full decimal precision when the duration is known.
- Update `SwiftTagDocumentPackageWriter` to persist the `Duration` field for every exported track.
- Update `SwiftTagDocumentPackageReader` to decode the `Duration` field when present and leave `duration == nil` when absent.
- Keep the existing tag-and-picture fingerprint calculation unchanged so duration persistence does not affect current track/document manifest fingerprint values.
- Keep `SwiftTagDocumentType.version` unchanged unless implementation proves an additive optional field is insufficient.

5. Update Quick Look Snapshot And View Layout
- Replace the current single-string `TrackRow` model with a shape that can carry at least:
  - leading title text (`TRACKNUMBER TITLE`)
  - trailing duration text (`MM:SS`, `HH:MM:SS`, or empty)
  - ellipsis state
- Keep the current ordering and ellipsis rules, but when the overflow row is `...`, leave the trailing duration slot empty while preserving the row layout.
- Update `SwiftTagDocumentQuickLookView` to render each track row as an `HStack`:
  - leading title text
  - `Spacer()`
  - trailing duration text aligned to the trailing edge
- Ensure the duration comes from saved `Duration`, not recalculation from live FLAC state.

6. Validate Non-Editable Derived-Field Behavior
- Confirm duration does not participate in:
  - tag diff formatting
  - track dirty-state calculations
  - save-option logic for tag/picture writeback
- Confirm metadata-only save paths that rewrite Vorbis comments or pictures do not change audio-derived duration, even though refresh paths may re-read and repopulate it.

## Test Strategy
Order:
1. Pure logic / formatter tests
  - `TrackDurationFormatter` truncates fractional seconds.
  - `TrackDurationFormatter` returns `MM:SS` below one hour and `HH:MM:SS` at one hour or above.
  - `nil` duration renders as an empty string.
  - Large durations still format predictably without day-based rollover behavior.

2. Service / bridge tests using fixtures
  - Read `SwiftTagTestFiles/test.flac` and assert the extracted duration matches `Double(6754) / 44100.0` with full-precision service-level comparison tolerance.
  - Read `SwiftTagTestFiles/test-with_padding.flac` and verify duration extraction yields the same full-precision value.
  - Add a bridge/service assertion that duration is derived from `total_samples / sample_rate` without channel-count adjustment.

3. ViewInspector / focused UI tests
  - Extend `TrackStatusViewInspectorTests` or add a sibling file to verify `TagEditorTrackFileView` receives a duration-column visibility binding.
  - Add a source-order assertion that `Duration` is declared between `Title` and `Filename`.
  - Add a source-based or inspectable assertion that the context menu declares the `Show Duration` / `Hide Duration` toggle action.
  - Add a lightweight actual-view assertion that the new binding controls whether the duration column is emitted.
  - Use seeded duration values in view-model or formatter-level tests to cover both `MM:SS` and `HH:MM:SS` display paths because the checked-in FLAC fixtures are sub-second.

4. Document round-trip tests
  - Extend `SwiftTagDocumentTests` to save a `.swifttag` document with a known fractional `duration` and verify the `Duration` field persists it with full precision.
  - Verify read-back restores the saved duration.
  - Verify older documents without the new key still decode with `duration == nil`.
  - Verify current track/document manifest fingerprints remain unchanged by duration-only differences.

5. Quick Look tests
  - Extend `SwiftTagQuickLookTests` so snapshot rows include trailing formatted duration text.
  - Cover both `MM:SS` and `HH:MM:SS` display cases with seeded duration values.
  - Verify `nil` duration yields an empty trailing slot.
  - Verify snapshot ordering/ellipsis still works when duration is present.
  - Add a focused structure or source assertion that the Quick Look row layout uses a spacer before the trailing duration text.
  - Keep the existing bitmap-render smoke test to ensure the preview still renders non-empty output after the row-layout change.

6. Verification workflow
  - Build the project.
  - Run targeted test files rather than the full suite first:
    - document tests
    - Quick Look tests
    - track-table ViewInspector tests
  - Perform a manual editor sanity check that:
    - the Duration column is hidden on first launch
    - the context menu can show and hide it
    - displayed values match `MM:SS` below one hour and `HH:MM:SS` when hours are present
  - Perform a manual Quick Look sanity check on a saved `.swifttag` document and confirm duration appears trailing after the track title.

## Acceptance Criteria
- FLAC import reads STREAMINFO sample rate and total samples and derives `duration` as `total_samples / sample_rate` without channel-count adjustment.
- Unusable or missing STREAMINFO duration inputs fall back to stored duration `nil` and displayed duration `""`.
- `Track` exposes `duration`, and all metadata refresh paths keep it up to date.
- The tracks table includes a `Duration` column between `Title` and `Filename`.
- The Duration column is hidden by default.
- Column visibility is backed by AppStorage and toggled through the track-table context menu using `Show Duration` / `Hide Duration`.
- Table duration values render in `MM:SS` below one hour and `HH:MM:SS` when hours are present.
- `.swifttag` documents persist `Duration` and restore it on read.
- `.swifttag` persists known durations with full decimal precision and omits unknown durations.
- Existing `.swifttag` documents without a duration field still load successfully.
- Quick Look uses saved `Duration` and renders it as trailing `MM:SS`, `HH:MM:SS`, or empty text after the title with a spacer pushing the value to the right edge.
- Adding duration persistence does not change the existing tag-and-picture manifest fingerprint calculation, and `flacFingerprint` remains excluded from that calculation.
- Duration remains informational and does not create editable diffs or new unsaved-change behavior.

## Open Questions
None at this stage.
