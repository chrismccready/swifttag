# Add FLAC Document Open Support Plan

## Goal
Add proper macOS Finder/open-document support for `.flac` files so opening one or more FLAC files through Finder, Dock drop, or `open` routes those files into SwiftTag using the same append-oriented behavior as the existing `Add FLAC files...` flow.

## Scope
In scope:
- Add app-level document-open handling for `.flac` file URLs delivered by macOS.
- Route Finder-opened FLAC files through the same duplicate filtering and append import path used by `Add FLAC files...`.
- Preserve the current loaded editor session contents when opening FLAC files from Finder.
- Support launch-time opens and opens delivered while the app is already running.
- Decide and document which editor window/session receives Finder-opened files.
- Add targeted tests for routing, buffering, duplicate handling, and add-vs-load behavior.
- Verify project metadata needed for Finder document opening is actually persisted in source.

Out of scope:
- Replacing the existing `Load FLAC files...` behavior.
- Converting SwiftTag to an `NSDocument`-based app.
- Adding Finder-open support for folders or non-FLAC file types.
- Changing FLAC metadata import/write semantics beyond reusing the current add import path.
- Redesigning the app icon or document icon artwork.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/11-v4-AddMultiPicturePerTrackSupport.md`.
- Current implementation files reviewed:
- `SwiftTag/SwiftTagApp.swift`
- `SwiftTag/ContentView.swift`
- `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
- `SwiftTag/Shared/Utilities/EditorWindowCoordinator.swift`
- `SwiftTag/Shared/Models/EditorSessionModels.swift`
- `SwiftTag/Features/TagEditor/TagEditorTrackFileView.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Relevant fixtures inspected:
- `SwiftTagTestFiles/test.flac`
- `SwiftTagTestFiles/test-with_padding.flac`
- Constraints accounted for:
- The app currently uses `WindowGroup` plus `@NSApplicationDelegateAdaptor`, not `NSDocument`.
- The current importer in `ContentView` distinguishes `Load FLAC files...` from `Add FLAC files...` through `pendingImporterAddsFiles`.
- Duplicate suppression for add flows currently happens before import via `removeDuplicateImportURLsByBookmarkIdentity(_:)`.
- Imported tracks immediately create security-scoped bookmarks in `TagEditorViewModel.importFlacFiles(_:locked:append:)`.
- The app is sandboxed with `ENABLE_USER_SELECTED_FILES = readwrite`, so Finder-delivered URLs and launch-time document opens must be treated carefully and bookmarked promptly.
- The current saved project file does not show persisted document-type or imported-UTI entries yet, so document icon/type registration cannot be confirmed from source in its present state.

## Current Implementation Snapshot
- `SwiftTagApp` declares app commands and an application delegate, but it does not currently implement `application(_:openFiles:)`, `application(_:open:)`, or another Finder-open entry point.
- `ContentView` already has the append behavior we want for Finder-open:
- `showAddWritableImporter()` sets `pendingImporterAddsFiles = true`.
- `handleFlacImportResult(_:)` filters duplicates only for add flows and then imports with `append: true`.
- `importFlacFiles(_:locked:append:)` in `TagEditorViewModel` appends imported tracks without clearing current tracks when `append == true`.
- `EditorWindowCoordinator` already owns editor-session discovery/opening and is the best existing seam for routing Finder-opened files into either an existing session or a newly opened window.
- `EditorSessionValue` currently supports reopen-notification state but has no field for pending Finder-open URLs.

## Confirmed Decisions
- Default Finder-open behavior for `.flac` files will follow the current `Add FLAC files...` path rather than the destructive `Load FLAC files...` path.
- Finder-opened FLAC files should append to the target editor session and preserve existing loaded tracks and unsaved edits.
- Duplicate filtering should match the current add behavior by bookmark identity/path identity in the target session before import.
- Finder-opened files should import as writable by default, matching `Add FLAC files...`, not `Add FLAC files (read-only)...`.
- The source of truth for the target session will be the focused/frontmost editor session when one exists while the app is already active; if the app is not active when Finder-open arrives, SwiftTag should always create a new editor window and deliver the pending FLAC files there after the scene is ready.
- Current table selection is not the source of truth for Finder-open routing; the operation is session-scoped append behavior.
- If Finder/open-document delivers a mixed batch containing valid `.flac` files and unsupported URLs, SwiftTag should silently ignore the unsupported URLs and continue importing the valid FLAC files.

## Dependencies And Constraints
- App-level document-open callbacks may arrive before SwiftUI scene registration finishes, so the implementation needs a buffering/forwarding mechanism between `AppDelegate`, `EditorWindowCoordinator`, and `ContentView`.
- Finder can deliver multiple URLs in one event, and launch-time delivery may happen before the initial `WindowGroup` content is interactive.
- The target session must reuse the add-import duplicate filter so Finder-open does not create duplicate tracks when a file is already loaded.
- Imported URLs should become security-scoped bookmarks as part of the existing import path rather than inventing a second bookmarking path.
- Proper document opening in Finder also depends on the project’s document-type/UTI registration being persisted in source control, not only shown in unsaved Xcode UI state.

## High-Risk Concerns
### Product / Behavioral Risks
- If Finder-open accidentally routes through the load path instead of the add path, users could lose unsaved in-editor context by replacing the current session contents.
- Multiple-window behavior can feel unpredictable if the target session is not clearly defined and consistent with the frontmost editor window when the app is active versus the always-open-new-window rule when the app is inactive.
- Duplicate filtering must happen against the target session’s currently loaded tracks, or repeated Finder opens may create duplicate table entries.

### Tooling / Environment / Sandbox Risks
- Sandbox-opened document URLs may behave differently at launch versus while the app is active, so the implementation should avoid assuming a SwiftUI view is already mounted when the callback fires.
- Full UI automation for Finder-open/document events is likely brittle and slower than necessary in this environment; coordinator/unit coverage should be preferred, with XCUI reserved for a narrow end-to-end case only if needed.
- The current repository state does not yet expose persisted document-type metadata, so Finder integration may appear incomplete in source even if Xcode UI changes were made locally but not saved into the project file.

## Implementation Phases
1. Persist And Verify Document Registration
- Re-check the Xcode project metadata after saving the project so `CFBundleDocumentTypes`/`LSItemContentTypes`, imported UTI declarations, and document icon references are visible in source.
- Confirm the `.flac` document type is registered to the intended icon file and UTI before treating Finder-open behavior as complete.

2. Add App-Level Finder Open Entry Point
- Extend `AppDelegate` in `SwiftTagApp.swift` with the appropriate macOS open-files callback for Finder/document events.
- Normalize incoming URLs and silently filter out non-FLAC payloads at the app boundary.
- Forward accepted URLs into a coordinator instead of importing directly in the app delegate.

3. Add Session Routing And Pending-Open Buffering
- Extend `EditorWindowCoordinator` with a pending document-open queue and an API for delivering FLAC URLs to either the current frontmost session or a new session when no suitable editor window is registered yet.
- Extend `EditorSessionValue` only if needed to carry pending open-file identifiers into the destination scene.
- Ensure launch-time opens can survive the gap between app delegate callback time and `ContentView` registration time.

4. Reuse The Existing Add Import Path In ContentView
- Add a dedicated `ContentView` entry point that accepts externally supplied FLAC URLs and routes them through the same append import behavior as `Add FLAC files...`.
- Reuse `collectFlacFiles(from:)` where practical, but keep Finder-open constrained to file URLs rather than folder recursion unless explicitly delivered in a supported way.
- Reuse `removeDuplicateImportURLsByBookmarkIdentity(_:)` and `importFlacFiles(_:locked:append:)` with `locked: false` and `append: true`.
- Surface import errors through the existing FLAC import alert flow.

5. Register Session Focus And Target Selection
- Track which editor session is frontmost/eligible for Finder-open delivery so the routing rule is explicit and testable while the app is active.
- Ensure Finder-open always creates a new editor window when the app is inactive, including launch-time opens and inactive-app reopen events.

6. Validation And Hardening
- Add targeted tests around coordinator routing, pending-open buffering, and append import behavior.
- Run targeted build/test verification rather than a full UI suite by default.
- Re-check the project file for persisted document registration after Xcode saves the updated metadata.

## Test Strategy
Order:
1. Unit tests for app/coordinator routing logic:
- opening FLAC files with an existing focused session routes to that session
- opening FLAC files while the app is inactive queues work and opens a new editor session even if other sessions already exist
- opening FLAC files with no registered session queues work and opens a new editor session
- pending open-file delivery flushes once the destination session registers
- non-FLAC URLs are silently ignored before import
2. Service/view-model tests:
- append import from external URLs preserves existing tracks
- duplicate filtering removes files already loaded in the target session
- imported Finder-opened files are bookmarked through the existing import path
3. Targeted UI/state tests where practical:
- `ContentView` external-open handler uses append semantics, not load semantics
- import errors still surface through the existing alert path
4. XCUI only if a narrow end-to-end document-open scenario is required and ViewInspector/unit seams cannot validate the scene lifecycle confidently.

## Acceptance Criteria
- The saved project metadata contains the `.flac` document type, imported UTI mapping, and document icon registration needed for Finder association.
- SwiftTag responds to Finder/open-document `.flac` events instead of ignoring them.
- Opening `.flac` files through Finder appends them to the target editor session using the same semantics as `Add FLAC files...`.
- Existing loaded tracks and unsaved edits are preserved when Finder-open adds files to an existing session.
- Duplicate files already present in the target session are not re-imported.
- If no editor session is available yet, SwiftTag opens a new editor window and imports the pending FLAC files there once the scene is ready.
- If the app is inactive when Finder-open occurs, SwiftTag opens a new editor window and imports the pending FLAC files there once the scene is ready, rather than reusing an existing window.
- Imported Finder-opened files remain writable by default and participate in the existing bookmark-based monitoring/save flows.
- Unsupported non-FLAC URLs delivered in the same open event are silently ignored while valid FLAC files continue importing.
- Errors during Finder-open import surface through the existing import error presentation.

## Open Questions
- None currently.
