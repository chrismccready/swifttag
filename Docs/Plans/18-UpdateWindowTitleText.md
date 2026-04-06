# Update Window Title Text Plan

## Goal
Add window titlebar navigation metadata to `ContentView` so the macOS titlebar reflects the current editor state using SwiftUI's navigation-title APIs:
- `.navigationTitle(...)`
- `.navigationSubtitle(...)`
- `.navigationDocument(...)`

The intended result is:
- `SwiftTag` when the editor window is empty
- the selected tracks' shared album when one or more tracks are selected
- `Mixed` when selected tracks do not share the same album value
- the associated SwiftTag document name when the session is backed by a `.swifttag` document
- a contextual subtitle showing loaded-track counts plus unsaved tag/picture change counts
- a titlebar proxy icon only when a valid SwiftTag document URL is available

## Scope
In scope:
- Add derived title text for empty, selected-album, mixed-album, and SwiftTag-document-backed states.
- Add derived subtitle text with:
- total loaded track count
- selected track count
- total tag change count
- selected-track tag change count
- total picture change count
- selected-track picture change count
- Apply `.navigationTitle(...)` and `.navigationSubtitle(...)` from `ContentView`.
- Apply `.navigationDocument(...)` only when the current session has an associated SwiftTag document URL.
- Add targeted automated coverage for the title/subtitle/document derivation logic and the UI wiring seam.

Out of scope:
- Changing SwiftTag document open/save routing behavior beyond exposing existing document metadata to the titlebar.
- Renaming documents from the titlebar.
- Broad toolbar redesign or unrelated window-architecture changes.
- Reworking save-status notifications, file-monitoring behavior, or track-diff logic beyond what is needed to surface counts in the titlebar.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/17-SwiftTagDocumentReadLiveFileResolution.md`.
- Relevant prior plans reviewed:
- `Docs/Plans/15-AddSwiftTagDocumentCreation.md`
- `Docs/Plans/16-AddSwiftTagDocumentRead.md`
- `Docs/Plans/17-SwiftTagDocumentReadLiveFileResolution.md`
- Current implementation files reviewed:
- `SwiftTag/SwiftTag/ContentView.swift`
- `SwiftTag/SwiftTag/SwiftTagApp.swift`
- `SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
- `SwiftTag/SwiftTag/Shared/Models/Track.swift`
- `SwiftTag/SwiftTag/Shared/Models/TrackStatus.swift`
- `SwiftTag/SwiftTagTests/SwiftTagTests.swift`
- `SwiftTag/SwiftTagTests/SwiftTagDocumentTests.swift`
- `SwiftTag/SwiftTagTests/TrackStatusViewInspectorTests.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Apple SwiftUI documentation reviewed via Xcode documentation search:
- `Configure your apps navigation titles`
- `navigationTitle(_:)`
- `navigationSubtitle(_:)`
- `navigationDocument(_:)`
- Relevant fixtures inspected:
- None required for the initial planning pass because this feature is driven by editor/session state rather than FLAC format behavior.
- Constraints accounted for:
- `ContentView` currently returns `presentedContent` directly and does not apply window title/navigation modifiers.
- The editor already tracks selected rows through `viewModel.selectedTrackIDs`.
- `TagEditorViewModel.sharedAlbumDisplayText(in:)` already computes shared-vs-mixed album text for a save scope, but it currently uses the internal mixed marker (`*`) rather than the requested user-facing `Mixed` string.
- `TagEditorViewModel.editorDifferenceCounts(...)` already computes track-level unsaved tag and picture change counts for an arbitrary set of track IDs.
- `TagEditorViewModel.swiftTagDocumentSaveState()` already exposes the remembered `.swifttag` document URL and document ID for the active session.
- `EditorWindowCoordinator` registration already uses the remembered SwiftTag document URL and ID, so titlebar document metadata should reuse that existing session state instead of introducing a second document-source-of-truth.
- The current editor view is not obviously wrapped in a root `NavigationStack`, so modifier placement needs to be verified carefully to avoid accidental layout or toolbar regressions.
- ViewInspector support for direct navigation-title assertions may be limited, so the safest coverage path is likely pure helper tests plus a very thin UI-wiring seam.

## Current Implementation Snapshot
- `ContentView.body` currently returns `presentedContent` with no `.navigationTitle`, `.navigationSubtitle`, or `.navigationDocument` modifiers on the editor root.
- `ContentView` already reacts to:
- track selection changes
- track-list identity changes
- SwiftTag document save-state changes
- album-art state changes
- save-operation state
- `ContentView.handleOpenedSwiftTagDocument(_:)` loads a SwiftTag document and `registerEditorSession()` republishes the remembered document URL/ID after load.
- `TagEditorViewModel` already contains the core ingredients needed for titlebar text:
- `trackItems`
- `selectedTrackIDs`
- `mixedSelectionMarker`
- `sharedAlbumDisplayText(in:)`
- `editorDifferenceCounts(for:tagWriteOptions:albumArtPictures:)`
- `swiftTagDocumentSaveState()`
- Existing difference counts are track-level counts:
- `tagEdits` increments once per track with any tag differences
- `pictureEdits` increments once per track with any picture differences
- Existing tests already exercise selection-sensitive and difference-sensitive behavior in the view model, but there is not yet a titlebar/navigation-specific test seam.

## Confirmed Decisions
- When a SwiftTag document is associated with the session, the document name always overrides the album-based title.
- If selected tracks all share an empty album value, the title uses the document name when one exists; otherwise it uses `Untitled`.
- `Tag Changes` and `Picture Changes` use the existing track-level counts from `editorDifferenceCounts(...)`.
- Subtitle selected counts continue to include deleted tracks when those tracks remain selected.
- Apply `.navigationTitle(...)`, `.navigationSubtitle(...)`, and `.navigationDocument(...)` directly to `ContentView`; do not add a `NavigationStack` or similar wrapper for this feature.

## Dependencies And Constraints
- The implementation should keep a single source of truth for navigation metadata, preferably derived from `TagEditorViewModel` or a small dedicated helper owned by it, rather than duplicating selection and diff-count logic inside `ContentView`.
- The displayed title should follow this confirmed precedence order:
- associated SwiftTag document name when present
- `Untitled` when selected tracks exist but their shared album value is empty and there is no document name
- selected-track shared album when selected tracks share one non-empty album value
- `Mixed` when selected tracks disagree on album
- `SwiftTag` when the editor window is empty
- `navigationDocument(_:)` should only be applied when there is a real document URL for the current session; windows without an associated document must not show a stale or fake proxy icon.
- Subtitle derivation depends on current editor differences, which already require `TagWriteOptions` plus the current album-art snapshot, so the titlebar computation must stay aligned with the same save/diff inputs used elsewhere in `ContentView`.
- The user has already confirmed that the required titlebar behavior works by applying the modifiers directly to `ContentView`, so the plan should preserve the current root view structure and avoid navigation-container wrapper work.
- The requested display text uses `Mixed`, not the internal mixed marker `*`, so the implementation should translate internal mixed state into a user-facing title string rather than exposing the marker directly.

## High-Risk Concerns
### Product / Behavioral Risks
- Applying document metadata from remembered save state must not cause an untitled non-document session to look like it is backed by a saved `.swifttag` package after unrelated state changes.

### Tooling / Environment / Sandbox Risks
- SwiftUI titlebar behavior on macOS depends on the primary destination/navigation context, and `ContentView` is not currently structured as an obvious navigation container.
- ViewInspector may not expose the final AppKit titlebar state directly, so tests should focus on deterministic helper outputs and thin modifier wiring instead of brittle runtime titlebar inspection.

## Implementation Phases
1. Finalize Title And Counting Semantics
- Encode the confirmed precedence so the SwiftTag document name overrides album-based title text whenever a SwiftTag document is associated with the session.
- Encode the empty-album fallback so the title becomes the document name when one exists or `Untitled` otherwise.
- Reuse the existing track-level `editorDifferenceCounts(...)` model for subtitle change counts.
- Ensure subtitle selected counts continue to include deleted tracks when those tracks remain selected.

2. Extract Navigation Metadata Derivation
- Add a small, testable derivation seam that computes:
- the effective window title string
- the effective window subtitle string
- the optional document URL
- the optional document display name
- Reuse the existing sources of truth already present in the view model:
- `selectedTrackIDs`
- `trackItems`
- `swiftTagDocumentSaveState()`
- `editorDifferenceCounts(...)`
- Translate internal mixed markers into the requested user-facing `Mixed` output.
- Keep empty-state fallback logic explicit so `SwiftTag` only appears in the intended cases.

3. Apply Navigation Modifiers In ContentView
- Attach `.navigationTitle(...)` and `.navigationSubtitle(...)` at the narrowest `ContentView` seam that reliably drives the window titlebar.
- Apply `.navigationDocument(...)` only when the derived document URL is non-`nil`.
- Keep the current root view structure intact and apply the modifiers directly to `ContentView`.

4. Add Automated Coverage
- Add pure unit tests for title derivation covering:
- empty window
- selected tracks with one shared album
- selected tracks with mixed album values
- associated SwiftTag document title precedence
- empty selected album fallback
- Add pure unit tests for subtitle derivation covering:
- no tracks loaded
- loaded tracks with no selection
- selected tracks with unsaved tag changes
- selected tracks with unsaved picture changes
- mixed total/selected counts
- Add tests for document gating:
- document URL absent means no titlebar document metadata
- document URL present returns the standardized URL and expected display name
- Add targeted UI/runtime tests for the explicitly requested titlebar scenarios:
- default starting window shows `SwiftTag` and no navigation-document URL
- newly created editor window shows `SwiftTag` and no navigation-document URL
- adding a FLAC whose album tag is populated sets the title to that album and leaves navigation-document URL absent
- adding a FLAC with no album tag sets the title to `Untitled` and leaves navigation-document URL absent
- adding two FLAC files where one has an album and one does not:
- selecting the track with an album sets the title to that album and leaves navigation-document URL absent
- selecting the track without an album sets the title to `Untitled` and leaves navigation-document URL absent
- opening a `.swifttag` document sets the title to the document file name and makes navigation-document URL present
- saving a window with no associated document to a `.swifttag` document sets the title to the document file name and makes navigation-document URL present
- Prefer app/runtime seams that can assert actual title/document state reliably; only fall back to heavier XCUI coverage where lighter verification cannot observe the window metadata.

5. Verify On The Preferred Toolchain Path
- Use Xcode diagnostics/build tooling first.
- Prefer `BuildProject`.
- Run targeted tests for the new helper coverage instead of broad UI runs.
- Only consider heavier UI/runtime verification if the navigation modifier behavior cannot be trusted from the build plus helper tests alone.

## Test Strategy
Order:
1. Pure unit tests:
- title is `SwiftTag` when no tracks are loaded
- title is the shared album when selected tracks share the same non-empty album
- title is `Mixed` when selected tracks disagree on album
- title uses the SwiftTag document name when a SwiftTag document is associated with the session, even if a selected album value exists
- title is `Untitled` when selected tracks share an empty album value and there is no associated SwiftTag document name
- subtitle reports loaded and selected track counts correctly
- subtitle reports total and selected tag-change counts correctly using the existing track-level counting model
- subtitle reports total and selected picture-change counts correctly using the existing track-level counting model
- subtitle selected counts include deleted tracks when those tracks remain selected
- document metadata is omitted when no remembered SwiftTag document URL exists
- document metadata returns the remembered SwiftTag document URL when present
2. SwiftUI/state tests where practical:
- `ContentView` consumes the derived title/subtitle/document values through one narrow seam rather than recomputing them independently
3. Targeted UI/runtime tests:
- default starting window has title text `SwiftTag` and no `.navigationDocument(...)` URL
- new window has title text `SwiftTag` and no `.navigationDocument(...)` URL
- importing a FLAC with an album sets the title text to that album and no `.navigationDocument(...)` URL
- importing a FLAC without an album sets the title text to `Untitled` and no `.navigationDocument(...)` URL
- importing two FLACs where only one has an album:
- selecting the track with an album sets the title text to that album and no `.navigationDocument(...)` URL
- selecting the track without an album sets the title text to `Untitled` and no `.navigationDocument(...)` URL
- opening a `.swifttag` document sets the title text to the document file name and makes `.navigationDocument(...)` URL present
- saving a previously non-document-backed window to a `.swifttag` document sets the title text to the document file name and makes `.navigationDocument(...)` URL present
4. Verification workflow:
- prefer Xcode code-issue refresh for touched files
- prefer `BuildProject`
- run targeted unit tests plus the specific UI/runtime titlebar tests above
- reserve broader UI/runtime validation only if modifier placement proves unusually fragile

## Acceptance Criteria
- An empty editor window shows `SwiftTag` as the title.
- A session with an associated SwiftTag document shows the document name as the title, regardless of the current selected-track album value.
- A non-empty editor window with one or more selected tracks and no associated SwiftTag document shows the selected tracks' shared album as the title when that shared album is non-empty.
- A selection whose tracks do not share the same album shows `Mixed` as the title.
- A selection whose shared album value is empty and has no associated SwiftTag document shows `Untitled` as the title.
- A session with an associated SwiftTag document shows the document-backed title text and exposes the document URL through `.navigationDocument(...)`.
- A session without an associated SwiftTag document does not expose `.navigationDocument(...)`.
- The default starting window shows `SwiftTag` and no document URL via `.navigationDocument(...)`.
- A newly created window shows `SwiftTag` and no document URL via `.navigationDocument(...)`.
- Adding a FLAC file with a populated album value sets the window title to that album and leaves `.navigationDocument(...)` absent.
- Adding a FLAC file with no album value sets the window title to `Untitled` and leaves `.navigationDocument(...)` absent.
- When two FLAC files are loaded and only one has an album value, selecting the album-backed track sets the title to that album and selecting the album-empty track sets the title to `Untitled`; both cases leave `.navigationDocument(...)` absent.
- Opening a `.swifttag` document sets the window title to the document file name and makes `.navigationDocument(...)` present.
- Saving a previously non-document-backed window to a `.swifttag` document sets the window title to the saved document file name and makes `.navigationDocument(...)` present.
- The titlebar subtitle displays:
- total loaded track count
- selected track count
- total tag change count
- selected-track tag change count
- total picture change count
- selected-track picture change count
- Deleted tracks remain included in subtitle selected counts when they are selected.
- Title and subtitle update when selection changes, track contents change, save-state/document association changes, or picture/tag diffs change.
- The implementation keeps a single, testable derivation seam for title/subtitle/document metadata instead of duplicating logic across the view.
- Automated tests cover the agreed title precedence and subtitle count behavior sufficiently for implementation sign-off.

## TODO
These items are intentionally deferred and should not be implemented until specifically requested:
- Add an associated `.swifttag` document file bookmark so file changes outside the app can be tracked.
- Add a test confirming that when a `.swifttag` file is renamed or moved, the window title updates and `.navigationDocument(...)` remains present with the correct updated URL.
- Add functionality to handle associated document deletion:
- update the window title text to the last known filename followed by ` (deleted)`
- when the user attempts to save, prompt that the file was deleted and offer saving to a new file
- Add a limit to album title length of 32 characters with a middle ellipsis.

## Open Questions
- None currently.
