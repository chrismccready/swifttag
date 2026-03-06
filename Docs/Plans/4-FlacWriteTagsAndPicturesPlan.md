# FLAC Write Tags and Pictures Plan

## Goal
Implement write-back support for imported FLAC files so SwiftTag can:
- Save tags, pictures, or both back to the source `.flac` files.
- Respect user-configurable save defaults stored with `@AppStorage`.
- Expose a macOS Settings window built with SwiftUI `Settings`.
- Add `Save`, `Save Tags...`, and `Save Pictures...` commands to the File menu.

## SwiftUI Settings Guidance
Use a dedicated `Settings` scene in `SwiftTagApp` and present a `TabView` with `General` and `Tags` tabs. This matches Apple’s current SwiftUI guidance for macOS settings scenes and pairs naturally with `@AppStorage`-backed controls.

## Scope
In scope:
- New settings UI and typed settings storage.
- Save command/menu architecture.
- FLAC bridge and Swift service write APIs for Vorbis comments and picture blocks.
- Track/model updates needed to know which imported files can be written.
- Tests for settings persistence, tag serialization, picture serialization, and command behavior.

Out of scope:
- Non-FLAC write support.
- A separate per-track save dialog unless required for sandbox/file-access recovery.
- New album-art editing UI beyond reusing the existing album-art state as the picture source.

## Critical Constraint
Imported file access is currently released immediately after import in `ContentView`. That is sufficient for reading, but not for later `Save` commands in a sandboxed macOS app. The implementation must either:
- Persist security-scoped bookmark data for each imported file and resolve access on demand during save, or
- Intentionally keep security-scoped access open for the lifetime of the imported session.

Recommended approach: store bookmark data per imported track and reacquire access only while saving.

## Implementation Plan

### 1. Add a typed save-settings model
- Create a small shared settings type, e.g. `Shared/Models/AppSettings.swift` or `Shared/Utilities/SaveSettings.swift`.
- Define enums for:
  - Save payload: `writeTags`, `writePictures`, `writeTagsAndPictures`
  - Save scope: `selectedTracks`, `allTracks`
  - Track count key strategy: `totalTracks`, `trackTotal`, `both`, `none`
  - Disc count key strategy: `totalDiscs`, `discTotal`, `both`, `none`
- Centralize `@AppStorage` keys and defaults:
  - Default save payload = `Write Tags and Pictures`
  - Default save scope = `Write to All Tracks`
  - Zero pad track number = `true`
  - Track count key strategy = `TOTALTRACKS and TRACKTOTAL`
  - Zero pad disc number = `true`
  - Disc count key strategy = `TOTALDISCS`
- Define save-scope semantics explicitly:
  - `selectedTracks` means the tracks currently selected in the `trackItems` table shown by `TagEditorTrackFileView`.
  - `allTracks` means all imported FLAC-backed tracks currently loaded in the editor.

### 2. Add the macOS Settings scene
- Update `SwiftTag/SwiftTag/SwiftTagApp.swift`:
  - Keep the existing `WindowGroup`.
  - Add a macOS `Settings` scene.
- Create a dedicated settings root view, e.g. `SwiftTag/SwiftTag/Features/Settings/SettingsView.swift`.
- Structure the settings UI as:
  - `TabView`
  - `General` tab
  - `Tags` tab
- `General` tab requirements:
  - A `GroupBox` labeled `Default on Save (⌘S) behavior`
  - Picker 1: `Write Tags`, `Write Pictures`, `Write Tags and Pictures`
  - Picker 2: `Write to Selected Tracks`, `Write to All Tracks`
- `Tags` tab requirements:
  - `Toggle`: `Zero Pad Track Number`
    - Applies to both `TRACKNUMBER` and track-total keys such as `TOTALTRACKS` / `TRACKTOTAL`.
  - `TODO`: add a `Prefer In-Place FLAC Writes (use padding when possible)` checkbox that maps to libFLAC write-padding policy so users can choose whether rewritten files should retain/add padding to reduce future full rewrites.
  - `Picker`: `Write track count key as`
    - `TOTALTRACKS`
    - `TRACKTOTAL`
    - `TOTALTRACKS and TRACKTOTAL`
    - `don't write key`
  - `Toggle`: `Zero Pad Disc Number`
    - Applies to both `DISCNUMBER` and disc-total keys such as `TOTALDISCS` / `DISCTOTAL`.
  - `Picker`: `Write disc count key as`
    - `TOTALDISCS`
    - `DISCTOTAL`
    - `TOTALDISCS and DISCTOTAL`
    - `don't write key`
- Bind all controls directly to `@AppStorage` so changes persist immediately.

### 3. Track imported file identity and access
- Update `SwiftTag/SwiftTag/Shared/Models/Track.swift` to retain source-file metadata required for save:
  - `sourceFileURL` or resolved file path
  - `securityScopedBookmarkData` or equivalent access token
  - Optional imported-file flag if needed to disable save for placeholder demo tracks
- Update `TagEditorViewModel.importFlacFiles` and `ContentView.handleFlacImportResult` so imported tracks carry durable write access information.
- Add a clear policy for non-imported placeholder tracks:
  - Recommended: disable save commands when there are no imported FLAC tracks.

### 4. Introduce a write-facing FLAC serialization layer
- Add a mapper that converts editor state back into FLAC-ready payloads, likely in:
  - `SwiftTag/SwiftTag/Features/FlacImport/FlacWriteMapper.swift`
- Responsibilities:
  - Convert app-level explicit fields back to FLAC keys.
  - Merge explicit fields and misc tags into a final `[String: String]`.
  - Apply zero-padding rules to `TRACKNUMBER` plus track-total keys and to `DISCNUMBER` plus disc-total keys.
  - Apply track/disc count key strategy from settings.
  - Ensure write output does not contain conflicting duplicate count keys that violate the selected strategy.
- Recommended explicit output rules:
  - Rename app-level explicit keys to align with canonical FLAC output:
    - `TagKey.number` -> `TagKey.trackNumber` for `TRACKNUMBER`
    - `TagKey.disc` -> `TagKey.discNumber` for `DISCNUMBER`
  - Track number: write only `TRACKNUMBER`.
  - Disc number: write only `DISCNUMBER`.
  - Album-level fields (`ALBUM`, `ALBUMARTIST`, total disc count) should be written consistently to every saved track file.
  - Misc tags should exclude internal-only keys like `FILENAME`.
  - Only write keys whose values are not empty after trimming.
  - When writing tags, remove all existing Vorbis comment entries from the destination file first, then write only the newly generated non-empty keys.

### 5. Define picture write source-of-truth
- Decide the picture payload source for saving pictures:
  - Album-level picture state from `AlbumArtViewModel.albumArtImages`
  - Existing per-track imported picture state in `Track.flacPicturesByType`
- Recommended approach:
  - Treat `AlbumArtViewModel` as the authoritative edited album-art state for app-level picture slots.
  - When saving pictures, build picture blocks from current album-art slots and write the same selected set of pictures to each destination track.
- Add a write payload model that preserves:
  - FLAC picture type
  - MIME type
  - Description
  - Binary data
- If only `Image` is currently retained for edited album art, extend the stored asset model so the write path can access original/exportable binary data and MIME type without recompressing unexpectedly unless recompression is acceptable by design.
- When writing pictures, remove all existing FLAC picture blocks from the destination file first, then write only the newly generated picture blocks.
- Add an implementation `TODO` for future multi-picture support per FLAC picture type.
- Add a guard for FLAC picture type `1`:
  - Allow at most one type-1 picture per file.
  - Enforce PNG-only data for type `1`.

### 6. Extend the FLAC bridge for write support
- Update `SwiftTag/SwiftTag/FLACBridge/include/FlacMetadataBridge.h` with write-oriented structs and APIs, for example:
  - `FlacWriteTagPair`
  - `FlacWritePicture`
  - `flac_write_metadata(...)`
  - or separate `flac_write_tags(...)` and `flac_write_pictures(...)`
- Implement write support in `SwiftTag/SwiftTag/FLACBridge/src/FlacMetadataBridge.c` using libFLAC metadata chain APIs:
  - Read the chain.
  - Find or create the Vorbis comment block.
  - If tag writing is requested, clear existing Vorbis comments and rebuild the block from the new non-empty key/value pairs.
  - Remove/replace count keys according to selected strategy.
  - If picture writing is requested, remove all existing picture blocks before inserting new ones.
  - Append fresh picture blocks from the current payload.
  - Use the callbacks-based chain APIs for writeback:
    - Read with `FLAC__metadata_chain_read_with_callbacks(...)`.
    - Call `FLAC__metadata_chain_check_if_tempfile_needed(...)` before writing.
    - If no tempfile is needed, write with `FLAC__metadata_chain_write_with_callbacks(...)` so padded FLAC files can be updated in place.
    - If a tempfile is needed, write with `FLAC__metadata_chain_write_with_callbacks_and_tempfile(...)` using an app-owned temporary file location instead of relying on libFLAC’s implicit temp-file behavior near the source FLAC.
    - Complete the rewrite by atomically replacing the original file from Swift only after the temp-file write succeeds.
- Error handling requirements:
  - Surface chain-read, allocation, validation, and write failures back to Swift.
  - Free all allocated strings/data in all success and failure paths.

### 7. Add Swift write services
- Extend `SwiftTag/SwiftTag/FlacMetadataService.swift` with write APIs, for example:
  - `writeTags(_:to:)`
  - `writePictures(_:to:)`
  - `writeMetadata(tags:pictures:to:)`
- Keep bridge marshaling in the service layer:
  - Convert Swift dictionaries and `Data` into C structs.
  - Call the bridge.
  - Free temporary allocations after each call.
  - Pass an app-owned temporary rewrite destination into the bridge/service so callback-based libFLAC writes can preserve in-place edits when possible and only fall back to a controlled temp-file rewrite when `FLAC__metadata_chain_check_if_tempfile_needed(...)` reports that a full rewrite is required.
- Keep read and write concerns in the same service only if the file remains coherent; otherwise split into `FlacMetadataReader` and `FlacMetadataWriter`.

### 8. Add save orchestration to the editor/view model
- Add save commands to `TagEditorViewModel`, e.g.:
  - `save(using defaultSettings)`
  - `saveTags(for scope:)`
  - `savePictures(for scope:)`
- Responsibilities:
  - Resolve track targets based on `TagEditorTrackFileView` table selection (`selectedTrackIDs`) or all imported tracks.
  - Reacquire security-scoped access for each target file.
  - Build the final tag payload per track.
  - Build the picture payload from current album-art state.
  - Call the FLAC write service.
  - Collect and surface partial failures cleanly.
- Save semantics:
  - `Save` uses the stored payload default and the stored scope default.
  - `Save Tags...` uses the stored scope default and writes tags only.
  - `Save Pictures...` uses the stored scope default and writes pictures only.
  - If only tags are being written, picture blocks remain unchanged.
  - If only pictures are being written, Vorbis comments remain unchanged.
- Add command enablement state:
  - Disabled when there are no imported FLAC tracks.
  - `Save Tags...` and `Save Pictures...` disabled when their target scope resolves to zero tracks.
  - When the saved scope is `selectedTracks`, all save commands are disabled if `selectedTrackIDs` is empty.

### 9. Add File menu commands
- Update `SwiftTag/SwiftTag/SwiftTagApp.swift` command definitions:
  - Keep the current FLAC import and TOML commands.
  - Add `Save` with keyboard shortcut `⌘S`.
  - Add `Save Tags...`
  - Add `Save Pictures...`
- Use focused scene values or another scene-safe command routing mechanism so commands invoke the active editor window’s view model.
- `Save` behavior:
  - Use the two default settings from the `General` tab:
    - payload kind
    - selected-vs-all track scope
- `Save Tags...` and `Save Pictures...` behavior:
  - Override only the payload kind.
  - Respect the same saved selected-vs-all scope default as `Save`.

### 10. Add user feedback and failure handling
- Add save result UI to `ContentView` or a dedicated coordinator:
  - Success confirmation can stay lightweight.
  - Failures should identify which files failed and why.
- Recommended behavior:
  - If one file fails, continue attempting the remaining files and summarize failures afterward.
  - If security-scoped bookmark resolution fails, report that the file must be re-imported.

### 11. Tests
- Unit tests in `SwiftTag/SwiftTagTests/SwiftTagTests.swift` or split into focused files:
  - Settings default values
  - Settings enum raw-value persistence
  - Tag serialization for zero-padded and non-padded track/disc numbers and their corresponding total-count keys
  - Count-key strategy matrix for tracks and discs
  - Exclusion of internal-only keys like `FILENAME`
  - Save-scope resolution for selected vs all tracks
  - Save-scope resolution uses the current `TagEditorTrackFileView` track-table selection
- Bridge/service tests:
  - Write tags to a copied FLAC fixture, then re-read and verify values
  - Use `SwiftTagTestFiles/test-with_padding.flac` (or a copy of it) to verify the `FLAC__metadata_chain_check_if_tempfile_needed(...) == false` branch, confirming the callback-based write path performs an in-place metadata update when padding is sufficient
  - Write pictures to a copied FLAC fixture, then re-read and verify picture types/data exist
  - Write tags and pictures together, then re-read and verify both
  - Use `SwiftTagTestFiles/test.flac` (or a copy of it) to verify the `FLAC__metadata_chain_check_if_tempfile_needed(...) == true` branch, confirming the callback-based tempfile write path succeeds and the original file is atomically replaced with the rewritten output
  - Verify tag-only saves leave picture blocks unchanged
  - Verify picture-only saves leave Vorbis comments unchanged
  - Verify empty-string tag values are omitted from the rewritten Vorbis comments
  - Verify type-1 picture writes reject non-PNG data and reject multiple type-1 payloads
- UI tests in `SwiftTag/SwiftTagUITests/SwiftTagUITests.swift`:
  - Settings window exposes both tabs and expected controls
  - Changing settings persists across relaunch
  - `Save` respects default save behavior
  - `Save Tags...` does not overwrite pictures
  - `Save Pictures...` does not change tag fields

## Suggested File Additions / Updates
- Update `SwiftTag/SwiftTag/SwiftTagApp.swift`
- Update `SwiftTag/SwiftTag/ContentView.swift`
- Update `SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
- Update `SwiftTag/SwiftTag/Features/AlbumArt/AlbumArtViewModel.swift`
- Update `SwiftTag/SwiftTag/Shared/Models/Track.swift`
- Update `SwiftTag/SwiftTag/FlacMetadataService.swift`
- Update `SwiftTag/SwiftTag/FLACBridge/include/FlacMetadataBridge.h`
- Update `SwiftTag/SwiftTag/FLACBridge/src/FlacMetadataBridge.c`
- Add `SwiftTag/SwiftTag/Features/Settings/SettingsView.swift`
- Add `SwiftTag/SwiftTag/Features/Settings/GeneralSettingsView.swift`
- Add `SwiftTag/SwiftTag/Features/Settings/TagWriteSettingsView.swift`
- Add `SwiftTag/SwiftTag/Features/FlacImport/FlacWriteMapper.swift`
- Add tests as needed under `SwiftTag/SwiftTagTests` and `SwiftTag/SwiftTagUITests`

## Open Questions Needing Confirmation
No open questions at this time. Implementation should proceed with the confirmed decisions below:
- `Save Tags...` and `Save Pictures...` use the saved scope default.
- Export writes only canonical FLAC keys such as `TRACKNUMBER` and `DISCNUMBER`.
- Tag writes replace all existing tag data, but only when tag writing is requested.
- Picture writes replace all existing picture blocks, but only when picture writing is requested.
- Placeholder sample tracks should be removed from the app flow.

## Acceptance Criteria
- A macOS Settings window exists with `General` and `Tags` tabs and the exact controls/defaults described above.
- Settings persist across app relaunch via `@AppStorage`.
- `Save` (`⌘S`) writes tags, pictures, or both according to the saved default behavior.
- `Save Tags...` writes tags only.
- `Save Pictures...` writes pictures only.
- Save target scope respects the chosen behavior for selected vs all imported tracks, where `Selected Tracks` means the current selection in the `TagEditorTrackFileView` tracks table.
- Placeholder sample tracks are removed; save commands operate only on imported FLAC tracks.
- Tag writes clear existing Vorbis comments and rewrite only non-empty keys.
- Picture writes clear existing FLAC picture blocks and rewrite only the selected picture payload.
- Type `1` picture writes are limited to a single PNG image per file.
- Written FLAC files can be re-read by the existing import/service path and reflect the saved metadata.
- Save failures are surfaced without crashing and do not stop remaining target files from being attempted.
