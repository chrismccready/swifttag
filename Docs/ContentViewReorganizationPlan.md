# ContentView Reorganization Plan

## 1. Test-First Plan (Current Code Baseline)

### Goals
- Lock current behavior before moving code out of `ContentView.swift`.
- Add coverage for tag editing rules, FLAC import mapping, and album art workflows.
- Keep refactor risk low by proving no behavior regressions.

### Current Test Snapshot
- `SwiftTagTests` currently has only template test coverage.
- `SwiftTagUITests` already covers several misc-tag scenarios and launch behavior.
- FLAC fixture available at `SwiftTag/SwiftTagTestFiles/test.flac` for deterministic import assertions.

### Add Immediately (Before Refactor)
1. Expand `SwiftTagUITests` for current SwiftUI behavior:
- Select multiple tracks and verify shared field edits apply to all selected tracks.
- Verify `TOTALTRACKS/TRACKTOTAL` mismatch indicator behavior.
- Verify `TOTALDISCS` mismatch indicator behavior.
- Verify album art front cover tap opens album art sheet.
- Verify album art import/export UI affordances exist for selected slot.

2. Add unit tests in `SwiftTagTests` for logic that can be extracted without UI changes:
- Date parse and format matrix (`yyyy-MM-dd`, `yyyy/MM/dd`, `yyyy-MM`, `yyyy`).
- Positive integer text filtering behavior.
- Tag key normalization and explicit-key detection.
- Misc-tag duplicate/invalid-key rules.

3. Add FLAC import mapping tests:
- `TRACKNUMBER/TRACK` normalization.
- `DISCNUMBER/DISC` normalization.
- `DESCRIPTION/COMMENT` and `LOCATION/VENUE` fallback behavior.
- Album and album artist initialization from first imported record.

### FLAC Fixture Assertions (Use `test.flac`)
Use `SwiftTag/SwiftTagTestFiles/test.flac` as the baseline import file and verify the imported UI/model values below:

- Album-level fields:
- `album = "Test Album"`
- `albumArtist = "Test AlbumArtist"`
- `totalDiscs = "1"` (normalized from `"01"`)

- Track-level fields for imported track:
- `TITLE = "Test Title"`
- `ARTIST = "Test Artist"`
- `COMPOSER = "Test Composer"`
- `GENRE = "Test Genre"`
- `LOCATION = "Test Location"`
- `DATE = "2026-03-01"`
- `DESCRIPTION = "Test Description"`
- `NUMBER = "1"` (normalized from `TRACKNUMBER="01"`)
- `DISC = "1"` (normalized from `DISCNUMBER="01"`)
- `TOTALTRACKS = "01"` retained from source tags while mismatch logic compares normalized value.
- `TOTALDISCS = "1"` when read from the current fixture through the bridge (already normalized in source tags at import time).
- `ENCODED_BY = "Test Encoded_By"` appears in misc tags and is editable like other non-explicit keys.

Recommended concrete tests using this fixture:

1. Service-level read test (`FlacMetadataService.readTags`) validating raw key/value extraction.
2. Import-mapping unit test validating normalized and fallback-mapped fields.
3. UI automation test importing `test.flac` and asserting visible field values in the editor.
4. UI automation test asserting `ENCODED_BY` appears in Misc Tags table after import.

### SwiftUI Testing Strategy
- Keep XCUI tests as integration coverage for rendered SwiftUI screens.
- Move business rules into testable pure Swift types (`struct`/`actor`) and test with the `Testing` framework.
- Optional later step: add snapshot-style checks once UI stabilizes (not required for first refactor pass).

### Test Execution Gates
- Gate 1: Existing + new tests pass before moving files.
- Gate 2: Tests pass after each migration phase.
- Gate 3: Full project build + all tests pass when `ContentView` slimming is complete.

## 2. Target SwiftUI Project Organization

Use feature-first folders with small shared foundations:

- `SwiftTag/App`
- `SwiftTag/Features/TagEditor`
- `SwiftTag/Features/AlbumArt`
- `SwiftTag/Features/FlacImport`
- `SwiftTag/Shared/Models`
- `SwiftTag/Shared/Services`
- `SwiftTag/Shared/Utilities`
- `SwiftTag/Shared/UIComponents`

Recommended file split for current `ContentView.swift`:

- `Features/TagEditor/TagEditorView.swift` (new root screen replacing large body)
- `Features/TagEditor/TrackTableView.swift`
- `Features/TagEditor/MetadataFieldsView.swift`
- `Features/TagEditor/MiscTagsSectionView.swift`
- `Features/TagEditor/TOMLUtilityView.swift`
- `Features/AlbumArt/AlbumArtSheetView.swift`
- `Features/AlbumArt/AlbumArtWellView.swift`
- `Features/FlacImport/FlacImportCoordinator.swift`
- `Shared/Models/Track.swift`
- `Shared/Models/MiscTagRow.swift`
- `Shared/Models/TagKey.swift`
- `Shared/Utilities/DateTagFormatter.swift`
- `Shared/Utilities/TagNormalization.swift`

## 3. State and Logic Boundaries

- Keep view structs focused on rendering and bindings.
- Move mutable editor state to `TagEditorViewModel` (`@MainActor`, `Observable`).
- Move pure rules to utility/model helpers (no SwiftUI imports).
- Keep file I/O and bridge calls in service/coordinator types.

## 4. Suggested Migration Order

1. Extract pure helper types (date/tag normalization, misc-tag validation) + unit tests.
2. Extract models (`Track`, `MiscTagRow`, `TagKey`) + compile/test.
3. Extract album art feature views + tests.
4. Extract FLAC import coordinator + tests.
5. Extract misc-tag section view + tests.
6. Create `TagEditorViewModel`, move state/commands from `ContentView`, keep behavior unchanged.
7. Slim `ContentView` into composition shell.

## 5. Definition of Done

- `ContentView.swift` becomes a thin composition entry point.
- Business logic has unit tests in `SwiftTagTests`.
- Key SwiftUI user flows are covered in `SwiftTagUITests`.
- Build and tests pass with no behavior regressions in existing workflows.
