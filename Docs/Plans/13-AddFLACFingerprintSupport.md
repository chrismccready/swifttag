# Add FLAC Fingerprint Support Plan

## Goal
Add FLAC audio fingerprint support so SwiftTag can read the FLAC stream MD5 from libFLAC, surface it per track in the track table as `Fingerprint (ffp)`, and let users show or hide that column from the track table context menu.

## Scope
In scope:
- Add a FLAC bridge accessor for the FLAC audio MD5 value exposed by libFLAC and equivalent to `metaflac --show-md5sum`.
- Surface the fingerprint through the Swift metadata service and into the imported track model.
- Add a `Fingerprint (ffp)` column at the end of the track table.
- Add track-table context-menu controls to show or hide the fingerprint column.
- Add targeted tests for bridge/service mapping, track-model propagation, and table/context-menu behavior.

Out of scope:
- Changing how save-session fingerprints are computed in `TrackSetFingerprint`.
- Writing or modifying FLAC audio fingerprints.
- Adding fingerprint-based duplicate detection or search/filtering.
- Adding non-FLAC fingerprint support.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/12-AddFLACDocumentOpenSupport.md`.
- Current implementation files reviewed:
- `SwiftTag/FLACBridge/include/FlacMetadataBridge.h`
- `SwiftTag/FLACBridge/src/FlacMetadataBridge.c`
- `SwiftTag/FlacMetadataService.swift`
- `SwiftTag/Shared/Models/Track.swift`
- `SwiftTag/Shared/Models/TrackStatus.swift`
- `SwiftTag/Features/TagEditor/TagEditorTrackFileView.swift`
- `SwiftTag/Features/TagEditor/TagEditorView.swift`
- `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Relevant fixtures inspected:
- `SwiftTagTestFiles/test.flac`
- `SwiftTagTestFiles/test-with_padding.flac`
- Constraints accounted for:
- The current FLAC bridge reads Vorbis comments and picture blocks separately, so fingerprint support should extend that bridge rather than shelling out to `metaflac`.
- `FlacMetadataService.readTags(for:)` is the shared import/reload read path, so fingerprint support should flow through that path instead of inventing a second file-read path.
- `Track` and `TrackFileSnapshot` currently store tag and picture state only; there is no fingerprint field yet.
- `TagEditorTrackFileView` currently hardcodes four columns and has no built-in column-visibility state.
- Existing per-app UI preferences are stored with `@AppStorage` in `ContentView` and settings views; that is the most likely persistence seam if column visibility should be remembered.
- SwiftUI `Table` inspection support is limited, so source-order assertions and `actualView()` checks are likely to be more reliable than brittle structural traversal.

## Current Implementation Snapshot
- `flac_read_tags` and `flac_read_pictures` exist in the C bridge, but there is no accessor for the FLAC stream MD5 in `FlacMetadataBridge.h` or `FlacMetadataBridge.c`.
- `FlacMetadataRecord` currently returns only `tags` and `pictures`, so the Swift layer has no place to carry a fingerprint value today.
- `TagEditorViewModel.importFlacFiles(_:locked:append:)` builds `Track` values from `FlacMetadataService.readTags(for:)`, which makes import the primary insertion point for a track fingerprint.
- Track refresh and reload paths also call `FlacMetadataService.readTags(for:)`, so fingerprint refresh behavior can stay aligned with existing file reread flows.
- `TagEditorTrackFileView` currently declares status, track number, title, and filename columns only, and its context menu has no column-visibility items.
- `TagEditorView` currently passes no fingerprint-specific data or column-visibility state into `TagEditorTrackFileView`.

## Confirmed Decisions
- `Fingerprint (ffp)` should be visible by default the first time the app shows the track table.
- The fingerprint column show/hide choice should persist across launches and windows using `@AppStorage`.
- If SwiftTag cannot read a fingerprint for a row, the cell should display `NA`.

## Dependencies And Constraints
- The bridge implementation should read the stored FLAC stream info MD5 value from libFLAC metadata rather than compute a new checksum in Swift.
- The returned fingerprint should preserve parity with libFLAC/metaflac output so fixture tests can compare a stable known value.
- Fingerprint values need to survive import, reload, and external file refresh flows without creating a separate synchronization path.
- The table column must be appended at the end of the current track table, preserving the existing order of status, `#`, `Title`, and `Filename`.
- Context-menu show/hide support needs a source of truth for whether the fingerprint column is visible, and that scope must be explicit and testable.

## High-Risk Concerns
### Product / Behavioral Risks
- If the bridge reads the wrong metadata block or formats the MD5 differently than `metaflac --show-md5sum`, the UI could show misleading values that appear authoritative.
- If the fingerprint column visibility state has unclear scope, users may find it surprising if the column reappears or disappears between windows or launches.
- If refresh/reload paths do not update the fingerprint consistently, the table could show stale values after file replacement or external modification.

### Tooling / Environment / Sandbox Risks
- Bridge-level changes require careful C memory management and explicit free behavior if a new C string is allocated for the MD5 value.
- Fixture verification should prefer the checked-in FLAC samples rather than ad hoc files so targeted tests stay deterministic.
- SwiftUI `Table` and context-menu inspection can be brittle, so verification may need a mix of bridge/service tests, source-order assertions, and narrow view tests instead of broad UI traversal.

## Implementation Phases
1. Add FLAC Bridge MD5 Accessor
- Extend `FlacMetadataBridge.h` with a dedicated fingerprint read API and any result/freeing surface it needs.
- Update `FlacMetadataBridge.c` to read the FLAC stream info metadata block and extract the stored MD5 of the audio data.
- Normalize the bridge result into the expected hex string format and return a clear error when the FLAC metadata cannot be read.

2. Surface Fingerprint Through Swift Metadata Reads
- Extend `FlacMetadataRecord` to carry a fingerprint field.
- Update `FlacMetadataService.readTags(for:)` to call the new bridge accessor and include the fingerprint in the returned record.
- Ensure the bridge-owned memory for the fingerprint string is freed on both success and failure paths.

3. Add Fingerprint To Track And Snapshot Models
- Add a per-track fingerprint property to `Track`.
- Decide whether `TrackFileSnapshot` also needs the fingerprint for external-difference or reload bookkeeping, or whether a track-level field is sufficient.
- Populate the fingerprint during import, reload, and other file-reread flows that already reconstruct track state from `FlacMetadataService.readTags(for:)`.

4. Add Table Column And Visibility State
- Extend `TagEditorTrackFileView` to accept the fingerprint display value and visibility flag needed to render the column.
- Append a `TableColumn("Fingerprint (ffp)")` after `Filename`.
- Add context-menu controls to toggle the fingerprint column on and off.
- Store the visibility source of truth in the appropriate parent state container using `@AppStorage` so it persists across launches and windows.

5. Validation And Hardening
- Add targeted tests for fixture fingerprint reads from the FLAC bridge/service layer.
- Add model/view-model tests confirming imported and refreshed tracks receive the expected fingerprint.
- Add targeted view tests or source assertions that the fingerprint column remains last and that the context menu exposes the show/hide control.
- Prefer targeted `RunSomeTests` coverage over full-suite execution.

## Test Strategy
Order:
1. Bridge/service tests using checked-in fixtures:
- reading `test.flac` returns the expected MD5 value
- reading `test-with_padding.flac` returns the expected MD5 value for that file
- service-level failures propagate a useful bridge error if the FLAC metadata cannot be read
2. View-model/model tests:
- imported tracks receive the fingerprint from `FlacMetadataRecord`
- reload/external refresh paths update the track fingerprint when the file is reread
- any chosen snapshot/state container carries the fingerprint consistently if snapshot storage is added
3. Targeted SwiftUI/ViewInspector or source-order tests:
- the track table declares `Fingerprint (ffp)` after `Filename`
- the track table context menu exposes the show/hide fingerprint action
- the view respects the visibility flag and omits the column when hidden
4. XCUI only if a context-menu visibility interaction cannot be validated with a lighter seam.

## Acceptance Criteria
- SwiftTag can read a FLAC audio fingerprint from libFLAC without invoking external tools.
- The returned fingerprint matches the FLAC stream MD5 representation expected from `metaflac --show-md5sum`.
- Imported FLAC tracks display their fingerprint in a track-table column titled `Fingerprint (ffp)`.
- The fingerprint column is appended after the existing `Filename` column.
- The fingerprint column is visible by default on first launch.
- The track table context menu lets the user show or hide the fingerprint column.
- The fingerprint column visibility choice persists across launches and windows.
- Rows whose fingerprint cannot be read display `NA`.
- The fingerprint value stays aligned with import and file-reread flows instead of drifting out of sync.
- Targeted automated tests cover the bridge/service read path and the table visibility behavior.

## Open Questions
- None currently.
