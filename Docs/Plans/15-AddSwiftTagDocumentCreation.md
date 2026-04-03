# Add SwiftTag Document Creation Plan

## Goal
Add creation and save/export support for SwiftTag package documents so the frontmost editor window can save its current session into a `.swifttag` file package containing a root `Info.plist` manifest plus a `Pictures` folder of deduplicated JPEG/PNG assets.

## Scope
In scope:
- Register a SwiftTag document type for the `.swifttag` extension with the `SwiftTagNamedDoc` icon and `LSTypeIsPackage = true`.
- Add a File menu command titled `Save SwiftTag Document...` immediately after the existing save-item group.
- Route the new command from the frontmost editor window through the existing focused-scene command system.
- Present a save dialog for choosing the destination `.swifttag` package path.
- Serialize the frontmost editor session into a file package with:
- root `Info.plist`
- root `Pictures/` directory
- document `Id`
- document `Version` starting at `1.0.0`
- document `Fingerprint`
- per-track dictionaries containing track fingerprint, FLAC file URL, FLAC bookmark, FLAC fingerprint, tags, and picture references
- Write image assets using the editor’s deduplicated picture pool semantics so tracks refer to shared image files instead of embedding duplicate image bytes.
- Add targeted tests for package serialization, hashing/reference stability, menu wiring, remembered document state, and package writing.

Out of scope:
- Opening `.swifttag` documents back into the app.
- Making SwiftTag an `NSDocument`-based or document-scene-based app.
- Changing FLAC save/write behavior for `.flac` files.
- Syncing or auto-updating a previously saved `.swifttag` package after the editor changes unless explicitly added later.
- Supporting image formats beyond JPEG and PNG for package image assets.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/14-AddCompilationTag.md`.
- Relevant prior plans reviewed:
- `Docs/Plans/12-AddFLACDocumentOpenSupport.md`
- `Docs/Plans/13-AddFLACFingerprintSupport.md`
- Current implementation files reviewed:
- `SwiftTag/SwiftTag/SwiftTagApp.swift`
- `SwiftTag/SwiftTag/ContentView.swift`
- `SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
- `SwiftTag/SwiftTag/Features/AlbumArt/AlbumArtViewModel.swift`
- `SwiftTag/SwiftTag/Features/AlbumArt/AlbumArtTypes.swift`
- `SwiftTag/SwiftTag/Features/FlacImport/FlacImportMapper.swift`
- `SwiftTag/SwiftTag/Features/FlacImport/FlacWriteMapper.swift`
- `SwiftTag/SwiftTag/Shared/Models/EditorSessionModels.swift`
- `SwiftTag/SwiftTag/Shared/Models/Track.swift`
- `SwiftTag/SwiftTag/Shared/Utilities/EditorWindowCoordinator.swift`
- `SwiftTag/SwiftTag/Info.plist`
- `SwiftTag/SwiftTagUITests/SwiftTagUITests.swift`
- `SwiftTag/SwiftTagTests/SwiftTagTests.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Relevant fixtures inspected:
- `SwiftTagTestFiles/test.flac`
- `SwiftTagTestFiles/test-with_padding.flac`
- Constraints accounted for:
- The app currently uses `WindowGroup` plus focused-scene commands rather than `DocumentGroup` or `NSDocument`.
- The existing File menu save commands operate on imported FLAC tracks only and do not maintain a current SwiftTag document URL for editor sessions.
- The new feature needs per-session remembered `.swifttag` document URL state and remembered document `Id` state once a package is first written.
- `Track` already carries security-scoped bookmark data and FLAC audio fingerprint data, which are likely the correct source inputs for the new package manifest.
- `AlbumArtViewModel` already maintains a deduplicated picture pool keyed by SHA-256 of image bytes, but pool entries are identified in-memory by UUID and per-track references carry slot, MIME type, and description metadata that are not yet serialized for a SwiftTag package.
- The current Swift-side picture models do not yet expose width, height, depth, or colors fields, so the plan must account for where those values will come from during export and save-difference detection.
- Existing save verification is split across unit tests, fixture-based service tests, and narrow XCUI menu assertions; save-panel interaction remains a likely XCUI-only seam.

## Current Implementation Snapshot
- `SwiftTagApp` replaces the standard save menu group with custom `Save`, `Save Tags`, and `Save Pictures` items, so the new command should be added in that command definition instead of relying on default document commands.
- `ContentView` exposes save/menu behavior through `FocusedValues`, making it the current source of truth for frontmost-editor command routing.
- `TagEditorViewModel` already exposes imported track references, per-track security-scoped bookmarks, per-track FLAC audio fingerprints, and file snapshots, but it does not currently provide a session-export snapshot, remembered `.swifttag` document state, or package-writing API.
- `AlbumArtViewModel` deduplicates image bytes with `SHA256.hash(data:)`, keeps pool items in memory, and preserves per-track reference metadata separately from pooled bytes.
- `Info.plist` currently registers only `.flac` as a document type.
- The project already has XCUI coverage that asserts File menu items and launches fixture-backed editors, which is a useful seam for validating that the new command is present and enabled in the intended contexts.

## Confirmed Decisions
- The SwiftTag document extension is `.swifttag`.
- The SwiftTag document uses the `SwiftTagNamedDoc` asset as its document icon.
- The SwiftTag document is a file package, so its document registration must set `LSTypeIsPackage` to `true`.
- The file package contents are:
- root `Info.plist`
- root `Pictures/` folder
- `Info.plist` includes:
- `Id`
- `Version`
- `Fingerprint`
- `Tracks`
- `Id` is a UUID for the document.
- A newly created `.swifttag` document gets a new UUID on first save.
- Once written to a document, that document `Id` does not change on later saves to the same remembered document URL.
- `Version` starts at `1.0.0`.
- `Fingerprint` is a hash of all track fingerprints.
- SwiftTag should preserve a package’s existing `Id` whenever saving over an existing `.swifttag` package.
- Each track dictionary includes:
- `Fingerprint`
- `FLAC File URL`
- `FLAC File Bookmark`
- `FLAC Fingerprint`
- track tags by key/value
- `Pictures`
- Track fingerprint content is based on all tags in alphanumeric order plus picture references from the editor state at save time.
- FLAC audio MD5 fingerprints from source files and app-created SHA-256 fingerprints should preserve original key/value forms while trimming surrounding whitespace before hashing.
- `FLAC File URL` stores a normalized URL path.
- `FLAC File Bookmark` stores bookmark data for the original FLAC file.
- `FLAC Fingerprint` stores the FLAC stream MD5 already exposed through libFLAC.
- The `Pictures` folder stores pooled JPEG/PNG images from the editor at save time.
- Image filenames use the format `<picture type number>-<hash>.<mime extension>`.
- Each picture reference stored in the plist is the full filename, for example `3-<hash>.png` or `4-<hash>.jpg`.
- The leading number in a picture filename is the FLAC picture type or app slot number used for the reference.
- The hash portion reuses the same image-bytes hash concept already used by the app’s picture pool.
- Each track’s `Pictures` value stores picture metadata including:
- a reference to the picture file in `Pictures/`
- `FLAC Type`
- `MIME Type`
- `Description`
- `Width`
- `Height`
- `Depth`
- `Colors`
- Each track’s `Pictures` value is an array of picture dictionaries.
- SwiftTag document export should preserve the original picture bytes while recording accurate picture specs computed from those original bytes.
- If imported FLAC picture metadata specs differ from specs computed from the original picture bytes, SwiftTag should treat that mismatch as a saveable editor change for unlocked files.
- Even when a file is locked and cannot be written back to FLAC, SwiftTag document export should still write the original picture bytes and the correct computed specs into the `.swifttag` package.
- Tracks refer to shared pooled pictures instead of duplicating image bytes per track.
- The new File menu command title is `Save SwiftTag Document...`.
- Selecting the new command should save a SwiftTag document based on the frontmost editor contents.
- The export source of truth is the full frontmost editor session contents, not only the currently selected tracks.
- `Save SwiftTag Document...` is disabled for an empty editor.
- Repeated saves to the same `.swifttag` should plan for per-session remembered document URLs.

## Dependencies And Constraints
- The save command needs an explicit source of truth for the frontmost editor session and should reuse the same focused-scene routing approach as existing File menu commands.
- Because the app is not document-based today, SwiftTag document creation should be treated as an export/save-package workflow rather than a replacement for the existing FLAC save lifecycle unless future work changes that model.
- “Selected items” are not the source of truth for this feature; export should be session-scoped from the frontmost editor window unless a later clarification changes that behavior.
- Package serialization needs a stable, documented manifest schema so future open/import support can read it back without guessing at keys or normalization rules.
- Track fingerprint generation must define a canonical ordering and normalization strategy for:
- tag keys
- tag values
- picture-reference ordering
- mixed or absent picture metadata
- Image naming and manifest references must preserve enough metadata to reconstruct both shared pooled bytes and per-track picture association data later.
- Package writing should avoid mutating original FLAC files; the only persisted side effect of this feature should be creation or replacement of the `.swifttag` package itself.
- The package writer must preserve JPEG versus PNG bytes from the current editor pool rather than re-encoding images, or hashes and future round-tripping may drift.
- The menu command’s enabled state must be defined for empty editors and editors without imported FLAC tracks.
- If a save operation targets an existing package, the writer should replace obsolete pictures and manifest contents atomically enough to avoid partial packages on failure.
- The writer needs a stable way to remember, per editor session, the chosen `.swifttag` destination URL and the document `Id` assigned on first save.

## Write-Back Behavior
- Preserved data:
- original FLAC files and their on-disk metadata remain unchanged
- the editor’s in-memory state remains the source used to build the export
- pooled image bytes are preserved without re-encoding when written into the package
- the document `Id` remains unchanged for repeated saves to the same remembered `.swifttag` document
- Replaced data when saving to an existing `.swifttag` path:
- the destination package’s `Info.plist`
- the destination package’s `Pictures` folder contents
- Removed data when overwriting an existing `.swifttag` path:
- obsolete picture files no longer referenced by the newly exported manifest
- any previous manifest fields or track entries no longer present in the new export snapshot
- Selection semantics:
- the export includes all loaded tracks and pooled pictures from the frontmost editor session
- current table selection does not limit which tracks are written

## High-Risk Concerns
### Product / Behavioral Risks
- If manifest hashing rules are underspecified, identical editor state could produce different document fingerprints across saves, making future reopen/diff behavior unreliable.
- If picture-spec correction is not based on the original stored picture bytes, SwiftTag could write incorrect dimensions/color information while still preserving the original file payload.
- If the save command uses the wrong editor/session source of truth, users could save a background window instead of the intended frontmost editor.
- If stale or invalid security-scoped bookmarks are copied blindly into the package, later reopen support may fail in ways that are hard to diagnose.
- If empty or partially loaded editors are handled inconsistently, users may get confusing enabled-state or empty-package behavior.
- If a later save to an already existing `.swifttag` path handles document identity incorrectly, the “new once, then stable” `Id` rule could drift.

### Tooling / Environment / Sandbox Risks
- Save-panel interaction is difficult to validate with lightweight SwiftUI inspection alone; a narrow XCUI path may still be required.
- File-package writing and atomic replacement can be brittle if implemented through ad hoc filesystem calls rather than a single well-defined package writer seam.
- Info.plist document-type registration and icon/package metadata must be persisted in source, not just changed in Xcode UI state.
- Fixture-based verification can cover manifest generation and package layout, but bookmark bytes and sandbox behavior may still vary between tests and live app sessions.

## Implementation Phases
1. Finalize Document Format And Save Semantics
- Confirm unresolved format choices before implementation starts:
- manifest key names/casing
- canonical fingerprint normalization rules
- Define how a new document `Id` is created on first save and then preserved in memory for later saves to the same remembered document URL.
- Define how first-save document creation interacts with the rule to preserve an existing package’s `Id` when saving over a pre-existing `.swifttag` package.

2. Register The SwiftTag Package Type
- Add a SwiftTag package document type to `Info.plist`.
- Register the `.swifttag` extension, icon, type role, and package metadata with `LSTypeIsPackage = true`.
- Decide whether the new type should be exported, imported, or both based on whether creation-only support still needs Finder recognition immediately.

3. Add A SwiftTag Document Model And Writer
- Create a dedicated manifest/package model for the root plist and picture inventory.
- Add helpers for:
- document fingerprint generation
- per-track fingerprint generation
- picture-reference generation from picture type plus hashed image bytes plus MIME-derived file extension
- picture metadata capture for `FLAC Type`, `MIME Type`, `Description`, `Width`, `Height`, `Depth`, and `Colors`
- picture-spec computation from original picture bytes without mutating or re-encoding those bytes
- stable sorting of tags, tracks, and picture assets
- Implement a package writer that produces:
- `Info.plist`
- `Pictures/`
- only the picture files referenced by the exported tracks
- Prefer a single writer seam that can target a temporary directory/package and then replace the destination package cleanly.

4. Build Export Snapshots From The Frontmost Editor
- Add a frontmost-editor export API that gathers the current editor session state without altering existing FLAC save behavior.
- Build the export snapshot from the current source-of-truth state:
- `TagEditorViewModel.trackItems`
- remembered SwiftTag document URL and document `Id` state for the current session
- imported track bookmarks
- per-track FLAC fingerprint values
- `AlbumArtViewModel.picturePool`
- `AlbumArtViewModel.trackReferencesByTrackID`
- FLAC/import metadata or image-derived metadata needed for width, height, depth, and colors
- Map per-track tags and picture references into manifest dictionaries.
- Use pooled image bytes and reference metadata to decide picture filenames and manifest references.
- Define how non-imported tracks, missing bookmarks, or missing fingerprints are handled during export.
- Add a comparison path so incorrect imported picture specs versus computed specs are surfaced as saveable differences for unlocked FLAC tracks.

5. Add Menu Command And Save Dialog Flow
- Extend `FocusedValues` and `ContentView` with a new frontmost-editor action for SwiftTag document saving.
- Add `Save SwiftTag Document...` to the File menu immediately after the existing save-item group in `SwiftTagApp`.
- Present a save dialog constrained to `.swifttag`.
- On first save, store the selected destination and the newly assigned document `Id` in per-session state for later saves.
- Route the selected destination into the package writer and surface failures through the app’s existing save error presentation or a dedicated SwiftTag-document error path if needed.
- Define and implement command enablement for no-editor, empty-editor, and in-progress-save states, with the command disabled for empty editors.

6. Add Targeted Tests And Verification
- Add unit tests for:
- track fingerprint canonicalization
- document fingerprint canonicalization
- picture-reference naming
- manifest sorting and plist encoding
- Add service/file tests using temporary directories and checked-in FLAC fixtures to verify:
- package layout
- `Info.plist` contents
- `Pictures` deduplication
- preservation of JPEG/PNG extensions
- copied normalized FLAC file URL, bookmark, and fingerprint values
- picture dictionaries include the expected metadata fields in array form
- exported picture specs are computed from original picture bytes while preserving the original bytes unchanged
- incorrect imported picture specs are surfaced as saveable differences for unlocked tracks
- repeated saves preserve the same document `Id`
- Add targeted UI/XCUI coverage for:
- File menu contains `Save SwiftTag Document...`
- command is disabled in an empty editor and enabled in a loaded editor
- save-panel flow only if a narrow automation seam is practical
- Prefer `BuildProject`, then targeted tests, and reserve a broader UI run only if the save-panel path proves unstable.

## Test Strategy
Order:
1. Pure unit tests:
- track fingerprint generation uses stable alphanumeric tag ordering
- hashing trims surrounding whitespace but preserves original stored key/value forms
- picture-reference generation uses the full filename format `<picture type>-<hash>.<extension>`
- picture metadata mapping includes `FLAC Type`, `MIME Type`, `Description`, `Width`, `Height`, `Depth`, and `Colors`
- per-track `Pictures` serialization uses an array of picture dictionaries
- picture-spec computation reads original bytes and does not re-encode image data
- document fingerprint generation is stable for identical track sets
- plist model encoding preserves the expected key/value structure
2. Service/file tests using temp directories plus fixtures:
- export of a fixture-backed editor writes `Info.plist` and `Pictures/`
- duplicate pooled pictures are written once even when referenced by multiple tracks
- mixed JPEG/PNG assets keep the expected extension
- track dictionaries contain normalized FLAC file URLs, bookmark data, and FLAC fingerprint values
- track `Pictures` data includes the expected picture metadata payload for each referenced picture in array form
- exported picture bytes match the original bytes used by the editor pool
- exported width, height, depth, and colors reflect computed specs from those original bytes
- repeated saves to the same remembered document path preserve the same document `Id`
- replacing an existing package removes obsolete picture files and leaves a valid final package
3. Targeted SwiftUI/state tests where practical:
- focused-scene export action is published only for active editor content
- command enablement matches the chosen empty-editor rule
- per-session remembered document URL and document `Id` state update on first save
- picture-spec mismatch contributes to saveable-difference detection when the file is unlocked
4. Targeted XCUI tests only where lighter seams are insufficient:
- File menu shows `Save SwiftTag Document...`
- invoking the menu command from a loaded editor reaches the expected save flow if the panel can be driven reliably
5. Verification workflow:
- `BuildProject`
- targeted `RunSomeTests`
- narrow XCUI run only for the menu/save-panel scenario if needed

## Acceptance Criteria
- The app registers `.swifttag` as a packaged document type with the `SwiftTagNamedDoc` icon and package metadata persisted in source.
- The File menu shows `Save SwiftTag Document...` immediately after the existing save-item group.
- The command operates on the frontmost editor session, not a background editor.
- The command is disabled for an empty editor.
- Invoking the command opens a save dialog for a `.swifttag` destination.
- Saving writes a file package containing `Info.plist` and `Pictures/`.
- `Info.plist` contains document `Id`, `Version`, `Fingerprint`, and a `Tracks` array.
- Each exported track dictionary contains its editor-state fingerprint, normalized FLAC file URL, FLAC bookmark, FLAC fingerprint, serialized tags, and a `Pictures` array with picture metadata and picture-file references.
- The package fingerprint is derived from the exported track fingerprints using the documented canonical ordering.
- App-created SHA-256 hashes and FLAC MD5 values are computed from trimmed inputs while preserving original stored key/value forms.
- Picture assets are deduplicated at the package level and named with the `<picture type>-<hash>.<extension>` reference format.
- Tracks sharing the same pooled picture refer to the same picture file instead of duplicating bytes.
- Exported `.swifttag` picture entries preserve original picture bytes while recording accurately computed width, height, depth, and colors from those bytes.
- Incorrect imported picture specs are treated as saveable differences for unlocked FLAC files.
- Repeated saves to the same remembered `.swifttag` path preserve the document `Id`.
- Saving a SwiftTag document does not modify the original FLAC files.
- Targeted automated tests cover manifest generation, package layout, remembered document state, and command/menu wiring sufficiently for implementation sign-off.

## Open Questions
- None currently.
