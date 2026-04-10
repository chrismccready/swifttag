# Add Referenced SwiftTag Document Track-List Save Offer Plan

## Goal
Offer saving the referenced `.swifttag` document when the current session's track list has diverged from the referenced document's track list because tracks were added or removed, even when there are no FLAC tag or picture differences.

The intended result is:
- when a window references a `.swifttag` document and the current track list no longer matches the referenced document's saved track list, the document-backed window title shows the referenced document name followed by `*`
- this track-list-difference behavior is independent of the `saveReferencedSwiftTagDocument` and `askToSaveNewSwiftTagDocument` settings
- this track-list-difference behavior ignores tag-only and picture-only differences when deciding whether the referenced document needs attention
- when the user closes a window with a referenced-document track-list difference, the app offers:
  - `Save <referenced .swifttag document name>`
  - `Close Window`
  - `Cancel`
- when the app quits and a window has a referenced-document track-list difference, the app offers:
  - `Save <referenced .swifttag document name>`
  - `Quit`
  - `Cancel`
- if the user saves the referenced document from that close or quit flow, the current session is serialized to the existing referenced `.swifttag` document and the window then closes or the quit flow continues

## Scope
In scope:
- Detect whether the referenced `.swifttag` document's saved track list differs from the current session's track list because tracks were added or removed.
- Surface a document-dirty marker in the navigation title for that specific track-list-difference state.
- Extend window-close and app-quit prompting so a referenced-document track-list difference can block destructive close/quit in the same way unsaved session state already can.
- Reuse the existing referenced-document save helper for the close-triggered and quit-triggered `Save <document>` action.
- Refresh the referenced-document track-list baseline after a successful save or document load.
- Add targeted automated coverage for track-list-difference derivation, title-marker derivation, and close/quit option resolution.

Out of scope:
- Changing `⌘S` behavior or any follow-on save behavior covered by `Docs/Plans/19-AddSwiftTagDocumentSaveOptions.md` and `Docs/Plans/20-AddSwiftTagDocumentSaveOptions.md`.
- Treating tag or picture differences as part of this new referenced-document diff rule.
- Redesigning the broader unsaved FLAC save-option set beyond whatever combination behavior is required when both kinds of dirty state exist.
- Changing the `.swifttag` package format.
- Adding autosave for referenced `.swifttag` documents.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed:
  - `Docs/Plans/21-AddSwiftTagDocumentBookmark.md`
- Relevant prior plans reviewed:
  - `Docs/Plans/20-AddSwiftTagDocumentSaveOptions.md`
  - `Docs/Plans/18-UpdateWindowTitleText.md`
- Current implementation files reviewed:
  - `SwiftTag/ContentView.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/Shared/Utilities/UnsavedChangesFlow.swift`
  - `SwiftTag/Shared/Utilities/UnsavedChangesCoordinator.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackage.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentMonitor.swift`
  - `SwiftTag/Shared/Models/EditorSessionModels.swift`
  - `SwiftTag/Shared/Models/Track.swift`
  - `SwiftTagTests/SwiftTagDocumentTests.swift`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
- Relevant fixtures inspected:
  - none required for the initial planning pass; this feature can be verified primarily through pure state tests and temporary `.swifttag` packages rather than FLAC writeback fixtures
- Constraints accounted for:
  - `UnsavedChangesChoiceResolver.resolve(...)` currently prompts only when tag or picture edit counts are non-zero.
  - `UnsavedChangesSessionContext` currently exposes only edit counts plus referenced-document presence and URL; it cannot yet express referenced-document track-list divergence.
  - `ContentView.currentUnsavedChangesSessionContext()` derives its close/quit state only from `currentUnsavedEditCountsForLoadedTracks()` and the remembered save state.
  - `TagEditorViewModel.editorNavigationMetadata(...)` currently derives a document-backed title and deleted-document title, but it has no non-deleted dirty-marker concept for referenced-document divergence.
  - `ContentView` already observes `TrackSetFingerprint.make(from: viewModel.importedTrackReferences)` and re-registers the session whenever the current imported track membership changes.
  - the codebase already has a normalized path fingerprint helper in `TrackSetFingerprint`, which is a likely candidate for a membership-only track-list comparison if path membership is the intended source of truth.
  - `windowShouldClose(_:)` and `applicationShouldTerminate(_:)` are synchronous entry points, so any new referenced-document save action must continue to run through the existing deferred close/quit orchestration.
  - the referenced `.swifttag` document can already be deleted or moved externally, so any close-time `Save <document>` action must compose with the bookmark-backed associated-document state rather than assuming a simple writable live path.

## Current Implementation Snapshot
- `SwiftTagDocumentSaveState` already tracks:
  - referenced document URL
  - document ID
  - security-scoped bookmark data
  - last known display name
  - availability (`available` or `deleted`)
- `TagEditorViewModel.editorNavigationTitle(documentState:)` already shows:
  - the referenced document name when a referenced document exists
  - `<name> (deleted)` when the referenced document has been deleted
  - album-based fallback titles when no referenced document name is present
- `ContentView.navigationMetadata` is already sourced from `TagEditorViewModel.editorNavigationMetadata(...)`, so the title marker can be added through that existing derivation seam.
- `TagEditorViewModel.importedTrackReferences` exposes the current imported FLAC membership as `[ImportedTrackReference]`.
- `TrackSetFingerprint.make(from:)` already produces a stable, sorted membership fingerprint from imported file paths.
- `ContentView` already reacts to track-membership changes through `.onChange(of: TrackSetFingerprint.make(from: viewModel.importedTrackReferences))`.
- `UnsavedChangesCoordinator` already owns the deferred window-close and app-quit flow and can already run a referenced-document save action asynchronously before allowing the final close or quit.
- `UnsavedChangesChoiceResolver` currently supports only:
  - `Save FLAC files`
  - `Save <referenced .swifttag document>`
  - `Save FLAC files & <referenced .swifttag document>`
  - `Save New SwiftTag Document...`
  - `Save FLAC files & New SwiftTag Document...`
- `performSwiftTagDocumentSave(using:)` already supports remembered-document save, prompt-for-new-document save, and deleted-document recovery prompting.
- no current model stores the referenced document's last saved track-list baseline separately from the current session's imported-track membership, so the requested dirty check has no dedicated source of truth yet.

## Confirmed Decisions
- This feature is independent of the `saveReferencedSwiftTagDocument` and `askToSaveNewSwiftTagDocument` settings.
- The new diff check is about referenced-document track-list divergence caused by tracks being added or removed.
- Tag differences and picture differences are not relevant to this diff check.
- Track order changes also count as referenced-document track-list divergence.
- Tracks without a source FLAC file path still participate in the referenced-document track-list diff.
- When the referenced-document track list differs from the current track list, the window navigation title should show `*` after the document name.
- At window close time, the user should be offered `Save <referenced .swifttag document name>`, `Close Window`, or `Cancel`.
- At app-close or app-quit time, the user should be offered an equivalent prompt that preserves the destructive action label for the quit flow.
- When FLAC tag or picture unsaved changes also exist, this new feature should use the existing implemented code path for that mixed-dirty-state case rather than inventing a second combination flow in this plan.
- If the referenced document is deleted or unavailable at close time and the user chooses `Save <document>`, the existing deleted-document recovery flow should be reused.

## Dependencies And Constraints
- The implementation should add one explicit source of truth for referenced-document track-list divergence rather than recalculating loosely in multiple places.
- That source of truth likely needs to store both:
  - the referenced document's last accepted track-list fingerprint
  - the current session's comparable track-list fingerprint or a derivable equivalent
- The most natural update points for the referenced-document baseline are:
  - after loading a `.swifttag` document
  - after successfully saving to the referenced `.swifttag` document
- The current track-list fingerprint likely belongs near `TagEditorViewModel.importedTrackReferences` because that already models current imported FLAC membership and already drives window session registration.
- The close-flow resolver must be able to prompt even when tag edit counts and picture edit counts are both zero.
- The title dirty marker must apply only when the current title is document-backed; album-based titles should not start showing a stray `*` when no referenced document exists.
- The user-facing document label should continue to come from the existing remembered associated-document display name rather than inventing a second naming path.
- Because `performSwiftTagDocumentSave(using: .rememberedOnly)` already routes deleted documents through the deleted-document recovery branch, the close-time `Save <document>` action should reuse that path rather than forking a second recovery flow.
- Because order changes count and non-file-backed tracks participate, the current path-sorted `TrackSetFingerprint` helper is insufficient as the sole source of truth for this feature.
- The implementation therefore needs a richer ordered baseline model that can represent both:
  - file-backed tracks
  - non-file-backed session tracks
- The mixed-dirty-state path should defer to the existing implemented unsaved-changes flow when FLAC tag or picture edits are already present, so this plan should focus on the track-list-diff-only branch plus the shared dirty-state derivation seam.

## Write-Back Behavior
- Preserved data:
  - tag and picture edit detection remain the source of truth for FLAC unsaved-change prompts
  - referenced-document save continues to serialize the full current editor session to the referenced `.swifttag` package
  - referenced-document delete and recovery behavior remains handled by the existing remembered document save path
- Replaced data:
  - a successful close-triggered or quit-triggered `Save <document>` action updates the referenced document's saved track-list baseline to match the current session
- Removed data:
  - after a successful referenced-document save, the stale pre-save track-list-difference state should be cleared so the title marker and close prompt no longer appear
- Selection semantics:
  - the new referenced-document diff check is session-wide and should not depend on the current table selection

## High-Risk Concerns
### Product / Behavioral Risks
- If the track-list baseline is captured at the wrong times, the title can show a stale `*` even immediately after saving or loading the referenced document.
- If track membership is derived from the wrong identity signal, rename, move, or deleted-file repair flows can create false positive or false negative track-list differences.
- Because track order changes and non-file-backed tracks count, any identity model that collapses to a sorted path set will under-report required differences.
- If the close prompt label does not stay aligned with the existing referenced document name, the user can be offered the wrong save target.

### Tooling / Environment / Sandbox Risks
- Close and quit flows already bridge synchronous AppKit delegate callbacks into async save work, so this feature must compose with the existing deferred orchestration instead of introducing a second independent modal path.
- The referenced `.swifttag` document may be security-scoped or deleted, so a close-triggered save can still surface save-panel or recovery prompts.
- UI-level verification of close prompts can be timing-sensitive; prefer pure resolver tests and narrow orchestration tests before heavier integration coverage.

## Implementation Phases
1. Introduce Referenced-Document Track-List Baseline State
- Add a small state model that records the referenced document's accepted track-list baseline whenever the app:
  - loads a `.swifttag` document
  - successfully saves the referenced `.swifttag` document
- Derive a comparable current-session ordered track-list representation from current session tracks, not only imported-file references.
- Ensure the baseline can represent both file-backed and non-file-backed tracks in stable order.
- Keep the derivation pure and testable so the dirty decision is not embedded inside view or coordinator code.

2. Derive Referenced-Document Track-List Dirty State
- Add a pure helper that answers whether the referenced document is currently dirty because of track additions or removals.
- Wire that helper so it ignores tag and picture differences entirely.
- Compare the current ordered track-list state against the remembered referenced-document ordered baseline.
- Ensure that both:
  - order-only changes
  - non-file-backed-track additions or removals
  mark the referenced document as dirty.
- Ensure the dirty state clears immediately after successful referenced-document save or document load.

3. Surface The Dirty Marker In Navigation Metadata
- Extend `TagEditorViewModel.editorNavigationMetadata(...)` or an adjacent helper so a document-backed title becomes `<document name>*` when the referenced-document track list is dirty.
- Preserve the existing deleted-document formatting, with a clear rule for how `*` interacts with `(deleted)` if both states can coexist.
- Keep album-based fallback titles unchanged when there is no referenced document.

4. Extend Close And Quit Prompt Resolution
- Expand `UnsavedChangesSessionContext` so it can express referenced-document track-list divergence in addition to FLAC tag/picture edit counts.
- Extend `UnsavedChangesChoiceResolver` so it can produce a close or quit prompt when the only dirty reason is referenced-document track-list divergence.
- Add a focused option set for that state:
  - `Save <referenced .swifttag document name>`
  - destructive close or quit action
  - `Cancel`
- Keep this branch independent from the command-s follow-on save settings.
- Preserve the existing implemented code path when both FLAC unsaved edits and referenced-document track-list divergence are present.

5. Reuse Existing Referenced-Document Save Flow
- Route the new close-triggered and quit-triggered `Save <document>` action through `performSwiftTagDocumentSave(using: .rememberedOnly)`.
- Preserve existing cancellation and failure handling:
  - canceled save-panel or deleted-document recovery leaves the window open and aborts quit
  - failed referenced-document save leaves the window open and aborts quit
- After successful save, refresh the remembered track-list baseline before allowing close or quit to complete.

6. Add Targeted Automated Coverage
- Add pure unit tests for track-list baseline derivation and dirty-state resolution.
- Add navigation-metadata tests covering document-backed title marker behavior.
- Add close/quit resolver tests covering the new prompt configuration when referenced-document track-list divergence exists.
- Add targeted orchestration tests confirming successful save clears the dirty state and allows close or quit to continue.
- Add heavier UI coverage only if pure and coordinator-level tests cannot credibly verify the final prompt behavior.

## Test Strategy
Order:
1. Pure unit tests:
  - referenced document present plus matching track-list baseline does not produce the `*` marker
  - referenced document present plus added track produces the dirty state and `*` marker
  - referenced document present plus removed track produces the dirty state and `*` marker
- referenced document present plus order-only change produces the dirty state and `*` marker
- referenced document present plus non-file-backed-track addition produces the dirty state and `*` marker
  - tag-only and picture-only differences do not produce referenced-document track-list dirty state
  - no referenced document means no referenced-document track-list prompt or marker
  - referenced-document track-list dirty state alone resolves to the three-button close option set
  - referenced-document track-list dirty state alone resolves to the three-button quit option set
2. Service or state tests where practical:
  - loading a `.swifttag` document captures the baseline track-list fingerprint
  - successful referenced-document save refreshes the baseline fingerprint
  - current imported-track membership changes update the dirty-state derivation without requiring a save
3. Targeted orchestration tests:
  - choosing `Save <document>` from the close flow saves the referenced document and then allows the close
  - choosing `Save <document>` from the quit flow saves the referenced document and then allows termination to continue
  - canceling the referenced-document save path keeps the window open and aborts app quit
  - failed referenced-document save keeps the window open and aborts app quit
4. Verification workflow:
  - prefer pure and coordinator-level tests first
  - prefer temporary `.swifttag` package tests over full XCUI when possible
  - run targeted build and targeted tests rather than the full suite unless explicitly requested

## Acceptance Criteria
- A session with no referenced `.swifttag` document does not show the new title marker and does not gain the new prompt behavior.
- A session with a referenced `.swifttag` document and no track additions or removals does not show the new title marker.
- A session with a referenced `.swifttag` document and a current track list that differs because tracks were added or removed shows `*` after the referenced document name in the navigation title.
- A session with a referenced `.swifttag` document and the same tracks in a different order shows `*` after the referenced document name in the navigation title.
- A session with a referenced `.swifttag` document and an added or removed non-file-backed track shows `*` after the referenced document name in the navigation title.
- Tag-only differences do not trigger the new title marker by themselves.
- Picture-only differences do not trigger the new title marker by themselves.
- Closing a window whose only relevant dirty state is referenced-document track-list divergence offers `Save <referenced .swifttag document name>`, the destructive close action, and `Cancel`.
- Quitting the app when a window's only relevant dirty state is referenced-document track-list divergence offers the equivalent save, destructive quit, and cancel actions.
- Choosing `Save <referenced .swifttag document name>` from that prompt saves to the existing referenced document regardless of the `saveReferencedSwiftTagDocument` and `askToSaveNewSwiftTagDocument` settings.
- If the referenced document is deleted or unavailable when that save action is chosen, the existing deleted-document recovery flow is reused.
- When FLAC tag or picture unsaved changes are also present, the existing implemented mixed-dirty-state code path remains the governing close or quit flow.
- After a successful referenced-document save from the close or quit flow, the track-list dirty marker clears and the close or quit action proceeds.
- Canceling or failing the referenced-document save path leaves the window open and aborts app quit.
- Automated tests cover the derivation seam, title marker, and close or quit prompt resolution sufficiently for implementation sign-off.

## Open Questions
- None currently.