# Add SwiftTag Document Bookmark Plan

## Goal
Add bookmark-backed tracking for the associated `.swifttag` document so the app can follow external rename/move/delete events for the current document-backed session.

The intended result is:
- when a window is associated with a `.swifttag` document, the app stores a bookmark-backed reference rather than only a remembered URL
- when the associated `.swifttag` package is renamed or moved outside the app, the window title updates to the new file name and `.navigationDocument(...)` remains present with the updated live URL
- when the associated `.swifttag` package is deleted outside the app, the window title updates to the last known file name followed by ` (deleted)`
- when the user attempts to save after the associated `.swifttag` package has been deleted, the app explains that the document was deleted and offers saving to a new file

## Scope
In scope:
- Add bookmark-backed state for the associated `.swifttag` document.
- Track rename, move, delete, and restore-relevant state changes for the associated `.swifttag` package while the window is open.
- Update navigation metadata and `.navigationDocument(...)` from the live associated-document state.
- Update save behavior when the remembered associated document has been deleted.
- Keep editor-session registration in sync with the live associated-document URL so document routing stays correct after rename/move.
- Add targeted automated coverage for rename/move title updates, `.navigationDocument(...)` continuity, and deleted-document save prompting.

Out of scope:
- Changing the internal `.swifttag` package format.
- Adding autosave or background recovery for deleted associated documents.
- Reworking unsaved-FLAC close and quit behavior beyond the deleted-associated-document save path.
- Broad document-browser, toolbar, or window-management redesign.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed:
  - `Docs/Plans/20-AddSwiftTagDocumentSaveOptions.md`
- Relevant prior plans reviewed:
  - `Docs/Plans/18-UpdateWindowTitleText.md`
  - `Docs/Plans/17-SwiftTagDocumentReadLiveFileResolution.md`
- Current implementation files reviewed:
  - `SwiftTag/ContentView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackage.swift`
  - `SwiftTag/Shared/Utilities/EditorWindowCoordinator.swift`
  - `SwiftTag/Shared/Utilities/TrackFileMonitor.swift`
  - `SwiftTag/Shared/Utilities/UnsavedChangesFlow.swift`
  - `SwiftTagTests/SwiftTagTests.swift`
  - `SwiftTagTests/SwiftTagDocumentTests.swift`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
- Relevant fixtures inspected:
  - none required for the initial planning pass; existing temporary-package tests can reuse current `.swifttag` writer helpers and existing FLAC-backed document test helpers where needed
- Constraints accounted for:
  - `SwiftTagDocumentSaveState` currently remembers only `destinationURL` and `documentID`, so the current model cannot represent bookmark data, last-known file name, or deleted/unresolved state.
  - `TagEditorViewModel.editorNavigationMetadata(...)` currently derives the title and `.navigationDocument(...)` URL directly from the remembered destination URL.
  - `ContentView` already conditionally applies `.navigationDocument(...)`, so rename/move support only needs the underlying associated-document state to stay current.
  - `EditorWindowCoordinator` currently keys document-backed sessions by standardized `.swifttag` path and document ID; if the remembered path is not refreshed after rename/move, routing the same document can open a duplicate window.
  - `TrackFileMonitor` already provides a bookmark-aware file-monitoring pattern for FLAC files that can inform the associated-document implementation.
  - `.swifttag` is a package-type document, and `SwiftTagDocumentPackageWriter.save(...)` rewrites it through a temporary package plus `replaceItemAt` or `moveItem`, so any monitor must tolerate inode/path churn caused by in-app saves.
  - `performSwiftTagDocumentSave(using:)` currently treats the remembered destination as a normal save destination and does not distinguish a deleted associated document from a valid live document.

## Current Implementation Snapshot
- `SwiftTagDocumentSaveState` currently stores:
  - `destinationURL`
  - `documentID`
- `TagEditorViewModel.rememberSwiftTagDocumentSave(...)` and `loadSwiftTagDocument(...)` update only the remembered URL and document ID.
- `TagEditorViewModel.editorNavigationMetadata(...)` uses `rememberedSwiftTagDocumentSaveState.destinationURL?.lastPathComponent` as the source of truth for:
  - title precedence when a `.swifttag` document exists
  - `.navigationDocument(...)` URL exposure
  - displayed document name
- `ContentView.registerEditorSession()` republishes the remembered `.swifttag` URL and document ID into `EditorWindowCoordinator`.
- `EditorWindowCoordinator` currently matches open `.swifttag` windows by standardized path first and keeps a parallel map by document ID.
- `TrackFileMonitor` resolves security-scoped bookmarks, opens a file descriptor with `O_EVTONLY`, listens for `.write`, `.delete`, and `.rename`, and uses `F_GETPATH` to detect live path changes.
- `SwiftTagTests` already cover static navigation metadata for:
  - associated-document title precedence
  - standardized associated-document URL exposure
- `SwiftTagDocumentTests` already cover FLAC-track bookmark repair after external rename/move, but there is no equivalent coverage for the associated `.swifttag` document itself.
- `Docs/Plans/18-UpdateWindowTitleText.md` explicitly deferred this exact bookmark/rename/delete behavior into a future plan.

## Confirmed Decisions
- The associated `.swifttag` document should be tracked through a bookmark-backed reference so external file changes can be followed.
- When the associated `.swifttag` package is renamed or moved outside the app, the window title should update to the new file name and `.navigationDocument(...)` should stay present with the updated URL.
- When the associated `.swifttag` package is deleted outside the app, the window title should update to the last known file name followed by ` (deleted)`.
- When the associated `.swifttag` package is deleted outside the app, `.navigationDocument(...)` should remain attached to the last known document URL until the association is replaced.
- When the user attempts to save while the associated `.swifttag` package is deleted, the app should explain that the file was deleted and offer saving to a new file.
- The deleted-document save prompt should also offer recreating the document at the original path when that path becomes writable again.
- After recovery by saving to a new file, the new file should immediately become the associated document for future `Save` commands, title updates, and document routing.

## Dependencies And Constraints
- The implementation should keep a single source of truth for associated-document state rather than splitting it across navigation metadata, save routing, and editor-session registration.
- The associated-document model likely needs to grow beyond the current `SwiftTagDocumentSaveState`, or an adjacent `AssociatedSwiftTagDocumentReference` type should be introduced, to hold at least:
  - live URL
  - bookmark data
  - document ID
  - last-known display name
  - availability state such as available vs deleted vs unresolved
- Rename/move handling should refresh both the remembered live URL and any path-based coordinator registration so the same document continues routing to the existing window.
- Deleted-document handling needs a stable last-known display name even when no live URL remains.
- The save path should not silently recreate a deleted associated document at the stale path unless that behavior is explicitly chosen; the user request points toward a new-file save flow instead.
- Because the writer atomically replaces the package during normal saves, the document monitor must either:
  - tolerate self-initiated replacement events, or
  - be explicitly refreshed after successful save so the monitor tracks the new on-disk item without false deleted-state transitions.
- Bookmark resolution can become stale after external moves, so the implementation should plan for bookmark refresh on successful resolution and on successful save/open.
- Because the deleted state should keep `.navigationDocument(...)` attached to the last known URL, the associated-document model must preserve that last known URL even when the live item is unavailable.
- Associated-document saves continue to serialize the full editor session, not a selection-based subset, so no new track-selection source of truth should be introduced.

## Write-Back Behavior
- Preserved data:
  - the current editor session contents remain the source of truth for `.swifttag` document export
  - the existing associated document ID should remain stable across rename/move tracking and, unless clarified otherwise, across save-to-new-file recovery after deletion
  - current FLAC import state, track bookmarks, and unsaved editor changes remain in memory when the associated document is deleted
- Replaced data:
  - a normal associated-document save still rewrites the `.swifttag` package contents atomically using the current editor session state
  - a successful save-to-new-file recovery after deletion replaces the remembered associated-document URL/bookmark with the new destination
- Removed data:
  - once the associated document is deleted or replaced by a new destination, the stale path-based registration and stale bookmark should no longer be treated as the live associated document
- Selection semantics:
  - saving the associated `.swifttag` document continues to export the full loaded session rather than only selected tracks

## High-Risk Concerns
### Product / Behavioral Risks
- The deleted-title state requires preserving the last known file name separately from the live URL; otherwise the title can regress to a generic fallback after deletion.
- A normal in-app save should not flicker the title or temporarily mark the associated document as deleted just because the package was atomically replaced.
- If rename/move tracking updates the document URL but editor-session routing does not refresh at the same time, opening the same `.swifttag` package again can create duplicate windows.
- The deleted-document save prompt must clearly distinguish between:
  - saving back to an existing associated document
  - recovering from a deleted associated document
  - canceling and keeping the session open in the deleted state

### Tooling / Environment / Sandbox Risks
- `.swifttag` is a package directory, not a flat file, so rename/delete behavior may differ from single-file monitoring.
- Security-scoped bookmark resolution may fail or become stale after external moves into locations with different access requirements.
- Finder moves on the same volume may preserve inode identity, while cross-volume moves may present as copy-plus-delete; the monitor strategy must handle both predictable and degraded paths.
- Tests that assert real titlebar state can be brittle; the preferred path is a narrow, testable state seam plus one targeted integration-level assertion only where helper coverage is insufficient.

## Implementation Phases
1. Introduce Bookmark-Backed Associated Document State
- Expand the remembered associated-document model so it can represent bookmark-backed live state rather than only a URL and document ID.
- Store the associated-document bookmark whenever the app:
  - saves a `.swifttag` document
  - opens a `.swifttag` document
- Preserve a last-known display name separate from the live URL so deleted-title rendering is stable.
- Add a small, pure derivation seam for:
  - effective title text
  - optional `.navigationDocument(...)` URL
  - optional document display name
  - deleted-state handling

2. Add Associated Document Monitoring And Live-URL Refresh
- Introduce a dedicated associated-document monitor, likely modeled after `TrackFileMonitor`, that resolves the bookmark and observes `.write`, `.rename`, and `.delete` events for the `.swifttag` package.
- On rename or move:
  - resolve the live current path
  - refresh the remembered live URL
  - refresh stale bookmark data when possible
  - republish the updated document URL into `EditorWindowCoordinator`
- On deletion:
  - keep the last-known display name
  - transition the associated-document state into a deleted/unavailable status
  - update any path-based routing maps so stale paths are no longer treated as live
- After successful in-app saves, re-arm or refresh the monitor so atomic package replacement does not leave it attached to the wrong item.

3. Wire Navigation Metadata To The Associated Document State
- Update `TagEditorViewModel.editorNavigationMetadata(...)` to derive title and document metadata from the richer associated-document state.
- Preserve the existing title precedence for live associated documents.
- Add deleted-title formatting as `<last known name> (deleted)`.
- Keep `.navigationDocument(...)` present with the updated live URL after rename/move.
- Keep `.navigationDocument(...)` attached to the last known document URL while the associated document is in the deleted state.

4. Intercept Save When The Associated Document Has Been Deleted
- Add a deleted-associated-document branch before remembered-destination saves proceed.
- Present a dedicated alert that explains the associated `.swifttag` document was deleted and offers:
  - saving to a new file
  - recreating the document at the original path when possible
- Route the recovery paths through the existing save-panel helper or direct original-path save helper so the successful destination becomes the new associated document on success.
- Keep the window open and in the deleted state if the user cancels the recovery save flow.
- Ensure successful recovery save updates:
  - live URL
  - bookmark data
  - document routing registration
  - window title
  - `.navigationDocument(...)` state

5. Add Targeted Automated Coverage
- Add pure tests for associated-document navigation state derivation covering:
  - live associated document
  - renamed/moved associated document
  - deleted associated document
  - deleted associated document recovered to a new destination
- Add targeted file-system tests using temporary directories/packages for:
  - rename within the same directory
  - move to a different directory on the same volume
  - deletion of the associated package
- Add a targeted test confirming that when the associated `.swifttag` package is renamed or moved:
  - the window title metadata updates to the new file name
  - `.navigationDocument(...)` remains present
  - the exposed document URL matches the updated location
- Add save-flow tests confirming that when the associated document is deleted:
  - normal save does not silently write to the stale path
  - the deleted-document prompt appears
  - choosing the recovery save path associates the new file
  - cancel leaves the window in the deleted state

## Test Strategy
Order:
1. Pure unit tests:
  - associated-document state derives live title and document URL when the document is available
  - associated-document state derives updated title and updated document URL after rename/move
  - associated-document state derives `<last known name> (deleted)` when the document is deleted
  - deleted associated-document state routes save through the recovery prompt path instead of remembered-destination save
2. Service / filesystem tests using temporary directories:
  - bookmark-backed associated-document resolution refreshes the live URL after rename
  - moving the associated `.swifttag` package to a different folder refreshes the live URL and keeps the same logical document identity
  - deleting the associated `.swifttag` package transitions the state into deleted/unavailable
  - successful save-to-new-file recovery replaces the stale bookmark and live URL
3. Targeted UI/state wiring tests where practical:
  - `ContentView.navigationMetadata` follows the richer associated-document state rather than raw remembered URL-only state
  - `.navigationDocument(...)` is still applied when the live associated-document URL changes after rename/move
4. Verification workflow:
  - prefer targeted build/test runs over full-suite execution
  - prefer pure and service tests first
  - add a heavier runtime assertion only if helper-level coverage cannot credibly verify `.navigationDocument(...)` continuity

## Acceptance Criteria
- Saving or opening a `.swifttag` document records a bookmark-backed associated-document reference for the active session.
- When the associated `.swifttag` package is renamed outside the app, the active window title updates to the new file name and `.navigationDocument(...)` remains present with the updated URL.
- When the associated `.swifttag` package is moved outside the app, the active window title updates to the new file name and `.navigationDocument(...)` remains present with the updated URL.
- Reopening or re-routing the same `.swifttag` package after rename/move still targets the existing session instead of opening a duplicate window.
- When the associated `.swifttag` package is deleted outside the app, the title becomes `<last known name> (deleted)`.
- After associated-document deletion, invoking save does not silently continue as though the original document still exists.
- After associated-document deletion, the user is prompted that the file was deleted and is offered both:
  - saving to a new file
  - recreating the document at the original path when available
- If the user completes either recovery path, the recovered destination becomes the associated document for future title, `.navigationDocument(...)`, and save behavior.
- If the user cancels the recovery save, the window remains open and continues showing the deleted-associated-document state.
- Automated tests cover rename/move metadata updates and deleted-document save recovery behavior sufficiently for implementation sign-off.

## Open Questions
- None currently.
