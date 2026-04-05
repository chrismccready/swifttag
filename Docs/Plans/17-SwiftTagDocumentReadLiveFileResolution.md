# SwiftTag Document Read Live File Resolution Plan

## Goal
Fix `.swifttag` document loading so the editor still loads the saved tags and pictures as it does today, then immediately compares that saved document state against the current live FLAC files by reusing the existing difference-detection and UI-formatting mechanics, surfaces accurate live differences as if those editor values had been produced through the normal UI, and correctly resolves bookmark-backed files that were modified, moved, or renamed instead of incorrectly showing them as deleted. A top priority is that each editor session maintains valid bookmark data per loaded track and that later `.swifttag` saves write bookmark data that is still resolvable and usable.

## Scope
In scope:
- Compare each loaded `.swifttag` track against the current live FLAC file state immediately after document load.
- Preserve the `.swifttag` contents as the editor baseline while surfacing live FLAC tag and picture differences as external differences.
- Reuse the existing track-to-file difference determination, external-difference state, and status/formatting presentation mechanics instead of inventing a document-only compare path.
- Treat `.swifttag`-loaded track values as normal editor state, so live FLAC differences are handled the same way they would be if a user had produced those current editor values through the UI.
- Fix bookmark-resolution behavior so modified, moved, and renamed FLAC files remain active when the saved bookmark can still resolve them.
- Define and implement fallback ordering when bookmark resolution fails:
- first try the saved bookmark
- then try the saved `FLAC File URL`
- only mark the file as deleted when neither path is usable
- Ensure `.swifttag`-loaded sessions participate in the same ongoing live file-monitor refresh behavior already seen when the same FLAC file is loaded directly in multiple editors.
- Ensure each open editor session maintains its own current valid bookmark data per loaded track and refreshes that state when resolution succeeds on a moved, renamed, or otherwise refreshed file.
- Ensure `.swifttag` save/export verifies or refreshes the bookmark data it writes so saved bookmarks remain valid, resolvable, and usable on later reopen.
- Add substantial automated coverage for document-load comparison, bookmark resolution, rename/move handling, delete fallback, and ongoing live external-difference updates.

Out of scope:
- Changing the `.swifttag` package schema.
- Replacing the existing standard FLAC import flow.
- Converting SwiftTag to `NSDocument` or changing the window architecture.
- Automatically rewriting the `.swifttag` package on disk during load or passive file monitoring.
- Broad redesign of status icon presentation, save notifications, or unrelated editor UI.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/16-AddSwiftTagDocumentRead.md`.
- Relevant prior plans reviewed:
- `Docs/Plans/12-AddFLACDocumentOpenSupport.md`
- `Docs/Plans/15-AddSwiftTagDocumentCreation.md`
- `Docs/Plans/16-AddSwiftTagDocumentRead.md`
- Current implementation files reviewed:
- `SwiftTag/SwiftTag/ContentView.swift`
- `SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
- `SwiftTag/SwiftTag/Shared/Models/EditorSessionModels.swift`
- `SwiftTag/SwiftTag/Shared/Models/Track.swift`
- `SwiftTag/SwiftTag/Shared/Models/TrackStatus.swift`
- `SwiftTag/SwiftTag/Shared/Utilities/SwiftTagDocumentPackage.swift`
- `SwiftTag/SwiftTag/Shared/Utilities/TrackFileMonitor.swift`
- `SwiftTag/SwiftTagTests/SwiftTagDocumentTests.swift`
- `SwiftTag/SwiftTagTests/SwiftTagTests.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Relevant fixtures inspected:
- `SwiftTagTestFiles/test.flac`
- `SwiftTagTestFiles/test-with_padding.flac`
- Existing test helpers already create copied temporary FLAC fixtures and cover rename/delete monitor cases, which should be reused for the new document-read scenarios.
- Constraints accounted for:
- `.swifttag` load already reconstructs editable tracks through `TagEditorViewModel.loadSwiftTagDocument`.
- That load path currently calls `syncCurrentStateAsSaved`, so the saved document becomes the editor/file snapshot baseline before any live FLAC comparison happens.
- `TrackFileMonitor` and `refreshTrackFileState` already support rename-aware refresh for directly imported FLAC tracks, but the `.swifttag` path does not currently force an initial live comparison on load.
- Deleted-state handling currently flows through `handleMissingTrackFileState`, so bookmark failure and true deletion need to be separated carefully.
- Existing track/file difference and formatting behavior already flows through `latestFileSnapshot`, `externalDifferences`, track-status lookups, and existing formatting helpers, so the plan should keep `.swifttag` load aligned with those same seams.
- `.swifttag` export currently serializes whatever `sourceFileURL` and `securityScopedBookmarkData` each track currently holds, so stale per-editor bookmark state would be written back unless the save path validates or refreshes that data first.
- ViewInspector remains the preferred UI/state harness, but bookmark resolution and file monitoring are better covered through unit/service tests with copied fixtures and targeted monitor tests.

## Current Implementation Snapshot
- `SwiftTagDocumentPackageReader` already restores saved `FLAC File URL`, `FLAC File Bookmark`, tags, pictures, and FLAC fingerprint from the package manifest.
- `TagEditorViewModel.loadSwiftTagDocument` already rebuilds editor tracks, marks them with `preservesEditorStateDuringFileRefresh = true`, and remembers the document URL and document ID for later saves.
- `loadSwiftTagDocument` then calls `syncCurrentStateAsSaved`, which currently makes the saved document content the `latestFileSnapshot` and clears `externalDifferences`.
- `ContentView.handleOpenedSwiftTagDocument(_:)` currently loads the document, syncs album art, installs file monitoring, and re-registers the session, but it does not perform an immediate live FLAC comparison before returning control to the editor.
- `TagEditorViewModel.refreshTrackFileState` already:
- accepts file-monitor `currentPath` hints
- falls back to `withAccessingSecurityScopedTrackURL`
- updates `sourceFileURL`, filename tag, and bookmark data when a new resolved path is found
- computes external tag/picture differences against the current editor state
- marks tracks deleted only through `handleMissingTrackFileState`
- Existing UI/status presentation already reads the current track state plus `externalDifferences`, so a reused refresh path can drive the same formatting/help output for `.swifttag`-loaded tracks without a special document-only renderer.
- `TagEditorViewModel.swiftTagDocumentExportTracks()` currently writes each track's in-memory `sourceFileURL` and `securityScopedBookmarkData` directly into the `.swifttag` export payload.
- Existing tests in `SwiftTagTests.swift` already cover rename, multiple rename, rewrite, file-monitor rename, and delete behavior for imported tracks, but not the equivalent `.swifttag` document-load path or initial post-load comparison.

## Confirmed Decisions
- Loading a `.swifttag` document still restores the saved document tags and pictures into the editor first.
- The `.swifttag` contents remain the editor baseline after load; current FLAC contents are shown only as external differences until the user chooses to reload or save.
- A FLAC file changed since document save must not be shown as deleted when its saved bookmark still resolves to the file.
- Modified, moved, and renamed FLAC files are all treated as bookmark-resolvable success cases when the bookmark or fallback file URL leads to a readable file.
- If bookmark resolution fails, SwiftTag should next try the saved `FLAC File URL`.
- Only when both bookmark resolution and saved `FLAC File URL` lookup fail should the UI show the file as deleted.
- When a moved or renamed file is successfully resolved, the editor session should update its in-memory `sourceFileURL`, filename tag, and bookmark data so ongoing monitoring and later save flows follow the resolved file location.
- A successful live refresh for a `.swifttag`-loaded track must preserve the editor’s current document-derived tag and picture state while updating only the external-difference presentation.
- Live file monitoring should behave the same for `.swifttag`-loaded tracks as it already does for directly imported FLAC tracks.
- Initial `.swifttag` live comparison must reuse the same difference-determining mechanisms, `externalDifferences` updates, and UI formatting/status lookups already used for existing editor/file comparison behavior.
- The editor should treat `.swifttag`-loaded values as ordinary current editor values, so loaded-document differences against live FLAC state present the same way user-made UI edits versus live file state already do.
- Each editor window/session owns its own bookmark state for its loaded tracks; successful resolution in one editor should refresh that editor’s in-memory bookmark data rather than assuming another editor instance will keep it current.
- Before saving a `.swifttag` package, SwiftTag must ensure the bookmarks it is about to write are valid/resolvable/usable, refreshing them from the resolved file URL when possible and surfacing a clear failure instead of silently exporting unusable bookmark data.

## Dependencies And Constraints
- The fix should reuse the existing `.swifttag` manifest contract and current `TagEditorViewModel` refresh logic instead of inventing a separate document-only refresh path.
- The fix should route initial `.swifttag` live comparison through the same core difference/update mechanics already used for current editor state versus current file state, so status icons, formatting, and help text do not drift between load-time and later monitor-driven comparisons.
- Initial load comparison and ongoing file-monitor refreshes must agree on the same resolution order and deleted-state rules, or the UI will oscillate between “different” and “deleted.”
- `preservesEditorStateDuringFileRefresh` is currently the key mechanism that lets live file refresh update external-difference state without replacing the document-loaded editor content; the fix should preserve that contract.
- Bookmark success, stale bookmark refresh, saved-URL fallback, and true deletion need an explicit shared resolution seam so tests can cover each branch without relying only on monitor timing.
- Because `.swifttag` load is not destructive, any path or bookmark updates during resolution should stay in memory until a later explicit save writes a new `.swifttag` package.
- Because `.swifttag` export currently writes the track-level bookmark data as-is, the save flow needs an explicit pre-export bookmark validation/refresh step or equivalent guarantee that each exported bookmark is still usable.
- File-monitor timing remains inherently asynchronous, so direct `refreshTrackFileState` tests should cover the core logic and monitor tests should only verify the wiring/on-change path.

## High-Risk Concerns
### Product / Behavioral Risks
- If initial document-load comparison mutates the editor state instead of only setting `externalDifferences`, users could lose the saved document baseline they expected to inspect.
- If fallback ordering is wrong, a temporarily stale bookmark could still surface as `<deleted>` even though the saved URL or refreshed bookmark can resolve the file.
- If move/rename refresh updates the live file path but not the in-memory bookmark and filename state, later monitoring or save/reload flows can drift back to stale paths.
- If initial load comparison uses a bespoke compare/render path instead of the existing difference and formatting mechanics, `.swifttag`-opened editors can present a different status story than directly imported editors for the same underlying file state.
- If deletion detection becomes too permissive, a genuinely missing file could remain shown as active with stale metadata instead of clearly presenting deletion.
- If document-loaded sessions do not reuse the same live refresh path as directly imported tracks, the app will continue to show inconsistent external-change behavior between editor types.
- If each editor session does not refresh and own its own bookmark state, one window can save stale bookmark data even after another window successfully resolved the same moved file.
- If `.swifttag` save writes stale or unresolvable bookmark data, reopen behavior will regress even when the active editor had enough information to repair the bookmark before export.

### Tooling / Environment / Sandbox Risks
- Security-scoped bookmark behavior can differ between direct refresh calls and monitor-driven refresh calls, so tests must cover both deterministic direct refresh and at least one real monitor path.
- File-monitor rename/delete events are timing-sensitive; over-reliance on monitor-only tests would make the plan brittle.
- FLAC fixture mutation tests need temporary copied files so rename, move, and tag rewrite operations do not affect checked-in fixtures.

## Implementation Phases
1. Extract Explicit Live File Resolution Semantics
- Introduce or formalize a shared track-file resolution helper used by both initial document-load comparison and later refreshes.
- Make the helper return enough structured outcome to distinguish:
- resolved via bookmark
- resolved via saved file URL fallback
- resolved after stale bookmark refresh
- missing/unresolvable
- Keep the resolution contract responsible for updating in-memory path/bookmark state only after a usable FLAC file is confirmed.
- Ensure the shared seam plugs back into the existing refresh/difference/update mechanics rather than splitting document-load comparison into a separate state model.

2. Add Immediate Post-Load Live Comparison For SwiftTag Documents
- Extend the `.swifttag` open flow so, after `loadSwiftTagDocument` reconstructs the editor state, SwiftTag immediately refreshes each loaded track against the current FLAC file state.
- Preserve the current document-derived editor content and `latestFileSnapshot` baseline while populating `externalDifferences` from the live FLAC snapshot through the same difference-determining/state-update path already used for normal editor/file comparison.
- Ensure the initial compare runs before or immediately alongside monitor installation so already-modified files show the correct external-difference formatting as soon as the document opens.
- Verify that the resulting UI/status/hover presentation comes from the existing formatting/status mechanics, so a `.swifttag`-loaded difference looks the same as the corresponding live-file difference in a normal editor session.

3. Harden Missing-File Versus Resolved-File Handling
- Refine `refreshTrackFileState` and `handleMissingTrackFileState` so bookmark-resolvable modified/moved/renamed files do not fall through the delete path.
- Apply the saved `FLAC File URL` fallback only after bookmark resolution cannot produce a usable file URL.
- Keep deleted presentation limited to true unresolvable cases where neither bookmark nor saved URL locates the file.
- Confirm filename-tag updates and bookmark refreshes happen for rename/move success cases in `.swifttag`-loaded sessions too, and that each editor instance retains its own repaired bookmark state after those refreshes.

4. Add Save-Time Bookmark Validation For SwiftTag Export
- Add a pre-export validation/refresh step for the track references used by `swiftTagDocumentExportTracks()`.
- Where a track can still be resolved, refresh `sourceFileURL` and `securityScopedBookmarkData` before the `.swifttag` package is written.
- If a bookmark cannot be validated or repaired into a usable exported reference, fail clearly rather than silently saving stale bookmark data.

5. Ensure Live Monitoring Works For SwiftTag-Loaded Sessions
- Re-check the `ContentView.handleOpenedSwiftTagDocument(_:)` and `refreshTrackMonitoring()` sequence so document-loaded sessions install the same observations as imported FLAC sessions.
- Verify that monitor-triggered refreshes continue to honor `preservesEditorStateDuringFileRefresh` and only update external-difference state.
- Confirm that when another editor saves a shared FLAC file, a `.swifttag`-loaded editor reflects the change and later clears the difference again if the file returns to matching state.

6. Expand Automated Coverage Aggressively
- Add direct view-model tests for initial document-load comparison when the underlying FLAC has changed since document save.
- Add explicit bookmark-resolution tests for:
- modified file still resolved by bookmark
- moved file resolved by bookmark
- renamed file resolved by bookmark
- bookmark resolution failure with saved URL fallback success
- bookmark resolution failure with saved URL fallback failure resulting in deleted UI state
- Add save-path tests proving `.swifttag` export refreshes/validates bookmark data before writing and does not persist unusable bookmark state silently.
- Add monitor-driven tests proving `.swifttag`-loaded sessions receive the same live external-difference updates as imported-track sessions.
- Keep XCUI optional unless a lightweight state test cannot validate the editor formatting outcome.

## Test Strategy
Order:
1. Pure unit / view-model tests:
- loading a `.swifttag` document whose FLAC tags changed after document save shows external tag differences immediately
- loading a `.swifttag` document whose FLAC pictures changed after document save shows external picture differences immediately
- when the live FLAC matches the saved document, the loaded track stays clean with no external differences
- modified-file refresh preserves editor state and only updates external-difference presentation
- initial document-load comparison produces the same status/formatting outcome already used by normal editor/file difference presentation
- bookmark-resolved rename updates `sourceFileURL`, filename tag, and bookmark without deleted state
- bookmark-resolved move updates `sourceFileURL`, filename tag, and bookmark without deleted state
- separate editors loaded from the same `.swifttag` or FLAC source maintain independent in-memory bookmark state updates
- true deletion requires both bookmark resolution failure and saved-URL fallback failure
- `.swifttag` save refreshes or validates bookmark data before export and fails clearly when a usable bookmark cannot be produced
2. Service / fixture tests using copied FLAC files:
- save a `.swifttag` package from a copied fixture, mutate FLAC tags afterward, load the package, and verify the editor-facing model shows the expected difference
- repeat that pattern for picture changes when practical with current fixture utilities
- save a `.swifttag` package, rename or move the copied FLAC, load the package, and verify the track resolves to the new location
- save a `.swifttag` package, break bookmark resolution but keep the saved file URL valid, then verify fallback succeeds
- save a `.swifttag` package, remove the copied FLAC entirely, then verify the track is shown as deleted
- save a `.swifttag` package after rename/move repair and verify the exported bookmark resolves to the repaired location on later reopen
3. Targeted monitor tests:
- a `.swifttag`-loaded track receives file-monitor refreshes after an external save to the same FLAC file
- the external-difference indicator appears after the first external change and clears after the file is restored to match the document baseline
- rename monitor events for `.swifttag`-loaded tracks do not transiently mark the file deleted
4. SwiftUI / ViewInspector tests where practical:
- row/file-status presentation for a `.swifttag`-loaded track reflects external difference versus deleted states through existing view-model lookups
- any new state wiring added to `ContentView` remains narrow and assertion-friendly
5. Verification workflow:
- prefer `BuildProject`
- run targeted `RunSomeTests` for `SwiftTagTests` and `SwiftTagDocumentTests`
- reserve broader UI or full-suite runs only if targeted coverage leaves a gap

## Acceptance Criteria
- Opening a `.swifttag` document still restores the saved document tags and pictures into the editor.
- Immediately after open, SwiftTag compares each loaded track to the current live FLAC file state and updates the editor UI accordingly.
- If the live FLAC tags or pictures changed since the document was saved, the editor shows those changes as external differences instead of keeping the track falsely clean.
- The load-time compare and resulting UI/status/formatting behavior reuse the same difference-determining and presentation mechanics already used for current editor state versus live file state.
- If the associated FLAC file was modified, moved, or renamed, and the saved bookmark still resolves it, the editor does not show the track as deleted.
- If bookmark resolution fails but the saved `FLAC File URL` still points to a usable FLAC file, the editor uses that fallback and does not show the track as deleted.
- Only when both bookmark resolution and saved-file-URL fallback fail does the UI show the file as deleted.
- Successful move/rename resolution updates the in-memory track path, filename, and bookmark for that editor session so later monitoring and save flows keep working.
- Saving a `.swifttag` document writes bookmark data that has been validated or refreshed into a resolvable, usable form, or it fails clearly instead of silently exporting stale bookmark data.
- A `.swifttag`-loaded editor responds to ongoing underlying FLAC changes the same way a directly imported editor already does, including clearing the external-difference formatting when the live file returns to matching state.
- Automated tests cover the modified, moved, renamed, fallback-success, fallback-failure, and ongoing live-update scenarios with enough depth for implementation sign-off.

## Open Questions
- None currently.
