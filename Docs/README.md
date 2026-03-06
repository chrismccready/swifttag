# SwiftTag

SwiftTag is a macOS SwiftUI app for working with FLAC metadata in a way that feels closer to a focused utility than a media library manager. It imports one or more `.flac` files, lets you edit album-level and track-level metadata across a selection, manages embedded album art, and writes the updated tags and pictures back to the source files.

The app is currently centered on direct FLAC metadata workflows:

- Import individual `.flac` files or entire folders containing FLAC files.
- Edit album fields such as album title, album artist, and total discs.
- Edit track metadata across one or many selected tracks.
- Manage misc tags with validation for invalid or duplicate keys.
- Inspect and update embedded album art across multiple FLAC picture types.
- Save tags only, pictures only, or both, using configurable write defaults.
- Generate a TOML view of the current metadata state.

## What SwiftTag Does Today

SwiftTag is designed around a single editor window with a few supporting sheets and settings panels.

- The main editor loads imported FLAC files into a track list and supports multi-selection for batch editing.
- Album-wide values and selected-track values are shown side by side in a single editing workflow.
- Core tag editing includes fields such as title, artist, composer, genre, date, track number, disc number, location, and description.
- Track and disc total mismatches are surfaced in the UI so inconsistent metadata is easier to spot before saving.
- Misc tags can be added, edited, and removed, with key normalization and duplicate/invalid-key handling.
- Album art can be imported from JPEG or PNG files, dropped directly into wells, previewed, and exported back out.
- The app supports a broader set of FLAC picture slots than just front cover, including back cover, leaflet, media, artist/composer-related images, logos, icons, illustration, performance/session imagery, and other FLAC picture categories.
- Saving is configurable through app settings, including:
  - default save payload: tags, pictures, or both
  - default save scope: selected tracks or all tracks
  - number formatting and total-count key strategies for tracks and discs

## Typical Usage

1. Launch the app.
2. Use `Load FLAC files...` from the app commands to import `.flac` files or a folder containing FLAC files.
3. Select one or more tracks in the track list.
4. Edit album metadata, selected-track core tags, and misc tags in the main window.
5. Click the front cover image or open the album art sheet to manage embedded pictures.
6. Use `Save`, `Save Tags...`, or `Save Pictures...` depending on the write operation you want.
7. Use `Show TOML...` if you want a generated TOML representation of the current metadata state.

## Main App Areas

- `SwiftTag/ContentView.swift`
  The main workflow entry point. Handles FLAC import, save actions, sheets, focused commands, and view model wiring.
- `SwiftTag/Features/TagEditor/`
  The primary editor UI for album fields, track list editing, core tags, and misc tags.
- `SwiftTag/Features/AlbumArt/`
  Album art sheet navigation, image wells, drag and drop, import/export flow, and album art slot definitions.
- `SwiftTag/Features/Settings/`
  Save behavior defaults and tag-writing preferences.
- `SwiftTag/Features/FlacImport/`
  Mapping from imported FLAC metadata into the app’s Swift models, plus write mapping for save operations.
- `SwiftTag/Shared/Models/`
  Shared app data types such as `Track`, `MiscTagRow`, tag keys, and save settings.
- `SwiftTag/Shared/Utilities/`
  Helpers for tag normalization and date formatting/parsing.
- `SwiftTag/FlacMetadataService.swift`
  Swift wrapper around the FLAC bridge for reading and writing tags and pictures.
- `SwiftTag/FLACBridge/`
  C bridge code used to read and write FLAC metadata through libFLAC.

## Build And Test

Open the project in Xcode and use the standard app workflow:

- Build: Product > Build
- Run app: Product > Run
- Run tests: Product > Test

Current test targets:

- `SwiftTagTests`
- `SwiftTagUITests`
There is also a `SwiftTagTestFiles/` directory with sample FLAC and image fixtures used for development and UI testing workflows.

## AI Context Important

This section is intentionally reserved for high-signal project context that should remain easy for both humans and AI tooling to find quickly.

- Plans live under `Docs/Plans/`.
- Guides live under `Docs/Guides/`.
- Plan files are currently numbered in execution/order form:
  - `1-FLACBridgeExecution.md`
  - `2-ContentViewReorganizationPlan.md`
  - `3-FlacPictureImportAlbumArtPlan.md`
  - `4-FlacWriteTagsAndPicturesPlan.md`
- If plan files are renamed, renumbered, or moved, this README should be updated in the same change.
- This README should describe current app behavior, not planned behavior.
- When adding future AI context here, prefer concise operational facts over long narrative descriptions.

