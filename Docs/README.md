# SwiftTag

SwiftTag is a macOS SwiftUI app for editing FLAC metadata tags and embedded album art.
It supports importing `.flac` files (or folders of FLAC files), batch-editing selected tracks,
and exporting current metadata as TOML text.

## What the App Does

- Imports FLAC metadata through a C bridge (`FlacMetadataBridge`) wrapped by `FlacMetadataService`
- Displays tracks and lets you select one or more tracks for batch tag editing
- Edits core tags such as title, artist, composer, genre, date, track/disc numbers, and description
- Manages additional misc tags with validation rules for invalid or duplicate keys
- Shows mismatch indicators for track/disc totals
- Imports and exports album art for multiple picture slots (front cover, back cover, leaflet, etc.)
- Provides a TOML utility sheet for viewing generated tag output

## How to Use SwiftTag

1. Launch the app.
2. Load audio files:
- Use menu: `Load FLAC files...`
- Select one or more `.flac` files or a folder containing FLAC files
3. Edit metadata:
- Select track rows to edit one track or batch-edit multiple tracks
- Update album fields and core tags
- Add/edit/remove misc tags as needed
4. Manage album art:
- Click the front cover well or open the album art sheet
- Import by click, drag-and-drop, or context menu
- Export selected artwork from the context menu
5. View TOML:
- Use menu: `Show TOML...`

## Main App Areas

- `SwiftTag/ContentView.swift`: app composition, import flow, sheets, and focused commands
- `SwiftTag/Features/TagEditor/`: album, track list, core tags, and misc tags editor views
- `SwiftTag/Features/AlbumArt/`: album art sheet, slot definitions, and art view model
- `SwiftTag/Features/FlacImport/`: imported FLAC-to-model mapping logic
- `SwiftTag/Shared/Models/`: `Track`, `TagKey`, `MiscTagRow`
- `SwiftTag/Shared/Utilities/`: tag normalization and date formatting/parsing helpers
- `SwiftTag/FlacMetadataService.swift`: Swift wrapper for bridge metadata reads
- `SwiftTag/FLACBridge/`: C bridge implementation and headers

## Build and Test

Open `SwiftTag.xcodeproj` in Xcode, then:

- Build: Product > Build
- Run tests: Product > Test

Test targets:

- `SwiftTagTests`
- `SwiftTagUITests`
