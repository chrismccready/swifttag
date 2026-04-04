# Add SwiftTag Document Read Plan

## Goal
Add explicit `.swifttag` document open support to SwiftTag so users can choose `Open SwiftTag Document...` from the File menu, select one or more `.swifttag` packages, and have each selected document routed to the correct editor window while loading track state as a normal editable session with the same difference detection and formatting indicators used by standard track editing.

## Scope
In scope:
- Add a File menu item titled `Open SwiftTag Document...` immediately after `Add FLAC files (read-only)...` and before the following divider.
- Present an open panel constrained to `.swifttag` package documents and allow selecting one or more documents.
- Route each selected document URL through window-association logic so SwiftTag either:
- creates a new editor window when no suitable window exists
- focuses an already associated window when that document is already open
- creates a new editor window for a selected document that is not already associated with an existing window
- Add a `.swifttag` package reader that decodes the saved manifest plus pooled picture assets from the existing package format written by `SwiftTagDocumentPackageWriter`.
- Reconstruct editor session state from a `.swifttag` document so loaded tracks behave like normally edited tracks, including tag/picture state, snapshots, diff indicators, and formatting/status presentation.
- Remember per-session SwiftTag document identity/URL so reopened document sessions can participate in later save/update flows without guessing.
- Add targeted tests for menu wiring, document parsing, window routing, session association, and loaded-track behavior.

Out of scope:
- Converting SwiftTag to `NSDocument` or `DocumentGroup`.
- Replacing Finder-open `.flac` behavior added in the existing FLAC document-open flow.
- Changing the `.swifttag` package schema unless document-read implementation reveals a concrete compatibility gap that must be clarified first.
- Broad redesign of save notifications, general multi-window architecture, or unrelated File menu organization.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/15-AddSwiftTagDocumentCreation.md`.
- Relevant prior plans reviewed:
- `Docs/Plans/12-AddFLACDocumentOpenSupport.md`
- `Docs/Plans/15-AddSwiftTagDocumentCreation.md`
- Current implementation files reviewed:
- `SwiftTag/SwiftTag/SwiftTagApp.swift`
- `SwiftTag/SwiftTag/ContentView.swift`
- `SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
- `SwiftTag/SwiftTag/Features/FlacImport/FlacImportMapper.swift`
- `SwiftTag/SwiftTag/Shared/Models/EditorSessionModels.swift`
- `SwiftTag/SwiftTag/Shared/Models/Track.swift`
- `SwiftTag/SwiftTag/Shared/Models/TrackStatus.swift`
- `SwiftTag/SwiftTag/Shared/Utilities/EditorWindowCoordinator.swift`
- `SwiftTag/SwiftTag/Shared/Utilities/SwiftTagDocumentPackage.swift`
- `SwiftTag/SwiftTag/Info.plist`
- `SwiftTag/SwiftTagTests/SwiftTagTests.swift`
- `SwiftTag/SwiftTagTests/SwiftTagDocumentTests.swift`
- `SwiftTag/SwiftTagUITests/SwiftTagUITests.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Relevant fixtures inspected:
- `SwiftTagTestFiles/test.flac`
- `SwiftTagTestFiles/test-with_padding.flac`
- No checked-in `.swifttag` fixture currently exists, so document-read verification will likely need generated packages or a new dedicated fixture.
- Constraints accounted for:
- The app already registers `.swifttag` as a package document type in `Info.plist` and already writes that package format through `SwiftTagDocumentPackageWriter`.
- The current app architecture is `WindowGroup` plus focused-scene commands and `EditorWindowCoordinator`, not `NSDocument`.
- `EditorWindowCoordinator` currently routes external document opens only for `.flac` files and does not yet track `.swifttag` document associations by URL or document identity.
- `TagEditorViewModel` can export `.swifttag` save state but does not yet import a `.swifttag` package back into editable `Track` state.
- Current editor status/difference UI depends on `Track.latestFileSnapshot`, `Track.externalDifferences`, imported picture records, and existing per-track fingerprint/bookmark state.
- Multi-window focus and key-window behavior are app-lifecycle concerns that are better covered with coordinator tests plus narrow UI verification than with broad XCUI flows.

## Current Implementation Snapshot
- `SwiftTagApp` already owns the File menu command wiring through `FocusedValues`, and it already places `Save SwiftTag Document...` after the save command group.
- `ContentView` already wires focused-scene save commands, window registration, and external `.flac` open delivery through `EditorWindowCoordinator`.
- `EditorWindowCoordinator` already knows how to open or focus editor windows and buffer pending file opens, but its existing API is FLAC-specific and keyed to session IDs and track-set fingerprints rather than SwiftTag document URLs/IDs.
- `SwiftTagDocumentPackageWriter` defines the saved package structure:
- root `Info.plist`
- root `Pictures/`
- manifest keys `Id`, `Version`, `Fingerprint`, and `Tracks`
- per-track keys `Fingerprint`, `FLAC File URL`, `FLAC File Bookmark`, `FLAC Fingerprint`, `Tags`, and `Pictures`
- per-picture keys `File`, `FLAC Type`, `MIME Type`, `Description`, `Width`, `Height`, `Depth`, and `Colors`
- `TagEditorViewModel.importFlacFiles(_:locked:append:)` builds editable `Track` values plus `latestFileSnapshot` from live FLAC reads, which is the closest existing seam for “standard editing” behavior.
- There is currently no `.swifttag` package reader, no manifest-to-track mapper, and no session-level association between an open window and a SwiftTag document URL.

## Confirmed Decisions
- The new File menu command title is `Open SwiftTag Document...`.
- The command is placed after `Add FLAC files (read-only)...` and before the following divider in the File menu.
- Selecting the command shows an open dialog for `.swifttag` documents.
- If multiple `.swifttag` documents are selected while no windows are open, SwiftTag opens one new window per selected document.
- If no window is open and one `.swifttag` document is selected, SwiftTag creates a new window and loads that document.
- If one or more windows are open and one is already associated with a selected document, SwiftTag makes that associated window key.
- If one or more windows are open and none are associated with a selected document, SwiftTag opens a new window for that document, makes it key, and loads the document there.
- Tracks loaded from a `.swifttag` document must be treated the same as tracks edited through the standard app flow, so existing difference types and formatting indicators remain in play.
- The source of truth for “selected items” in this feature is the `.swifttag` URLs selected in the open panel, not the current track-table selection.
- After opening a `.swifttag` document, the target session immediately remembers that document URL and document `Id` so `Save SwiftTag Document...` overwrites the same package by default.
- When `.swifttag` contents differ from the current FLAC files on disk, the editor initially treats the `.swifttag` contents as the baseline and surfaces live/current FLAC differences as external differences.

## Dependencies And Constraints
- The read path should reuse the existing saved `.swifttag` manifest contract from `SwiftTagDocumentPackageWriter` rather than inventing a parallel document format.
- Window routing must define a stable association key for an opened SwiftTag document:
- likely normalized document URL
- possibly document `Id`
- and must decide how those keys behave if the package moves, is duplicated, or is opened from a different path
- Reopened document sessions should integrate with the existing remembered SwiftTag save state so the app knows whether later `Save SwiftTag Document...` should overwrite the same package or prompt again.
- The implementation needs a way to build editable `Track` values, picture state, and `TrackFileSnapshot` baselines from package contents without breaking current FLAC import behavior.
- If live FLAC file URLs/bookmarks stored in the package are stale or inaccessible, the app still needs a defined load behavior for the editor session and its status indicators.
- Because the app already uses `EditorWindowCoordinator` for Finder-opened FLAC files, extending that coordinator is likely the lowest-risk seam for document-to-window association and key-window activation.
- Open-panel handling, URL normalization, and multi-window activation may require AppKit-first seams rather than pure SwiftUI inspection.

## High-Risk Concerns
### Product / Behavioral Risks
- If document association is keyed inconsistently, the same `.swifttag` package could open in duplicate windows instead of focusing the existing one.
- If manifest data is mapped into `Track` state differently from normal FLAC imports, status icons, external-difference overlays, and saveability indicators may drift from the standard editing experience.
- If the load baseline is underspecified, SwiftTag could either hide genuine differences or immediately show misleading unsaved/external differences when a document opens.
- If pooled picture assets are reconstructed incorrectly, album-art deduplication or picture-difference detection may not match standard edit sessions.
- Multi-select document opens need deterministic ordering, or users may see surprising key-window outcomes.

### Tooling / Environment / Sandbox Risks
- Open panel and key-window activation are difficult to validate with ViewInspector alone and may need narrow XCUI coverage or coordinator-level AppKit seams.
- `.swifttag` packages are file packages with nested assets, so fixture handling and temporary-directory tests must validate both plist decoding and picture-file reads.
- Security-scoped bookmark resolution behavior may differ between tests and live app sessions, especially when a saved package references FLAC files that are no longer accessible.

## Implementation Phases
1. Finalize Read Semantics And Association Rules
- Confirm the remaining behavior questions before implementation:
- Define the canonical association key used to decide whether a selected document is “already open.”

2. Add SwiftTag Document Open Command
- Extend `FocusedValues` and `SwiftTagApp` command wiring for `Open SwiftTag Document...`.
- Present an `NSOpenPanel` constrained to `.swiftTagDocument`.
- Allow multi-selection and normalize the selected document URLs.

3. Extend Window Routing For SwiftTag Documents
- Add coordinator support for routing selected `.swifttag` documents one-by-one.
- Track which editor session is associated with which SwiftTag document.
- Reuse existing open-window/key-window behavior when a matching session already exists.
- Queue document loads for newly opened windows until their `ContentView` is registered and ready to receive the load request.
- Preserve a deterministic multi-selection order so “one new window per selected document” is testable and repeatable.

4. Build A SwiftTag Package Reader And Mapping Layer
- Add a dedicated reader for:
- `Info.plist` decoding
- `Pictures/` asset lookup
- manifest validation and version handling
- Map manifest tracks and pooled picture files into editor-ready state:
- tags
- picture records
- source FLAC URL/bookmark/fingerprint
- remembered SwiftTag document URL and document `Id`
- Build the session snapshot model needed for standard editing indicators, rather than treating document-read sessions as a separate track type.

5. Load Document Data Into ContentView And View Models
- Add a `ContentView`/view-model entry point for replacing the current session contents from a decoded SwiftTag document.
- Ensure a newly opened document session registers its associated document URL with the coordinator and updates remembered save state.
- Preserve the same UI and behavioral contracts used by normal editor sessions:
- table content
- album-art state
- save enablement
- diff/status presentation
- error presentation when load fails
- Use the decoded `.swifttag` content as the initial editor baseline and compare current/live FLAC file state against that baseline for external-difference presentation.

6. Add Targeted Tests And Verification
- Add pure unit tests for manifest decoding, picture-asset resolution, and manifest-to-track mapping.
- Add coordinator tests for:
- existing associated window is focused
- unassociated document opens a new window
- pending document loads flush after new session registration
- multi-selection routing order
- Add service/view-model tests for document-to-editor reconstruction and diff baseline behavior.
- Add targeted UI/XCUI coverage for the new File menu command and, if practical, the open-panel/menu routing seam.
- Prefer `BuildProject`, then targeted tests, and reserve broader UI runs only for the narrow menu/open-window scenario if needed.

## Test Strategy
Order:
1. Pure unit tests:
- decode valid `.swifttag` manifest data
- reject malformed or incomplete manifests with clear errors
- resolve picture references from `Pictures/`
- map manifest tracks into stable editor-side models
- normalize document URLs used for association checks
2. Service or bridge tests using temp packages:
- create a `.swifttag` package with the current writer, then read it back through the new reader
- verify tags, picture metadata, pooled image reuse, FLAC URL/bookmark data, and remembered document identity survive round-trip
- verify generated editor state can participate in standard save/diff logic
3. Targeted SwiftUI/state tests where practical:
- focused command publication and enablement for `Open SwiftTag Document...`
- session load path replaces content in the target window instead of appending unrelated tracks
- remembered SwiftTag document state is restored into the view model after open
4. Targeted coordinator/AppKit tests:
- existing associated session becomes the target/key window for repeated opens
- unassociated selected documents create new sessions
- multiple selected documents route deterministically
5. XCUI only where lighter seams are insufficient:
- File menu shows `Open SwiftTag Document...`
- invoking the command reaches the expected open flow if the panel can be driven reliably in this environment

## Acceptance Criteria
- The File menu shows `Open SwiftTag Document...` between `Add FLAC files (read-only)...` and the following divider.
- Choosing the command presents an open panel restricted to `.swifttag` package documents.
- Selecting a document when no editor window is open creates an editor window and loads that document.
- Selecting a document that is already open focuses the associated window instead of opening a duplicate session.
- Selecting a document with no associated window opens a new editor window for that document and loads it there.
- Multi-select document opens follow a documented, deterministic window-routing rule.
- When multiple selected documents are opened while no windows exist, SwiftTag opens one new window per selected document.
- SwiftTag can decode the existing `.swifttag` package format written by the app today.
- Tracks loaded from a `.swifttag` document appear and behave like standard editor tracks, including existing difference/status/formatting indicators.
- The loaded session remembers the opened document URL and document identity consistently enough for later save/update flows.
- When live FLAC state differs from the opened `.swifttag` contents, the session uses the `.swifttag` contents as baseline and surfaces the live FLAC state as external differences.
- Targeted automated tests cover menu placement, package decoding, window association/routing, and document-to-editor reconstruction sufficiently for implementation sign-off.

## Open Questions
- None currently.
