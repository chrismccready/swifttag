# Add Sandbox Path Settings Plan

## Goal

Add a General settings section where users can maintain a table of folders that
SwiftTag may access later through app-scoped, read/write security-scoped
bookmarks.

Primary use case: AppleScript or another non-panel workflow asks SwiftTag to
read or write a FLAC file or `.swifttag` document path that was not already
authorized by the current per-file open/save panel flow.

## Scope

### In Scope

- Add a `Sandbox Paths` section after `SwiftTag Document Save` in
  `SwiftTag/Features/Settings/GeneralSettingsView.swift`.
- Add a one-column `Table` with column title `Sandbox Paths`.
- Add plus and minus buttons below the table, visually matching the small
  bordered icon buttons in `TagEditorMiscTagsView`.
- Use an `NSOpenPanel` folder picker when plus is clicked.
- Allow multiple folder selection in the open panel and add each valid unique
  folder.
- Create and persist read/write security-scoped bookmark data for each valid
  selected folder.
- Keep the sandbox table within available General tab/window space and let the
  table scroll instead of expanding the settings window.
- Add a context menu to the sandbox table with:
  - `Sort by Name`
  - `Sort by Date Added`
  - separator
  - `Add Path…`
  - `Remove Path(s)`
- Prevent duplicate stored paths.
- Remove selected table rows and their persisted bookmark records when minus is
  clicked.
- Add a shared bookmark-access helper that existing file read/write flows can
  use as fallback when no per-file bookmark or active panel grant works.
- Use sandbox path bookmarks for FLAC read/write and SwiftTag document save
  fallback paths where the target path is inside a stored folder.
- Add required app-scope bookmark entitlement support.
- Add focused unit/ViewInspector tests and targeted runtime verification.

### Out Of Scope

- Replacing existing per-track and per-document bookmark behavior.
- Changing tag-only, picture-only, selected-track, or all-track save semantics.
- Adding Full Disk Access support.
- Adding AppleScript terminology for managing sandbox paths.
- Changing FLAC metadata mapping or fixture formats.
- Automatically scanning sandbox folders.
- Writing, deleting, or moving any user files when adding/removing sandbox path
  rows.

## Plan Input Checklist Coverage

- Latest numbered plan reviewed:
  - `Docs/Plans/28-AddSwiftTagUseDocumentation.md`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
  - `Docs/Guides/git-commit-message-guide.md`
  - `Docs/AppleDocsIndex/apple-docs-scout-agent.md`
- Relevant app files reviewed:
  - `SwiftTag/Features/Settings/GeneralSettingsView.swift`
  - `SwiftTag/Features/Settings/SettingsView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorMiscTagsView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/ContentView.swift`
  - `SwiftTag/FlacMetadataService.swift`
  - `SwiftTag/Shared/Models/SaveSettings.swift`
  - `SwiftTag/Shared/Utilities/TrackFileMonitor.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentMonitor.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackageReader.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackageWriter.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagAppleScriptSupport.swift`
  - `SwiftTag.xcodeproj/project.pbxproj`
- Relevant tests reviewed:
  - `SwiftTagTests/TrackStatusViewInspectorTests.swift`
  - `SwiftTagTests/SwiftTagTests.swift`
  - `SwiftTagTests/SwiftTagAppleScriptTests.swift`
  - `SwiftTagUITests/SwiftTagUITests.swift`
- Relevant fixtures reviewed:
  - `SwiftTagTestFiles/test.flac`
  - `SwiftTagTestFiles/test-with_padding.flac`
- Tooling reviewed:
  - `xcodebuild -scheme SwiftTag -showBuildSettings` shows main app sandbox is
    enabled and user-selected files are already read/write.

## Current Implementation Snapshot

- The main app target has App Sandbox enabled.
- The main app target has `ENABLE_USER_SELECTED_FILES = readwrite`.
- Existing imports start access for URLs returned from panels, import FLAC
  files, and create per-track `.withSecurityScope` bookmark data.
- `Track` stores optional `securityScopedBookmarkData`.
- `.swifttag` document save state stores optional document bookmark data.
- FLAC saves go through `TagEditorViewModel.saveTrack`, then
  `withAccessingSecurityScopedTrackURL`.
- Track resolution currently prefers per-track bookmark data, then remembered
  URL/path fallback.
- SwiftTag document saves already resolve the current document bookmark when
  saving a referenced document.
- AppleScript FLAC save reuses `viewModel.saveSynchronously`, so it benefits
  from any shared track URL resolution improvement.
- AppleScript document save reuses `performSwiftTagDocumentSave`, so it needs
  matching folder-bookmark fallback for explicit destinations or remembered
  destinations without a current document bookmark.
- Existing monitors keep security-scoped access open only while an observation
  needs it, then stop access in cancel handlers.

## Apple Documentation Review

Apple Docs Scout findings:

- `Accessing files from the macOS App Sandbox`
  - URL: `https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox`
  - User-selected folders extend sandbox access to contained items, including
    nested folders, during the granted access period.
- `Persist file access with security-scoped URL bookmarks`
  - URL: `https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox#Persist-file-access-with-security-scoped-URL-bookmarks`
  - Create bookmark data with `URL.bookmarkData(...)` and `.withSecurityScope`.
  - Resolve later with `URL(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)`.
  - Recreate and persist bookmark data when `bookmarkDataIsStale` is true.
- `URL.startAccessingSecurityScopedResource()`
  - URL: `https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource()`
  - Start access before using a resolved security-scoped URL.
- `URL.stopAccessingSecurityScopedResource()`
  - URL: `https://developer.apple.com/documentation/foundation/url/stopaccessingsecurityscopedresource()`
  - Balance every successful start with stop, preferably with `defer`.
- `App Sandbox: File Access`
  - URL: `https://developer.apple.com/documentation/security/app-sandbox#File-Access`
  - Relevant entitlements include App Sandbox, user-selected read/write files,
    and app-scoped security-scoped bookmarks.
- `com.apple.security.files.user-selected.read-write`
  - URL: `https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.files.user-selected.read-write`
  - Needed for read/write access to user-selected files and folders.
- `Security-scoped bookmark access`
  - URL: `https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access`
  - Relevant entitlement: `com.apple.security.files.bookmarks.app-scope`.
- `NSOpenPanel`
  - URL: `https://developer.apple.com/documentation/appkit/nsopenpanel`
  - Configure folder-only selection with `canChooseDirectories = true` and
    `canChooseFiles = false`.

## Confirmed Decisions

- Plan file path is `Docs/Plans/29-AddSandboxSettings.md`.
- Add section goes after existing `SwiftTag Document Save` section.
- The settings table has one visible column: `Sandbox Paths`.
- Plus opens a folder-only picker with multiple selection enabled.
- Plus creates read/write security-scoped bookmark data.
- Duplicate prevention uses normalized path identity.
- Minus removes selected table rows and their stored bookmark data.
- Removing rows does not touch folders or files on disk.
- Sandbox table stays within the available General tab/window container and
  uses table scrolling for overflow.
- Sandbox table context menu exposes `Sort by Name`, `Sort by Date Added`,
  `Add Path…`, and `Remove Path(s)`.
- Sorting uses stored path names and original date-added values.
- Stored folder bookmarks are fallback access only; existing per-file
  open/save panel authorization remains first choice.
- Folder bookmarks are app-scoped, not document-relative.
- Start/stop security-scoped access is per operation, not at app launch.

## Product Behavior

### Add Folder

1. User opens Settings > General.
2. User clicks plus button under the `Sandbox Paths` table, or chooses
   `Add Path…` from the table context menu.
3. App presents `NSOpenPanel`:
   - `canChooseDirectories = true`
   - `canChooseFiles = false`
   - `allowsMultipleSelection = true`
   - `resolvesAliases = true`
   - prompt: `Add`
4. User selects one or more folders.
5. App processes selected folder URLs in panel order.
6. App normalizes each selected folder URL:
   - `standardizedFileURL`
   - `resolvingSymlinksInPath()`
7. App validates each selected item is a directory.
8. App checks existing stored rows and rows added in this batch for same
   normalized path.
9. If duplicate exists, app skips that folder and continues processing the
   batch.
10. If unique, app creates bookmark data with `.withSecurityScope`.
11. App stores row with normalized path, bookmark data, and date added.
12. App persists settings.
13. Table displays normalized path strings using the active sort mode.

### Remove Folder

1. User selects one or more rows in `Sandbox Paths` table.
2. Minus button and context menu `Remove Path(s)` are enabled only when
   selection is nonempty.
3. User clicks minus or chooses `Remove Path(s)` from the table context menu.
4. App removes selected records from persisted settings.
5. App clears removed IDs from table selection.
6. App does not delete, move, edit, or inspect selected folders.

### Sort Sandbox Paths

1. User opens the sandbox table context menu.
2. User chooses `Sort by Name` or `Sort by Date Added`.
3. App updates the active sort mode.
4. Table reorders rows without changing bookmark data.
5. Sort mode persists so relaunch keeps the chosen table order.

### Later File Access

When a FLAC file or SwiftTag document path needs access and existing
authorization fails or is unavailable:

1. App finds first stored sandbox folder whose normalized path contains the
   target path.
2. App resolves the folder bookmark with `.withSecurityScope` and `.withoutUI`.
3. If bookmark is stale, app recreates bookmark data from the resolved folder
   and updates the stored row.
4. App calls `startAccessingSecurityScopedResource()` on the resolved folder.
5. App performs read/write operation on the target file.
6. App calls `stopAccessingSecurityScopedResource()` with `defer`.
7. If access fails, app reports existing save/import error style with target
   path context.

Path containment must be exact:

- target path equals folder path, or
- target path has prefix `folderPath + "/"`.

This avoids false matches such as `/Music` matching `/Music Archive`.

## Proposed Data Model

Create a small shared model, for example in
`SwiftTag/Shared/Models/SandboxPathSettings.swift`:

```swift
struct SandboxPathBookmarkRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var path: String
    var bookmarkData: Data
    var dateAdded: Date
}
```

Optional future fields can be added if needed:

- `displayName`
- `lastResolvedAt`
- `lastErrorDescription`
- `accessMode`

For this feature, access mode is always read/write, so avoid adding a visible
mode until product behavior needs it.

## Proposed Persistence

Use `UserDefaults` for settings-level bookmark records unless implementation
finds a concrete size or migration reason to use Application Support.

Recommended shape:

- Add `SaveSettingsKey.sandboxPathBookmarks`.
- Add `SaveSettingsKey.sandboxPathSortMode`.
- Add `SaveSettingsDefaults.sandboxPathBookmarks = []`.
- Add `SaveSettingsDefaults.sandboxPathSortMode = .dateAdded`.
- Store `[SandboxPathBookmarkRecord]` as encoded `Data`.
- Store sort mode as a raw string value.
- Prefer `PropertyListEncoder` / `PropertyListDecoder` for native `Data`
  storage.
- Keep path string only as display and duplicate identity.
- Treat bookmark data as authority for access.

Reasoning:

- Current app settings already use `UserDefaults`.
- Records are small.
- Bookmark data is not a secret, though it grants scoped access to this app.
- Existing UI test settings reset already clears the app defaults domain.

## Proposed Access Helper

Create a shared utility, for example
`SwiftTag/Shared/Utilities/SandboxPathBookmarkAccess.swift`.

Responsibilities:

- Load stored records.
- Normalize folder and target paths.
- Find containing folder record for target URL.
- Resolve bookmark with `.withSecurityScope` and `.withoutUI`.
- Refresh stale bookmark data and persist updated row.
- Start access before body.
- Stop access after body.
- Surface errors with enough path context for existing save error messages.

Suggested API shape:

```swift
enum SandboxPathBookmarkAccess {
    static func withAccess<T>(
        to targetURL: URL,
        _ body: (URL) throws -> T
    ) throws -> T?
}
```

Return `nil` when no stored folder contains target URL. Throw when matching
record exists but bookmark resolution or access fails.

## Implementation Phases

### Phase 1: Entitlements And Models

- Add app-scope bookmark entitlement for main app:
  - `com.apple.security.files.bookmarks.app-scope = true`
- Preserve current app sandbox and user-selected read/write file settings.
- If Xcode generated entitlements cannot express app-scope bookmarks through
  build settings, add an explicit main-app entitlements file.
- Add `SandboxPathBookmarkRecord`.
- Add `SandboxPathSortMode`.
- Add store/codec methods for loading and saving records.
- Add path normalization and containment helpers.

### Phase 2: Settings UI

- Update `GeneralSettingsView.swift`.
- Add `@State` table row selection.
- Load sandbox path records from store.
- Add section after `SwiftTag Document Save`.
- Add `Table(records, selection:)` with one `TableColumn("Sandbox Paths")`.
- Feed the table sorted rows from the active sort mode.
- Give the table a fixed or geometry-constrained max height within the General
  tab so it scrolls internally instead of resizing the settings window.
- Add plus/minus buttons below table in an `HStack`.
- Match `TagEditorMiscTagsView` button size:
  - `20 x 20`
  - `Image(systemName: "plus")`
  - `Image(systemName: "minus")`
  - `.buttonStyle(.bordered)`
  - help text
- Add accessibility identifiers:
  - `settings.general.sandboxPaths.table`
  - `settings.general.sandboxPaths.addButton`
  - `settings.general.sandboxPaths.deleteButton`
- Add a context menu to the table with commands in this exact order:
  - `Sort by Name`
  - `Sort by Date Added`
  - separator
  - `Add Path…`
  - `Remove Path(s)`
- Keep `Remove Path(s)` disabled when selection is empty.
- Keep table and controls inside current General tab/window container space;
  prefer internal table scroll bars over increasing settings window size.

### Phase 3: Folder Picker And Row Mutations

- Implement plus action with `NSOpenPanel`.
- Enable multiple selection in `NSOpenPanel`.
- Share plus button and context menu `Add Path…` through the same add-folder
  action.
- Process selected folders in panel order.
- Start security-scoped access for each selected folder while validating and
  creating bookmark data if needed.
- Create `.withSecurityScope` bookmark data, without
  `.securityScopeAllowOnlyReadAccess`.
- Normalize path.
- Reject non-directory result.
- Ignore duplicate normalized paths, including duplicates selected in the same
  panel batch.
- Append unique rows with `dateAdded = .now` and persist once per completed
  batch when possible.
- Implement minus/context-menu remove action against selected row IDs.
- Keep UI selection stable after removal.
- Implement sort context menu actions against `SandboxPathSortMode`.

### Phase 4: Shared Fallback Access

- Add `SandboxPathBookmarkAccess.withAccess`.
- Unit-test path containment independent from bookmark APIs.
- Unit-test stale bookmark update through injected resolver/store seams if
  direct stale bookmark creation is not deterministic.
- Make helper side-effect small:
  - no access at app launch
  - no background folder scans
  - no long-lived access tokens unless a monitor explicitly needs one later

### Phase 5: FLAC Read/Write Integration

- Update `TagEditorViewModel.withResolvedTrackFileURL`.
- Keep existing order:
  1. Per-track security-scoped bookmark.
  2. Current file path if directly accessible.
  3. Remembered source file URL if directly accessible.
  4. Stored sandbox folder bookmark if target path is inside a saved folder.
- When folder bookmark fallback succeeds:
  - pass target file URL to existing read/write body while folder access is
    active.
  - create a refreshed per-file bookmark for target file if possible.
  - update track source URL/bookmark through existing resolved-reference path.
- Ensure `save`, `saveSynchronously`, reload, external diff refresh, and
  document track-reference validation all benefit because they already call
  `withResolvedTrackFileURL`.

### Phase 6: SwiftTag Document Save Integration

- Update `withAccessingResolvedSwiftTagDocumentDestination`.
- Existing referenced document bookmark remains first choice.
- If no document bookmark applies, try stored sandbox folder bookmark for:
  - explicit AppleScript destination
  - remembered destination without resolvable document bookmark
  - destination parent folder when writing a new `.swifttag` package
- Keep save-panel flow unchanged.
- Refresh document bookmark after successful save using existing save result
  behavior.

### Phase 7: Error Handling And UI State

- Use existing save/import error presentation where possible.
- Add a specific error only if needed:
  - failed to resolve sandbox path bookmark
  - failed to access sandbox path
  - selected path is not a folder
- Do not show noisy alerts for duplicate add; no-op is acceptable unless
  implementation reveals user confusion.
- Do not expose bookmark data in UI or logs.

## Destructive And Write-Back Behavior

### Existing Data Preserved

- User folders and files are preserved.
- Existing per-track bookmark data is preserved.
- Existing SwiftTag document bookmark data is preserved.
- Existing save settings are preserved.
- Existing `.swifttag` document package format is preserved.

### Existing Data Replaced

- A stored sandbox path row's bookmark data may be replaced when resolved as
  stale and refreshed.
- Settings persistence blob for sandbox paths is replaced when rows are added,
  removed, or refreshed.

### Existing Data Removed

- Minus removes selected sandbox path bookmark records from app settings only.
- Minus does not remove any filesystem item.

### Partial Save Behavior

- Tag-only saves still write tags only.
- Picture-only saves still write pictures only.
- Tags-and-pictures saves still write both.
- Selected-track saves still use selected tracks from the editor table.
- All-track saves still use all tracks.
- Sandbox path fallback changes only whether SwiftTag can access a target file.

### Selection Semantics

- `Sandbox Paths` table selection is the source of truth for minus.
- Editor track selection remains the source of truth for selected-track saves.
- The two selections are independent.

## High-Risk Concerns

### Product Or Behavioral Risks

- Users may expect adding a folder to import files automatically. It should not.
- Duplicate paths may differ by symlink or alias. Normalize aggressively.
- A stored folder may be moved, renamed, deleted, or live on an unavailable
  volume.
- A path may be inside a stored folder but still fail due POSIX permissions,
  ACLs, SIP, TCC privacy protection, or file locks.
- Bookmark data grants access to this app, so export/logging should avoid
  exposing raw data.
- Adding broad folders gives broad app access. UI should label paths plainly.

### Tooling, Sandbox, Or Filesystem Risks

- Xcode generated entitlements may not expose app-scope bookmarks as a build
  setting. Explicit entitlements file may be needed.
- `FileManager.fileExists` can fail before security scope starts, so fallback
  code must try folder bookmark using known path strings.
- Security-scoped access leaks kernel resources if stop is not balanced.
- `replaceItemAt` and temp-file rewrites need write access to original file and
  sometimes parent directory.
- SwiftTag document package saves write a temp package then move/replace into
  destination; access may need to wrap parent directory.
- Full UI automation of `NSOpenPanel` can be brittle.
- AppleScript UI tests can be affected by Apple Event sandbox/TCC rules.

## Testing Strategy

Follow project test order.

### Unit Tests

- `SandboxPathBookmarkRecord` encodes and decodes with bookmark data.
- Store returns empty array for missing settings key.
- Store ignores corrupt persisted data safely.
- Duplicate detection treats normalized equivalent paths as same path.
- Batch add skips duplicates already stored and duplicates within the batch.
- Path containment rejects prefix-only siblings.
- Removing selected IDs removes only matching records.
- Sort-by-name orders rows by localized path/name comparison.
- Sort-by-date-added orders rows by original add timestamp.
- Access helper returns `nil` when no stored folder contains target path.
- Access helper refreshes stale bookmark data through injected resolver/store
  seam.

### Service Tests

- Use temporary directories and copied FLAC fixtures:
  - `SwiftTagTestFiles/test.flac`
  - `SwiftTagTestFiles/test-with_padding.flac`
- Verify folder-access helper can wrap a target URL inside a registered folder
  and run a read/write closure.
- Verify no write occurs when target path is outside all registered folders.
- Keep fixture mutations on copied files only.

### ViewInspector Tests

- `GeneralSettingsView` exposes:
  - `settings.general.sandboxPaths.table`
  - `settings.general.sandboxPaths.addButton`
  - `settings.general.sandboxPaths.deleteButton`
- Delete button disables with empty selection.
- Table column label source contains `Sandbox Paths`.
- Sandbox section appears after `SwiftTag Document Save` source text.
- Plus/minus button source uses same symbol names and button size pattern as
  `TagEditorMiscTagsView`.
- Source includes `allowsMultipleSelection = true` for sandbox path panel.
- Source includes context menu items in required order.
- Table has constrained height or layout code that prevents General settings
  window growth and allows internal table scrolling.

### Targeted UI Or Runtime Verification

- Build app and inspect entitlements if needed:
  - App Sandbox enabled.
  - User-selected files read/write enabled.
  - App-scoped bookmarks enabled.
- Manual or targeted XCUI smoke:
  1. Open Settings > General.
  2. Add temporary folder through panel.
  3. Confirm path appears.
  4. Relaunch app.
  5. Confirm path persists.
  6. Remove path.
  7. Confirm path no longer appears after relaunch.
- AppleScript save fallback smoke, if automation is stable:
  1. Copy `test.flac` into a temporary folder.
  2. Add that folder as a sandbox path.
  3. Relaunch app.
  4. Use AppleScript save path that does not go through a save panel.
  5. Confirm save succeeds and copied FLAC changed as expected.

### Verification Command Order

1. `XcodeRefreshCodeIssuesInFile` on touched Swift files.
2. `BuildProject`.
3. Targeted `RunSomeTests` for new unit/ViewInspector tests.
4. Targeted UI test only for panel/settings persistence if added.
5. Full suite only if explicitly requested or if implementation touches broad
   save behavior enough to justify it.

## Acceptance Criteria

- General settings shows `Sandbox Paths` section after
  `SwiftTag Document Save`.
- Table has one visible column labeled `Sandbox Paths`.
- Plus and minus buttons appear below the table and match misc tag button style.
- Plus opens folder-only picker with multiple selection enabled.
- Table stays within available General tab/window container space and scrolls
  internally when rows overflow.
- Context menu contains `Sort by Name`, `Sort by Date Added`, separator,
  `Add Path…`, and `Remove Path(s)`.
- Adding a valid unique folder stores read/write security-scoped bookmark data.
- Adding multiple valid unique folders stores each path and bookmark.
- Adding same normalized path twice leaves one row.
- Minus removes selected rows and associated bookmark data.
- Context menu `Add Path…` matches plus behavior.
- Context menu `Remove Path(s)` matches minus behavior.
- `Sort by Name` sorts by path/name.
- `Sort by Date Added` sorts by original date added.
- Stored sandbox paths persist across app relaunch.
- Existing open/save panel and per-track bookmark behavior remains unchanged.
- FLAC save/reload paths can use stored folder bookmark fallback.
- SwiftTag document saves can use stored folder bookmark fallback for eligible
  destinations.
- Security-scoped access is always balanced with stop.
- Stale bookmarks are refreshed when resolved.
- Entitlements include app-scope bookmarks.
- Focused tests cover storage, duplicate logic, path containment, UI source, and
  access helper behavior.

## Open Questions

No blocking questions.

Default assumptions for implementation:

- Duplicate add is silent no-op.
- Table displays normalized absolute POSIX path.
- App does not expose sandbox path settings through AppleScript in this phase.
