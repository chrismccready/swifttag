# Add Track File Rename Plan

## Goal

Add editor-window scoped track file rename commands and configuration UI that
derive new FLAC file names from track tags, preview the first selected track's
new name or first loaded track's new name, sanitize configured output, and
rename selected or all loaded track files on disk.

## Scope

### In Scope

- Add `File` menu items immediately before `Reload Selected Tracks`:
  - `Rename Track Files`
  - `Rename Selected Track Files`
  - `Rename Track Files Config...`
  - divider
- Route all rename menu items to the key editor window using focused values.
- Add a rename configuration sheet presented from the key editor window.
- Add rename configuration state:
  - default `Rename Format`: `|TRACKNUMBER| |TITLE|`
  - default `Invalid Replacement`: `-`
  - default `Space Replacement`: `none`
  - default `Strict`: `false`
- Persist rename format, invalid replacement selection, space replacement
  selection, and strict selection with `@AppStorage`.
- Generate a live `Rename Example` from the first selected track or first
  loaded track when nothing is selected.
- Parse `|TAGKEY|` placeholders and literal text in rename format.
- Validate and normalize completed tag placeholders against known track tags.
- Support fuzzy tag matching such as `|track number|` and `|number|`
  resolving to `|TRACKNUMBER|`.
- Support zero-padded numeric placeholders:
  - `|zpTRACKNUMBER|`
  - `|zpDISCNUMBER|`
  - `|zpTOTALTRACKS|`
  - `|zpTOTALDISCS|`
  - `|zpTRACKTOTAL|`
  - `|zpDISCTOTAL|`
- Treat `TOTALTRACKS` and `TRACKTOTAL` as synonymous track-total tags.
- Treat `TOTALDISCS` and `DISCTOTAL` as synonymous disc-total tags.
- Replace invalid filename characters using an `Invalid Replacement` picker with:
  - `-`
  - `_`
  - `.`
  - `space`
- Replace whitespace after invalid-character formatting using a
  `Space Replacement` picker with:
  - `-`
  - `_`
  - `.`
  - `none`
- Apply selected invalid filename character replacement:
  - non-strict: `/`, `:`, and NUL
  - strict: `/`, `:`, NUL, `<`, `>`, `"`, `\`, `|`, `?`, `*`, and ASCII
    control characters
- Apply selected space replacement after invalid filename character replacement.
- Preserve original `.flac` extension after filename-stem generation.
- Rename all loaded track files from:
  - `Rename Track Files`
  - sheet `Rename All Track Files`
- Rename selected loaded track files from:
  - `Rename Selected Track Files`
  - sheet `Rename Selected Track Files`
- Update editor track file references after successful renames.
- Update `.swifttag` document export data so renamed source file paths and
  refreshed bookmarks are saved.
- Add focused unit, file-operation, ViewInspector/source-order, and build
  verification coverage.
- Update user documentation for menu commands and rename format syntax.

### Out Of Scope

- Writing FLAC metadata during rename.
- Moving files to a different folder.
- Renaming non-FLAC imported files.
- Adding AppleScript rename commands.
- Adding batch preview table UI beyond the requested single `Rename Example`.
- Adding undo for file renames unless confirmed.
- Changing existing save, reload, remove, sort, numbering, or total commands.

## Plan Input Checklist Coverage

- Latest numbered plan reviewed:
  - `Docs/Plans/32-AutoUpdateDiscTotal.md`
- Closest related plan reviewed:
  - `Docs/Plans/31-SetTrackNumbersAndSortTracks.md`
  - `Docs/Plans/26-AddAppleScriptSupport.md`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
  - `Docs/AppleDocsIndex/apple-docs-scout-agent.md`
- Apple Docs Scout used:
  - Built-in explorer agent reviewed current SwiftUI, Foundation, Picker, and
    FileManager documentation.
- Relevant app files reviewed:
  - `SwiftTag/SwiftTagApp.swift`
  - `SwiftTag/ContentView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorTrackFileView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/Shared/Models/Track.swift`
  - `SwiftTag/Shared/Models/TagKey.swift`
  - `SwiftTag/Shared/Utilities/SandboxPathBookmarkAccess.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagAppleScriptSupport.swift`
  - `SwiftTag/SwiftTag.sdef`
- Relevant tests to inspect/update during implementation:
  - `SwiftTagTests/SwiftTagTests.swift`
  - `SwiftTagTests/TrackStatusViewInspectorTests.swift`
  - `SwiftTagUITests/SwiftTagUITests.swift`
- Fixture applicability:
  - Rename does not parse or write FLAC metadata.
  - File-operation tests should still copy `SwiftTagTestFiles/test.flac` into a
    temporary directory before mutating it.

## Apple Documentation Findings

### SwiftUI Sheet Presentation

- Symbol/topic:
  - `View.sheet(isPresented:onDismiss:content:)`
  - `View.sheet(item:onDismiss:content:)`
- Framework: SwiftUI
- Source:
  - `/documentation/SwiftUI/View-Presentation`
  - `/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)`
- Finding:
  - Use editor-owned state and attach `.sheet` to `ContentView` or another view
    inside the key editor window. SwiftUI presentation modifiers are
    state-driven, so menu commands should mutate editor-scoped state rather than
    imperatively creating an AppKit sheet.

### Focused Command Routing

- Symbol/topic:
  - `FocusedValue`
  - `FocusedBinding`
- Framework: SwiftUI
- Source:
  - `/documentation/SwiftUI/FocusedValue`
  - `/documentation/SwiftUI/FocusedBinding`
- Finding:
  - Existing focused values are the right pattern for key-window menu routing.
    Add rename command closures, titles, and enablement beside existing
    `performReloadSelectedTracks` focused values.

### Text Entry Updates

- Symbol/topic:
  - `TextField(text:)`
  - `View.onChange(of:initial:_:)`
  - `Binding.init(get:set:)`
- Framework: SwiftUI
- Source:
  - `/documentation/SwiftUI/TextField`
  - `/documentation/swiftui/view/onchange(of:initial:_:)`
  - `/documentation/SwiftUI/Binding/init(get:set:)`
- Finding:
  - `TextField(text:)` updates bound `String` values continuously as the user
    types. Use a string binding for `Rename Format`. Use computed preview state
    for display. Use a custom `Binding` setter or guarded `onChange` for
    immediate tag-token normalization.

### Picker And App Storage

- Symbol/topic:
  - `Picker`
  - `Toggle`
  - `AppStorage`
- Framework: SwiftUI
- Source:
  - `/documentation/SwiftUI/Picker`
  - `/documentation/SwiftUI/Toggle`
  - `/documentation/SwiftUI/AppStorage`
- Finding:
  - Use SwiftUI pickers for limited invalid and space replacement values and a
    toggle for strict mode. Store rename format, invalid replacement selection,
    space replacement selection, and strict selection in `@AppStorage` so
    direct menu commands use the last saved configuration across launches.

### File Rename

- Symbol/topic:
  - `FileManager.moveItem(at:to:)`
- Framework: Foundation
- Source:
  - `/documentation/Foundation/FileManager/moveItem(at:to:)`
- Finding:
  - Implement rename as same-directory file move to a destination URL containing
    the new last path component. Validate collisions first because
    `moveItem(at:to:)` fails when the destination exists.

## Current Implementation Snapshot

- `SwiftTagApp.AppCommands` owns `File` menu construction.
- Existing `File` menu order near the requested insertion point is:
  - `Set Disc Total (...)`
  - divider
  - `Reload Selected Tracks`
  - `Remove Selected Tracks`
- `ContentView` publishes editor-scoped menu actions with `.focusedSceneValue`.
- `ContentView` already presents an editor-attached sheet for album art with
  `.sheet(isPresented:)`.
- `ContentView` owns save/import/reload/remove alerts and destructive action
  confirmation state.
- `TagEditorViewModel` owns track selection, track file references, security
  scoped bookmark resolution, reload, save, and file-monitor refresh helpers.
- `Track.displayFileName` uses `sourceFileURL.lastPathComponent` when present.
- Imported tracks store:
  - `sourceFileURL`
  - `securityScopedBookmarkData`
  - `latestFileSnapshot`
  - `tags[TagKey.filename]`
- `.swifttag` export writes `sourceFileURL` and `securityScopedBookmarkData`.
- `SwiftTag.sdef` and `SwiftTagScriptTrack.scriptPropertyTagKeys` contain the
  broadest current track-property-to-tag mapping.

## Confirmed Decisions

- Menu item labels are exactly:
  - `Rename Track Files`
  - `Rename Selected Track Files`
  - `Rename Track Files Config...`
- Rename menu items appear before `Reload Selected Tracks`.
- Rename menu items are followed by a divider before `Reload Selected Tracks`.
- Configuration sheet opens on the key editor window.
- Sheet controls are:
  - read-only `Rename Example`
  - `Rename Format` text field
  - `Invalid Replacement` picker menu containing `-`, `_`, `.`, and `space`
  - `Strict` checkbox
  - `Space Replacement` picker menu containing `-`, `_`, `.`, and `none`
  - `Cancel`
  - `Rename Selected Track Files`
  - `Rename All Track Files`
- Default rename format is `|TRACKNUMBER| |TITLE|`.
- Default invalid replacement selection is `-`.
- Default space replacement selection is `none`.
- Default strict value is `false`.
- Rename format string, invalid replacement selection, space replacement
  selection, and strict selection are saved with `@AppStorage`.
- There is no `Zero Pad` checkbox.
- Zero padding is requested with dedicated tags:
  - `|zpTRACKNUMBER|`
  - `|zpDISCNUMBER|`
  - `|zpTOTALTRACKS|`
  - `|zpTOTALDISCS|`
  - `|zpTRACKTOTAL|`
  - `|zpDISCTOTAL|`
- `TOTALTRACKS` is synonymous with `TRACKTOTAL`.
  - User-entered `|total tracks|` resolves to `|TOTALTRACKS|`.
  - User-entered `|track total|` resolves to `|TRACKTOTAL|`.
  - Plausible track-total aliases such as `|track count|` default to
    `|TOTALTRACKS|`.
- `TOTALDISCS` is synonymous with `DISCTOTAL`.
  - User-entered `|total discs|` resolves to `|TOTALDISCS|`.
  - User-entered `|disc total|` resolves to `|DISCTOTAL|`.
  - Plausible disc-total aliases such as `|disc count|` default to
    `|TOTALDISCS|`.
- `Rename Track Files` uses the same behavior as sheet
  `Rename All Track Files`.
- `Rename Selected Track Files` uses the same behavior as sheet
  `Rename Selected Track Files`.
- Direct menu rename commands use the current saved rename configuration.
- Format output is always treated as a filename stem. The original `.flac`
  extension is always preserved.
- Dedicated `zp...` tags use the same padding behavior as existing
  padding-on-save functionality.
- Batch rename conflicts abort the whole batch and show a dialog explaining the
  issue.
- Locked tracks are excluded from rename because lock means read-only.
- Tracks added via `Add FLAC files (read-only)...` are not renameable because
  they are locked.
- Deleted-in-table or missing-file tracks are skipped with a warning.
- `Rename Example` uses the first selected track, or the first loaded track when
  nothing is selected.
- When there is no selection, the `Rename Selected Track Files` menu item and
  sheet button are disabled.
- Renaming marks the referenced `.swifttag` document state as modified
  immediately so closing prompts to save updated file references.
- Direct menu rename commands do not prompt before renaming. They execute
  immediately when configuration and batch plan are valid, or show a dialog for
  invalid configuration or batch rename error conditions.

## Product Behavior

### Menu Commands

1. User opens `File` menu with an editor window focused.
2. Before `Reload Selected Tracks`, user sees:
   - `Rename Track Files`
   - `Rename Selected Track Files`
   - `Rename Track Files Config...`
   - divider
3. `Rename Track Files` renames all renameable loaded track files in the key
   editor window.
4. `Rename Selected Track Files` renames renameable selected track files in the
   key editor window.
5. `Rename Track Files Config...` opens the sheet on the key editor window.
6. Commands are disabled while a save or rename operation is running.
7. `Rename Selected Track Files` is disabled when no tracks are selected.
8. Direct rename commands execute immediately when configuration and batch plan
   are valid.
9. Direct rename commands show a dialog for invalid configuration or batch
   rename error conditions.

### Rename Config Sheet

1. Sheet initializes from persisted rename configuration.
2. `Rename Example` shows proposed output for the first selected track, or the
   first loaded track when nothing is selected.
3. If no selected track is available, sheet uses the first loaded track for
   preview.
4. Editing `Rename Format`, `Invalid Replacement`, `Strict`, or
   `Space Replacement` refreshes `Rename Example`.
5. Completing a placeholder by typing trailing `|` attempts to normalize it to
   a known tag key.
6. `Rename Selected Track Files` is disabled when no tracks are selected.
7. Buttons at bottom right:
   - `Cancel` closes without renaming.
   - `Rename Selected Track Files` saves configuration and renames selected
     track files.
   - `Rename All Track Files` saves configuration and renames all loaded track
     files.

### Rename Format

1. Text outside `|...|` is literal.
2. Text inside `|...|` is a tag placeholder.
3. Placeholder keys are normalized by trimming whitespace, removing separator
   noise for matching, and resolving aliases.
4. Exact normalized tags are preferred over fuzzy matches.
5. Known aliases include:
   - `TRACK`, `TRACK NUMBER`, `NUMBER` -> `TRACKNUMBER`
   - `TITLE`, `NAME` -> `TITLE`
   - `DISC`, `DISC NUMBER` -> `DISCNUMBER`
   - `TOTAL TRACKS`, `TRACK COUNT` -> `TOTALTRACKS`
   - `TRACK TOTAL` -> `TRACKTOTAL`
   - `TOTAL DISCS`, `DISC COUNT` -> `TOTALDISCS`
   - `DISC TOTAL` -> `DISCTOTAL`
6. `TOTALTRACKS` and `TRACKTOTAL` read the same track-total value.
7. `TOTALDISCS` and `DISCTOTAL` read the same disc-total value.
8. Plausible track-total aliases default to `TOTALTRACKS`.
9. Plausible disc-total aliases default to `TOTALDISCS`.
10. Dedicated zero-padded tags read the underlying numeric value and pad before
    substitution using existing padding-on-save behavior:
    - `zpTRACKNUMBER`
    - `zpDISCNUMBER`
    - `zpTOTALTRACKS`
    - `zpTOTALDISCS`
    - `zpTRACKTOTAL`
    - `zpDISCTOTAL`
11. Broader known tag keys come from shared tag catalog data based on:
   - `TagKey`
   - `SwiftTag.sdef` track properties
   - `SwiftTagScriptTrack.scriptPropertyTagKeys`
12. Unknown placeholders produce validation errors and disable rename actions.
13. Missing tag values render as empty strings for preview and rename.
14. Output whitespace is trimmed at the filename-stem boundary.

### Replacement Controls

1. `Invalid Replacement` is a picker menu.
2. Menu values are:
   - `-`
   - `_`
   - `.`
   - `space`
3. Selected invalid replacement text is used in place of invalid filename
   characters.
4. When `Strict` is unchecked, invalid filename characters are:
   - `/`
   - `:`
   - NUL
5. When `Strict` is checked, invalid filename characters are:
   - `/`
   - `:`
   - NUL
   - `<`
   - `>`
   - `"`
   - `\`
   - `|`
   - `?`
   - `*`
   - ASCII control characters, codes 0-31
6. `Space Replacement` is a picker menu.
7. Menu values are:
   - `-`
   - `_`
   - `.`
   - `none`
8. Default `Space Replacement` value is `none`.
9. When `Space Replacement` is not `none`, selected text replaces all
   whitespace in the filename after invalid-character replacement.
10. Space replacement runs after invalid-character replacement so whitespace
    produced by invalid-character replacement is included.
11. Rename format string, invalid replacement selection, space replacement
    selection, and strict selection are saved with `@AppStorage`.

### File Rename Execution

1. Build rename plan for requested scope before moving any files.
2. Scope `all` means all loaded tracks that are renameable.
3. Renameable tracks exclude locked tracks.
4. Tracks added via `Add FLAC files (read-only)...` are not renameable because
   they are locked.
5. Scope `selected` means the track-table selection in the key editor window.
6. Deleted-in-table or missing-file tracks are skipped with a warning.
7. Resolve each track file through existing security-scoped bookmark behavior.
8. Destination parent directory is the current source file parent directory.
9. Destination last path component is generated from:
   - format output
   - selected invalid replacement sanitization
   - selected space replacement sanitization
   - original `.flac` extension preservation
10. Validate before executing:
   - source is a regular file
   - source file extension is `.flac`
   - destination name is non-empty
   - destination stays in same parent directory
   - destination does not already exist unless it is the same path
   - no two planned renames target the same destination path
   - parent directory is writable or accessible through security-scoped access
11. If validation finds a conflict, no files are moved and a dialog explains the
    issue.
12. If validation fails for invalid configuration or another batch-level error,
    no files are moved and a dialog explains the issue.
13. If moving fails after validation, show error and refresh track file state.
14. After each successful move:
    - update `track.sourceFileURL`
    - refresh `track.securityScopedBookmarkData`
    - update `track.tags[TagKey.filename]`
    - refresh track monitoring
    - register editor session changes
    - mark the referenced `.swifttag` document state as modified

## Destructive / Write-Back Behavior

### Existing Data Preserved

- FLAC audio data.
- FLAC metadata blocks.
- FLAC pictures.
- Editor tag values.
- Album art state.
- Track lock values.
- Track order and selection where possible.
- Existing `.swifttag` document package contents until user saves it.

### Existing Data Replaced

- On-disk file path for each renamed track.
- Editor `sourceFileURL` for each renamed track.
- Editor security-scoped bookmark data for each renamed track.
- Editor `FILENAME` tag mirror for each renamed track.
- `.swifttag` document track references on next document save.

### Existing Data Removed

- Old file path disappears because same-directory rename is a move.
- No FLAC tag or picture data is removed.
- No `.swifttag` file is removed.

### Partial Save Behavior

- Rename is independent of tag-only, picture-only, and tags-and-pictures save
  payloads.
- After rename, later FLAC saves target the new file path.
- After rename, later `.swifttag` saves write the new file path/bookmark.

### Selected Items Source Of Truth

- Selected items means `TagEditorViewModel.selectedTrackIDs`, the same table
  selection used by reload/remove/lock commands.

## Dependencies And Constraints

### Product Constraints

- Filename generation must not silently create path separators.
- Batch rename must abort the whole batch when conflicts are known up front.
- Fuzzy tag matching must be predictable and test-covered.
- Direct menu commands require persisted `@AppStorage` configuration.
- Single example preview cannot show all batch conflicts; validation still must
  cover full requested scope before execution.
- Rename should not hide unsaved tag changes.
- Locked and read-only tracks must remain unchanged.
- Missing or deleted files must be reported as skipped warnings.

### Tooling, Environment, Sandbox, Filesystem Constraints

- Sandboxed file access may require existing track security-scoped bookmarks or
  configured sandbox path bookmarks.
- `FileManager.moveItem(at:to:)` fails if destination exists.
- A same-directory rename can still fail due to permissions, stale bookmarks,
  external moves, or locked files.
- Track file monitor may observe rename as external delete/move while rename is
  in progress.
- ViewInspector is preferred for SwiftUI sheet state and command wiring tests.
- XCUI should be reserved for menu integration if ViewInspector/source-order
  tests cannot validate it.

## High-Risk Implementation Concerns

### Product Or Behavioral Risks

- Batch collision handling can surprise users if one generated name duplicates
  another generated name.
- Unknown or fuzzy placeholder matches can rename many files incorrectly if the
  matcher is too permissive.
- Synonymous total tags must resolve predictably while reading the same value.
- Zero-padded tags must match existing padding-on-save output.
- Invalid replacement can create whitespace that space replacement must catch.
- File extension preservation must be consistent even when format text includes
  extension-like literal text.

### Tooling, Environment, Sandbox, Or Filesystem Risks

- Security-scoped bookmark resolution may fail for files imported from folders
  that no longer have valid access.
- `moveItem` can leave a partial batch if external filesystem state changes
  after validation.
- Rename may race with `TrackFileMonitor` external-change refresh.
- UI tests that rename files must use copied fixtures inside writable temp or
  app-owned caches directories.

## Proposed Implementation

### 1. Shared Rename Configuration Model

Add new model types, likely under `SwiftTag/Shared/Models` or
`SwiftTag/Features/TagEditor`:

- `TrackRenameConfiguration`
  - `format: String`
  - `invalidReplacementText: TrackRenameInvalidReplacementText`
  - `spaceReplacement: TrackRenameSpaceReplacement`
  - `strictReplacement: Bool`
- `TrackRenameConfigurationDefaults`
- `TrackRenameConfigurationKey`
- `TrackRenameInvalidReplacementText`
  - `.hyphen`
  - `.underscore`
  - `.period`
  - `.space`
- `TrackRenameSpaceReplacement`
  - `.hyphen`
  - `.underscore`
  - `.period`
  - `.none`
- `TrackRenameScope`
  - `.allTracks`
  - `.selectedTracks`
- Persist format string, invalid replacement selection, space replacement
  selection, and strict selection with `@AppStorage` so direct menu commands
  use last configured values.

### 2. Shared Tag Catalog

Add a reusable catalog, likely `TrackRenameTagCatalog`, with:

- canonical FLAC tag keys
- AppleScript property aliases
- user-facing aliases
- fuzzy normalization
- exact match before fuzzy match

Implementation options:

- Extract public/shared data from `SwiftTagScriptTrack.scriptPropertyTagKeys`.
- Keep AppleScript-specific wrappers private but duplicate canonical mapping in
  a neutral shared catalog and update AppleScript to consume it later.

Initial canonical keys should include at least:

- `ALBUM`
- `ALBUMARTIST`
- `ARTIST`
- `COMMENT`
- `COMPILATION`
- `COMPOSER`
- `DATE`
- `DESCRIPTION`
- `DISCNUMBER`
- `GENRE`
- `LOCATION`
- `TITLE`
- `TOTALDISCS`
- `TOTALTRACKS`
- `DISCTOTAL`
- `TRACKTOTAL`
- `zpDISCNUMBER`
- `zpDISCTOTAL`
- `zpTOTALDISCS`
- `zpTOTALTRACKS`
- `zpTRACKNUMBER`
- `zpTRACKTOTAL`
- `TRACKNUMBER`
- broader AppleScript-backed keys such as `CONDUCTOR`, `COPYRIGHT`,
  `ENCODED_BY`, `ISRC`, `PERFORMER`, `SOURCE`, and sort/replaygain keys.

### 3. Format Parser And Renderer

Add pure logic types:

- `TrackRenameFormatParser`
- `TrackRenameFormatToken`
  - `.literal(String)`
  - `.tag(raw: String, resolvedKey: String?)`
- `TrackRenameFormatRenderer`
- `TrackRenameValidationIssue`

Responsibilities:

- Tokenize literals and `|...|` placeholders.
- Detect unclosed placeholders.
- Normalize completed placeholders.
- Render track values.
- Render `TOTALTRACKS` and `TRACKTOTAL` from the same track-total value.
- Render `TOTALDISCS` and `DISCTOTAL` from the same disc-total value.
- Apply zero padding to numeric values only when using dedicated `zp...` tags,
  using existing padding-on-save behavior.
- Produce a normalized format string for completed tag tokens when safe.
- Produce preview and validation errors without mutating tracks.

### 4. Replacement Selection And Sanitizer

Add pure logic types:

- `TrackRenameInvalidReplacementText`
- `TrackRenameSpaceReplacement`
- `TrackRenameFilenameSanitizer`

Responsibilities:

- Map picker selections to literal replacement strings:
  - `-`
  - `_`
  - `.`
  - ` `
- Map space replacement picker selections to:
  - `-`
  - `_`
  - `.`
  - no replacement
- Replace non-strict invalid characters:
  - `/`
  - `:`
  - NUL
- Replace strict invalid characters:
  - `/`
  - `:`
  - NUL
  - `<`
  - `>`
  - `"`
  - `\`
  - `|`
  - `?`
  - `*`
  - ASCII control characters, codes 0-31
- Apply space replacement after invalid-character replacement.
- Return validation errors instead of throwing into the UI layer.

### 5. Rename Planner

Add pure/service logic:

- `TrackFileRenamePlanner`
- `TrackFileRenameRequest`
- `TrackFileRenameCandidate`
- `TrackFileRenamePlan`
- `TrackFileRenameError`

Responsibilities:

- Select tracks by scope.
- Exclude locked tracks from rename candidates.
- Treat read-only imports as locked, non-renameable tracks.
- Resolve generated destination names.
- Always preserve the original `.flac` extension.
- Return skipped warnings for missing or deleted files.
- Validate conflicts before move and abort the whole batch on conflicts.
- Return plan summary, skipped warnings, and blocking errors for execution and
  tests.

### 6. View Model Rename API

Add `TagEditorViewModel` APIs:

- `renameExample(configuration:) -> TrackRenamePreview`
- `canRenameTrackFiles(scope:configuration:) -> Bool`
- `validateTrackRenames(scope:configuration:) -> TrackRenameValidation`
- `renameTrackFiles(scope:configuration:) throws -> TrackFileRenameResult`

Execution should:

- Use existing `withResolvedTrackFileURL` / security scoped access path.
- Call `FileManager.moveItem(at:to:)`.
- Update track URL/bookmark/filename mirror.
- Refresh or suppress external difference state around the rename.
- Mark the referenced `.swifttag` document state as modified after successful
  renames.
- No-op same-path renames.

### 7. ContentView State And Sheet

Add state to `ContentView`:

- `@State private var isRenameSheetPresented`
- `@State private var isRenameOperationRunning`
- `@State private var renameErrorMessage`
- `@State private var isRenameErrorPresented`
- `@AppStorage` values for rename format, invalid replacement selection,
  space replacement selection, and strict selection.

Add:

- `renameSheetView`
- `showRenameTrackFilesConfig()`
- `renameTrackFiles(scope:)`
- `canRenameTrackFiles`
- `canRenameSelectedTrackFiles`
- `renameExample`

Attach sheet:

```swift
.sheet(isPresented: $isRenameSheetPresented) {
    TrackRenameConfigurationSheet(...)
}
```

### 8. Rename Configuration Sheet View

Add `TrackRenameConfigurationSheet`, likely under
`SwiftTag/Features/TagEditor`.

Layout:

- Top read-only `Text` or labeled row for `Rename Example`.
- `TextField("Rename Format", text: ...)`
- `Picker("Invalid Replacement", selection: ...)` with `-`, `_`, `.`, and
  `space`
- `Toggle("Strict", isOn: ...)`
- `Picker("Space Replacement", selection: ...)` with `-`, `_`, `.`, and
  `none`
- bottom trailing buttons:
  - `Cancel`
  - `Rename Selected Track Files`
  - `Rename All Track Files`

Use accessibility identifiers:

- `rename.example`
- `rename.formatField`
- `rename.invalidReplacementTextPicker`
- `rename.strictToggle`
- `rename.spaceReplacementPicker`
- `rename.cancelButton`
- `rename.renameSelectedButton`
- `rename.renameAllButton`

### 9. Menu And Focused Values

Extend `FocusedValues`:

- `performRenameTrackFiles`
- `performRenameSelectedTrackFiles`
- `showRenameTrackFilesConfig`
- `canPerformRenameTrackFiles`
- `canPerformRenameSelectedTrackFiles`
- `canShowRenameTrackFilesConfig`

Wire in `ContentView.commandFocusedContent`.

Update `SwiftTagApp.AppCommands` before `Reload Selected Tracks`:

```swift
Button("Rename Track Files") { performRenameTrackFiles?() }
    .disabled(!(canPerformRenameTrackFiles ?? false))

Button("Rename Selected Track Files") { performRenameSelectedTrackFiles?() }
    .disabled(!(canPerformRenameSelectedTrackFiles ?? false))

Button("Rename Track Files Config...") { showRenameTrackFilesConfig?() }
    .disabled(!(canShowRenameTrackFilesConfig ?? false))

Divider()
```

### 10. Track Table Context Menu

No context-menu rename item requested.

Do not add one unless confirmed.

### 11. User Documentation

Update docs where file menu workflows are documented, likely:

- `Docs/UserDocumentation/workflows/tags.html`
- `Docs/UserDocumentation/workflows/settings.html` if persistent rename
  defaults are documented there.
- `Docs/UserDocumentation/index.html` if navigation needs a link.

Document:

- format placeholders
- fuzzy tag examples
- dedicated zero-padded tags
- `TOTALTRACKS`/`TRACKTOTAL` and `TOTALDISCS`/`DISCTOTAL` synonyms
- replacement text picker values
- strict vs non-strict invalid character behavior
- conflict behavior
- selected vs all scope

## Test Strategy

Follow `Docs/Guides/testing-guide.md` order.

### Unit Tests

Add tests for:

- `|TRACKNUMBER| |TITLE|` tokenization.
- literal-only format.
- unclosed placeholder validation.
- unknown placeholder validation.
- exact tag match normalization.
- fuzzy matches:
  - `|track number|` -> `|TRACKNUMBER|`
  - `|number|` -> `|TRACKNUMBER|`
  - `|total tracks|` -> `|TOTALTRACKS|`
  - `|track total|` -> `|TRACKTOTAL|`
  - `|track count|` -> `|TOTALTRACKS|`
  - `|total discs|` -> `|TOTALDISCS|`
  - `|disc total|` -> `|DISCTOTAL|`
  - `|disc count|` -> `|TOTALDISCS|`
- ambiguous fuzzy matches produce validation errors.
- zero padding numeric `zpTRACKNUMBER`.
- zero padding numeric `zpDISCNUMBER`.
- zero padding numeric total tags.
- zero-padded tags match existing padding-on-save behavior.
- non-numeric `zp...` values stay unchanged.
- regular `TRACKNUMBER`, `DISCNUMBER`, and total tags are not zero-padded.
- invalid replacement picker maps `-`, `_`, `.`, and `space` to literal
  replacement text.
- space replacement picker maps `-`, `_`, `.`, and `none` to whitespace
  replacement behavior.
- non-strict sanitizer replaces `/`, `:`, and NUL.
- strict sanitizer replaces strict invalid characters.
- whitespace sanitizer replaces whitespace after invalid-character
  replacement.
- generated filename rejects empty output.
- generated filename rejects path separators after replacement.
- generated filename always preserves original `.flac` extension.
- duplicate generated destinations are detected.
- existing destination files are detected.
- locked tracks are excluded from rename candidates.
- missing or deleted files are returned as skipped warnings.

### Service / File Operation Tests

Use copied fixtures in temporary directories:

- Copy `SwiftTagTestFiles/test.flac` to temp.
- Import or construct track with source URL in temp.
- Rename to generated filename.
- Verify old path missing and new path exists.
- Verify `track.sourceFileURL` updates.
- Verify `track.tags[TagKey.filename]` updates.
- Verify bookmark data refreshes when available.
- Verify FLAC metadata is not rewritten by rename.
- Verify batch aborts before move when two tracks target same name.
- Verify locked tracks are not renamed.
- Verify missing source file is skipped with warning.
- Verify conflict dialog blocks the whole batch before any move.
- Verify same-path rename no-ops without error.
- Verify successful rename marks the referenced `.swifttag` document modified.

### SwiftUI / ViewInspector Tests

- `TrackRenameConfigurationSheet` renders requested controls.
- Editing format updates preview.
- Changing invalid replacement picker updates preview.
- Changing space replacement picker updates preview.
- Toggling strict updates preview.
- Invalid format disables rename buttons.
- No selection disables selected rename menu item and sheet button.
- No selection uses first loaded track for preview.
- Button callbacks pass selected/all scope.
- `TagEditorTrackFileView` remains unchanged unless context-menu rename is
  later confirmed.

### Source Order / Command Wiring Tests

- Verify `File` menu source order:
  - `Rename Track Files`
  - `Rename Selected Track Files`
  - `Rename Track Files Config...`
  - divider
  - `Reload Selected Tracks`
- Verify focused values expose rename actions and enablement from `ContentView`.
- Verify direct menu rename commands execute without confirmation when valid.
- Verify direct menu rename commands show dialogs for invalid configuration or
  batch rename errors.

### XCUI Tests

Add only if ViewInspector/source-order tests cannot verify menu integration.
If needed:

- Launch with copied FLAC fixture materialized in app-owned cache.
- Select track.
- Open rename config.
- Verify controls by accessibility identifier.
- Trigger selected rename and verify table filename updates.

### Verification Commands

1. `XcodeRefreshCodeIssuesInFile` for new/changed files.
2. `BuildProject`.
3. Targeted `SwiftTagTests` for rename parser/planner/service tests.
4. Targeted ViewInspector tests for sheet/source-order coverage.
5. Targeted `SwiftTagUITests` only if needed.

## Acceptance Criteria

- `File` menu shows rename items in requested order before reload.
- Config sheet opens on key editor window.
- Sheet contains requested label, text field, picker, checkbox, and buttons.
- Sheet does not contain a `Zero Pad` checkbox.
- Sheet contains `Invalid Replacement` picker values `-`, `_`, `.`, and
  `space`.
- Sheet contains `Space Replacement` picker values `-`, `_`, `.`, and `none`.
- Default config matches requested values.
- Rename format, invalid replacement selection, space replacement selection,
  and strict selection persist via `@AppStorage`.
- `Rename Example` updates live as format/replacement settings change.
- Completed tag placeholders normalize to canonical known tags.
- `|track number|` and `|number|` normalize to `|TRACKNUMBER|`.
- Dedicated `zp...` tags zero-pad numeric values.
- Dedicated `zp...` tags match existing padding-on-save behavior.
- `|total tracks|` normalizes to `|TOTALTRACKS|`.
- `|track total|` normalizes to `|TRACKTOTAL|`.
- `|track count|` defaults to `|TOTALTRACKS|`.
- `|total discs|` normalizes to `|TOTALDISCS|`.
- `|disc total|` normalizes to `|DISCTOTAL|`.
- `|disc count|` defaults to `|TOTALDISCS|`.
- Invalid placeholders disable rename actions.
- Non-strict replacement sanitizes `/`, `:`, and NUL with selected invalid
  replacement text.
- Strict replacement sanitizes requested strict invalid filename characters with
  selected invalid replacement text.
- Space replacement sanitizes whitespace after invalid-character replacement.
- Space replacement default `none` leaves whitespace unchanged.
- Menu rename all and sheet rename all share same code path.
- Menu rename selected and sheet rename selected share same code path.
- Direct menu rename commands do not prompt before valid renames.
- Invalid direct menu rename configuration shows a dialog.
- Selected rename uses current track-table selection.
- Selected rename controls are disabled when no tracks are selected.
- Rename preview uses first selected track, or first loaded track when nothing
  is selected.
- Locked and read-only tracks are excluded from rename.
- Missing or deleted files are skipped with warning.
- Format output is treated as filename stem and original `.flac` extension is
  always preserved.
- Rename updates table filename display.
- Rename updates track source file URL and bookmark.
- Rename marks referenced `.swifttag` document state as modified immediately.
- Rename does not write FLAC metadata.
- Batch conflicts abort the whole batch before files move and show a dialog.
- Build succeeds.
- Focused unit/service/ViewInspector coverage passes.

## Open Questions

None. Prior open questions have been moved into `Confirmed Decisions`.
