# FLAC Picture Import + Album Art Assignment Plan

## Goal
Implement FLAC picture import so SwiftTag:
- Reads all embedded FLAC pictures during import.
- Assigns the first picture with FLAC picture type `3` (Front Cover) to `TagEditorAlbumView`’s `AlbumArtWellView`.
- Stores imported pictures in a type-aware structure keyed by FLAC picture type.
- Refactors `albumArtTypes` to use a richer picture-type model instead of a plain `number` field.

## Scope
In scope:
- FLAC bridge + Swift metadata service updates for picture extraction.
- Album art type model refactor.
- Import pipeline wiring from FLAC read -> view models -> UI.
- Tests for mapping and first-front-cover assignment behavior.

Out of scope:
- Writing embedded pictures back into FLAC files.
- New UI for per-track picture browsing/editing (unless needed for internal data plumbing only).

## Actionable Checklist

### 1) Refactor album art type model
- [ ] Update `SwiftTag/SwiftTag/Features/AlbumArt/AlbumArtTypes.swift`:
  - Replace `AlbumArtType.number` with explicit FLAC picture metadata, e.g.:
    - `flacPictureType: Int`
    - `flacDescription: String` (or display description field)
  - Keep `navigationLinkName` and `slot` to preserve current UI navigation.
  - Add helper lookups (by slot and by FLAC picture type) to avoid repeated array scans.
- [ ] Update `SwiftTag/SwiftTag/ContentView.swift`:
  - Rebuild `albumArtTypes` values using the new field names.
  - Keep current slot order and labels unless intentionally changing UX.

### 2) Extend FLAC bridge to return picture blocks
- [ ] Update C bridge API in `SwiftTag/SwiftTag/FLACBridge/include/FlacMetadataBridge.h`:
  - Add `FlacPicture` and `FlacPictureResult` structs.
  - Add `flac_read_pictures(...)` and corresponding free function(s).
- [ ] Implement picture extraction in `SwiftTag/SwiftTag/FLACBridge/src/FlacMetadataBridge.c`:
  - Use libFLAC metadata iterator / block APIs to collect all `FLAC__METADATA_TYPE_PICTURE` blocks.
  - Capture at least:
    - Picture type (`type`)
    - MIME type
    - Description
    - Binary image bytes (+ size)
  - Ensure robust memory management and clear error paths matching existing bridge patterns.

### 3) Add Swift picture models + service mapping
- [ ] Update `SwiftTag/SwiftTag/FlacMetadataService.swift`:
  - Introduce Swift model(s), e.g. `FlacPictureRecord` and expanded `FlacMetadataRecord`.
  - Extend `readTags(for:)` behavior (or add `readMetadata(for:)`) to return tags + pictures together.
  - Convert C picture bytes to `Data` safely and free bridge allocations in all paths.

### 4) Map imported FLAC pictures into app-level structures
- [ ] Update `SwiftTag/SwiftTag/Features/FlacImport/FlacImportMapper.swift`:
  - Add mapping helper(s) that transform `FlacPictureRecord` into album-art domain objects keyed by FLAC picture type.
  - Keep tag mapping logic unchanged except where needed to pass through picture data.
- [ ] Decide and implement canonical conflict rule for multi-file import:
  - Recommended: first imported file wins per FLAC type unless that type is still empty.

### 5) Introduce typed album art storage in view models
- [ ] Update `SwiftTag/SwiftTag/Features/AlbumArt/AlbumArtViewModel.swift`:
  - Add an API to seed/update `albumArtImages` from imported FLAC pictures by matching `flacPictureType -> AlbumArtType.slot`.
  - Keep existing drag/drop + file import behavior as manual override.
- [ ] Update `SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift`:
  - During `importFlacFiles`, collect picture payloads from each file.
  - Return or expose imported picture map so `ContentView` can hand it to `AlbumArtViewModel`.
  - Preserve existing album/artist/track tag import behavior.

### 6) Wire first type-3 image to AlbumArtWellView front cover
- [ ] Update `SwiftTag/SwiftTag/ContentView.swift` orchestration:
  - After FLAC import completes, pass mapped pictures into `albumArtViewModel`.
  - Ensure the first encountered FLAC type `3` image sets slot `.frontCover`.
- [ ] Validate current `TagEditorAlbumView` usage path remains:
  - `frontCoverImage` (from `albumArtViewModel.imageForAlbumArtSlot(.frontCover)`) should now reflect imported type `3` automatically.

### 7) Preserve and document fallback behavior
- [ ] Define explicit fallback rules in code/docs:
  - If no type `3` exists, keep placeholder image.
  - If image data is invalid, skip that picture and continue.
  - Unknown FLAC picture types should be ignored unless mapped to `.other`.
- [ ] Add/update docs in `SwiftTag/Docs/README.md` if import behavior expectations are documented there.

### 8) Testing checklist
- [ ] Unit tests in `SwiftTag/SwiftTagTests/SwiftTagTests.swift` (or split files if preferred):
  - Picture-type mapping from FLAC type -> `AlbumArtSlot`.
  - “First type 3 wins” front-cover assignment behavior.
  - Multi-file merge rule per picture type.
  - Invalid/empty picture payload handling.
- [ ] Build verification:
  - Run `BuildProject` and resolve compile issues introduced by model refactor.
- [ ] Optional UI assertion in `SwiftTag/SwiftTagUITests/SwiftTagUITests.swift`:
  - Import FLAC fixture with embedded front cover and assert album art well is populated.

## Data Model Recommendation
Use explicit typed metadata for picture references.

Recommended shape (names can vary):
- `AlbumArtType`:
  - `flacPictureType: Int`
  - `flacDescription: String`
  - `navigationLinkName: String`
  - `slot: AlbumArtSlot`
- `FlacPictureRecord`:
  - `type: Int`
  - `mimeType: String`
  - `description: String`
  - `data: Data`

This keeps FLAC semantics clear and avoids overloading generic `number` naming.

## Acceptance Criteria
- Importing FLAC files reads all embedded pictures without crashing.
- First discovered FLAC picture type `3` appears in `TagEditorAlbumView`’s album art well.
- Imported pictures are stored in a structure keyed by FLAC picture type and mapped to album-art slots.
- Existing manual album-art import/export and drag/drop workflows still work.
- Project builds cleanly after refactor.
