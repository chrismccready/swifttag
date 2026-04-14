# Add Picture Description Edit Plan

## Goal
Add album-art picture description editing so the album-art browser can edit the current picture reference description from a new `Edit Description...` context-menu action, reject oversized description saves with an alert while preserving the user's staged text, and treat description-only changes as picture metadata edits throughout SwiftTag's diff/save flows.

## Scope
In scope:
- Add a divider plus a bottom context-menu item labeled `Edit Description...` to the current picture well in `AlbumArtSheetView`.
- Add a child sheet titled `Picture Description` centered on the existing album-art sheet.
- Show the current/original picture description above a multiline editable description field.
- Allow empty descriptions.
- Guard the edited description against exceeding the FLAC picture metadata block budget based on:
  - FLAC picture block max payload size
  - embedded image byte count
  - MIME-type byte count
  - required fixed-width picture metadata fields
  - an additional 256-byte safety buffer
- When `Save` is attempted with an oversized description, keep the sheet open, preserve the staged text, and show an alert with a single `Ok` button.
- Persist the edited description through the existing picture save/write path.
- Add targeted tests proving description-only edits count as `Picture` edits rather than tag edits.

Out of scope:
- Editing picture MIME type, FLAC picture type, or image bytes.
- Adding a reusable metadata inspector for all picture properties.
- Redesigning the album-art browser layout beyond the requested description editor sheet.
- Changing `.swifttag` document format, because picture descriptions are already persisted there.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed:
  - `Docs/Plans/24-AddTrackDurationInfo.md`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
- Relevant implementation files reviewed:
  - `SwiftTag/Features/AlbumArt/AlbumArtSheetView.swift`
  - `SwiftTag/Features/AlbumArt/AlbumArtViewModel.swift`
  - `SwiftTag/Features/AlbumArt/AlbumArtTypes.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/Shared/Models/FlacPictureModels.swift`
  - `SwiftTag/Shared/Models/Track.swift`
  - `SwiftTag/Shared/Models/TrackStatus.swift`
  - `SwiftTag/Shared/Utilities/FlacPictureUtilities.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentSupport.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackageManifest.swift`
  - `SwiftTag/FlacMetadataService.swift`
  - `SwiftTag/ContentView.swift`
  - `SwiftTagTests/SwiftTagTests.swift`
  - `SwiftTagTests/TrackStatusViewInspectorTests.swift`
  - `SwiftTagTests/SwiftTagDocumentTests.swift`
- Relevant fixtures inspected:
  - `SwiftTagTestFiles/test.flac`
  - `SwiftTagTestFiles/test-with_padding.flac`
- Constraints accounted for:
  - FLAC read/write already preserves picture descriptions end-to-end through `FlacMetadataService`, the C bridge, `FlacWritablePictureRecord`, and the document manifest.
  - `AlbumArtTrackReference` stores `description` per track reference, while pooled image bytes live separately in `AlbumArtPoolItem`.
  - `AlbumArtViewModel.uniquePresentationReferences` currently collapses visible pictures by `poolItemID` only, even though reference identity also includes slot, MIME type, and description.
  - `TagEditorViewModel.pictureRecordsDiffer` already compares canonicalized `FlacWritablePictureRecord` arrays, and that canonicalization includes `description`, so description edits should already be capable of surfacing as picture differences once the editor updates the underlying picture records.
  - The current app has no existing nested album-art child-sheet pattern to copy directly, so centering/attachment behavior may need lightweight AppKit verification during implementation.

## Current Implementation Snapshot
- `AlbumArtSheetView` currently exposes import/export/copy/paste actions in the picture well context menu, but it has no picture-metadata editing action.
- The album-art sheet currently shows description text only as part of the compact metadata summary below the well.
- `AlbumArtViewModel.flacPictures(for:albumArtTypes:)` builds per-track `FlacWritablePictureRecord` values from `AlbumArtTrackReference.description`, MIME type, slot, and pooled bytes.
- `TagEditorViewModel` picture change accounting flows through:
  - `editorDifferenceCounts(...)`
  - `differenceCounts(...)`
  - `hasDifferences(...)`
  - `pictureRecordsDiffer(currentPictures:snapshot:)`
- `ContentView.currentAlbumArtPictures` already uses `albumArtViewModel.flacPictures(albumArtTypes:)` as the picture source of truth for save/diff/status paths.
- `.swifttag` manifests already persist per-picture `Description`, so this feature is about editor UX and runtime save/diff behavior rather than document-schema expansion.

## Confirmed Decisions
- The picture well context menu gains a bottom `Divider()` followed by `Edit Description...`.
- The child editor sheet title is `Picture Description`.
- The sheet contains:
  - a read-only original-description label using the currently displayed picture reference
  - a multiline editable description field for the replacement description
  - `Cancel` and `Save` actions
- Empty-string descriptions are valid and must be saveable.
- Description-size validation must use byte counts, not Swift character counts.
- `Save` updates every matching in-scope reference for the current slot/picture representation, not just one underlying track reference.
- The 256-byte safety buffer applies against the FLAC picture metadata payload budget only, not the outer 4-byte metadata-block header.
- If the proposed description is too large, `Save` is rejected, the entered text remains in the text editor unchanged, the edit sheet stays open, and the app shows an alert with a single `Ok` button.
- Description-only edits must be treated as picture edits, not tag edits.

## Dependencies And Constraints
- The size guard should be implemented as a reusable helper that works from the exact picture payload the app will write, rather than duplicating ad hoc math in the view layer.
- The helper should budget against UTF-8 byte counts for both MIME type and description, because FLAC picture metadata stores those fields as byte-length-prefixed strings.
- The helper should account for the fixed-width FLAC picture metadata fields:
  - type
  - MIME length
  - description length
  - width
  - height
  - depth
  - colors
  - picture-data length
- The editor should mutate every matching in-scope per-reference description while leaving pooled image bytes untouched.
- Save behavior should remain aligned with current payload choices:
  - picture-only save persists description edits
  - tag-only save does not persist description edits
  - combined save persists them
- Because the visible album-art browser can collapse multiple references with identical bytes into one presented picture, the implementation must resolve the current representative picture into every matching in-scope reference before applying the edited description.

## Destructive / Write-Back Behavior
- Preserved data:
  - picture bytes, MIME type, FLAC picture type, and computed image specifications remain unchanged when only the description is edited
  - tags remain unchanged when only the description is edited
  - `.swifttag` document description persistence remains unchanged
- Replaced data:
  - the edited picture reference description on the affected in-memory reference set
  - the corresponding FLAC PICTURE block description field on the next picture save/write for affected tracks
- Removed data:
  - none; saving an empty description writes an empty description rather than removing the picture
- Partial-save behavior:
  - `Save Pictures` and combined FLAC saves must include description-only edits
  - `Save Tags` must not write description-only edits
- Selection/source-of-truth semantics:
  - saving the description updates every matching in-scope reference represented by the currently displayed picture in the active slot

## High-Risk Concerns
### Product / Behavioral Risks
- If the edit applies to only the currently presented representative reference while multiple in-scope tracks share the same pooled image, users may see inconsistent descriptions that the current browser cannot distinguish clearly.
- If the browser continues deduplicating by pooled image bytes only, different descriptions for the same bytes can remain visually collapsed, which may make the result of editing ambiguous unless the target scope is explicit.
- If the input guard uses character count instead of UTF-8 byte count, multi-byte text can still overflow FLAC's legal picture metadata size.
- If save-time validation does not preserve the user's staged text exactly, the alert flow will feel destructive and conflict with the confirmed behavior.
- If the alert is presented from the wrong window context, the nested sheet flow may become confusing or fail to stay centered over the album-art sheet.

### Tooling / Environment / Filesystem Risks
- Nested macOS sheet presentation from an already sheet-backed album-art browser may need AppKit-level verification to ensure the child sheet is attached and centered as expected.
- ViewInspector support for context menus and sheets is limited, so some assertions may need to remain source-based or use actual-view state seams rather than deep hierarchy traversal.
- The FLAC bridge already rejects illegal picture blocks, so any UI-side budget helper must stay consistent with libFLAC legality checks to avoid off-by-one regressions.

## Implementation Phases
1. Define Description Edit Scope And Budget Helper
- Add a dedicated helper for FLAC picture description budgeting, for example `FlacPictureDescriptionBudget` or an `AlbumArtViewModel`-owned helper, that computes:
  - maximum allowed description bytes for a specific picture reference
  - current edited description UTF-8 byte count
  - whether the pending value is legal after subtracting image bytes, MIME bytes, fixed metadata-field bytes, and the extra 256-byte safety buffer from the FLAC metadata payload limit
- Use the actual current picture reference MIME type and pooled image bytes as inputs.
- Resolve the write target for a description edit by collecting every matching in-scope reference represented by the current displayed picture.

2. Add Album-Art Sheet Presentation State
- Extend `AlbumArtSheetView` with the state/bindings needed to:
  - open the picture-description child sheet from the current picture context menu
  - populate original-description text from `metadataForSlot` or a richer view-model seam
  - stage editable description text separately from the committed reference description
  - validate the staged description on `Save`
  - show an `Ok`-only alert when the staged description exceeds the computed budget while keeping the sheet open and preserving the staged text
- Prefer SwiftUI `Text` plus `TextEditor` unless implementation proves a wrapped AppKit text view is necessary for the requested behavior.
- Keep the new action at the bottom of the existing image well context menu after a divider.

3. Add AlbumArtViewModel Description Editing APIs
- Add focused APIs to `AlbumArtViewModel` for the current picture reference, for example:
  - current/original description for a slot
  - maximum description byte allowance for the currently displayed reference
  - apply edited description to every matching in-scope target reference
- When saving a description edit:
  - update only reference metadata, not pooled image data
  - preserve MIME type and slot ordering
  - refresh the compact metadata display under the image well immediately
  - preserve navigation position on the currently displayed picture when possible
- Ensure the updated references still flow through `flacPictures(albumArtTypes:)` and `flacPictures(for:albumArtTypes:)` without requiring fallback recomputation.

4. Keep Diff/Save Accounting Explicitly Picture-Scoped
- Verify the current `TagEditorViewModel` diff path continues to classify description changes as picture differences via `pictureRecordsDiffer(...)` and `differenceCounts(...)`.
- If any path bypasses per-track picture records and accidentally loses the edited description, harden that path so `ContentView.currentAlbumArtPictures` and per-track picture payloads stay in sync.
- Confirm picture-only save continues to write description edits by way of `FlacMetadataService.writeMetadata(..., writePictures: true)`.
- Confirm tag-only save does not persist description-only edits.

5. Add Tests In Harness Order
- Pure/unit tests:
  - description budget helper computes the remaining UTF-8 byte allowance from image bytes, MIME bytes, fixed metadata bytes, and the 256-byte buffer
  - empty-string descriptions remain legal when the fixed fields plus image still fit
  - oversized save attempts are rejected according to the chosen interaction rule without mutating the staged text
- Album-art model tests in `SwiftTagTests.swift`:
  - applying a description-only change updates the relevant `AlbumArtTrackReference` description while leaving image bytes unchanged
  - `albumArtViewModel.flacPictures(for:albumArtTypes:)` emits the new description
  - if the chosen scope spans multiple references, all intended references update and no out-of-scope references do
- Diff/save regression tests in `SwiftTagTests.swift` and, if needed, `SwiftTagDocumentTests.swift`:
  - a description-only change increments `pictureEdits` but not `tagEdits`
  - `hasDifferences(...)` returns true for description-only picture edits
  - navigation/status subtitle reflects `Picture Δ` only for a description-only change
  - picture-only save writes the changed description to a copied FLAC fixture and read-back confirms it
  - tag-only save leaves the FLAC picture description unchanged
- UI/source assertions in `TrackStatusViewInspectorTests.swift` or a sibling test file:
  - `AlbumArtSheetView.swift` declares `Edit Description...` after a divider in the context menu
  - the source declares the `Picture Description` child sheet
  - the sheet contains original-description text, editable multiline text input, and `Cancel` / `Save` actions
  - the source declares the oversize-validation alert with a single `Ok` button

6. Verification Workflow
- Refresh diagnostics for touched Swift files.
- Build the project.
- Run targeted tests first:
  - `SwiftTagTests` cases covering album-art description editing and picture diff counts
  - `TrackStatusViewInspectorTests` source/assertion coverage for the new menu item and sheet
  - any targeted document/save regression tests added for picture-only vs tag-only persistence
- Manual verification on macOS:
  - open the album-art browser
  - invoke `Edit Description...`
  - confirm the child sheet appears attached to and centered over the album-art sheet
  - confirm empty string saves successfully
  - confirm oversized input cannot be committed
  - confirm the navigation subtitle changes `Picture Δ` without introducing a tag delta

## Acceptance Criteria
- The album-art picture well context menu ends with a divider followed by `Edit Description...`.
- Invoking that action presents a child sheet titled `Picture Description` centered on the album-art sheet.
- The sheet shows the original description and a multiline editable description field.
- `Cancel` dismisses without mutating picture metadata.
- `Save` commits the edited description to the intended picture reference scope.
- Empty descriptions are allowed.
- If `Save` is attempted with an oversized description, the sheet stays open, the staged text remains unchanged, and the app shows an `Ok`-only alert instead of truncating or auto-rewriting the text.
- The committed description scope updates every matching in-scope reference represented by the currently displayed picture.
- The size guard uses the legal FLAC picture metadata payload budget once image bytes, fixed fields, MIME bytes, and the extra 256-byte buffer are accounted for.
- Description-only edits leave image bytes and tags unchanged.
- Description-only edits are counted as `Picture` edits, not tag edits, in unsaved-difference accounting.
- `Save Pictures` persists description-only edits to FLAC files.
- `Save Tags` does not persist description-only edits.

## Open Questions
- None currently.