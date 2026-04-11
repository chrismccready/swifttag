# Add SwiftTag Document Quick Look Preview Extension Plan

## Goal
Add a `.swifttag` Quick Look Preview app extension so Finder and other Quick Look hosts can preview SwiftTag documents through an `.appex` embedded in the app bundle's `PlugIns` folder.

The intended result is:
- the built app contains a Quick Look Preview extension in `SwiftTag.app/Contents/PlugIns`
- Quick Look can preview `.swifttag` packages owned by SwiftTag
- the preview background uses the first front-cover picture saved in the `.swifttag` document when one exists, or a bundled SwiftTag app-icon fallback when it does not
- the preview text shows:
  - `ALBUM` in 1.5x system label font size
  - `ALBUMARTIST` in regular system label font size when non-empty
  - `ARTIST` in regular system label font size only when all tracks share the same `ARTIST` and that value differs from `ALBUMARTIST`
  - track rows in regular system label font size using `TRACKNUMBER TITLE`
- track rows are sorted by numeric `TRACKNUMBER`, display non-zero-padded numbers, and use the final visible row for `...` when not all rows fit

## Scope
In scope:
- Add a Quick Look Preview app extension target for `.swifttag` documents.
- Embed the `.appex` in the host app's `PlugIns` folder.
- Reuse the existing `.swifttag` package reader to build a preview snapshot from package contents only.
- Add a deterministic preview model for:
  - background-image selection
  - shared tag derivation
  - track ordering
  - overflow-to-ellipsis behavior
- Render the preview using current Apple-supported Quick Look preview-extension APIs.
- Add a dedicated fallback image resource for the SwiftTag app icon inside the extension bundle.
- Add targeted automated coverage for preview snapshot derivation and layout decisions, plus a narrow render smoke test.

Out of scope:
- A Quick Look Thumbnail extension.
- Reopening referenced FLAC files or resolving FLAC bookmarks during preview generation.
- Changing the `.swifttag` package format.
- Reworking the main app's editor UI, document save flow, or document routing behavior beyond reusable shared helpers.
- Adding editable or interactive Quick Look content.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed:
  - `Docs/Plans/22-AddSwiftTagDocumentSaveOptions.md`
- Relevant prior plans reviewed:
  - `Docs/Plans/16-AddSwiftTagDocumentRead.md`
  - `Docs/Plans/21-AddSwiftTagDocumentBookmark.md`
- Current implementation files reviewed:
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackage.swift`
  - `SwiftTag/Shared/Models/Track.swift`
  - `SwiftTag/Shared/Models/TagKey.swift`
  - `SwiftTag/ContentView.swift`
  - `SwiftTag/SwiftTagApp.swift`
  - `SwiftTag/Info.plist`
  - `SwiftTagTests/SwiftTagDocumentTests.swift`
  - `SwiftTag.xcodeproj/project.pbxproj`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
- Relevant fixtures inspected:
  - `SwiftTagTestFiles/test.flac`
  - `SwiftTagTestFiles/test-with_padding.flac`
- Constraints accounted for:
  - `.swifttag` is already exported as `com.toowalks.swifttag-document` and conforms to `com.apple.package`.
  - `SwiftTagDocumentPackageReader.read(from:)` already reads the package root `Info.plist` and pooled picture assets from `Pictures/`.
  - `SwiftTagDocumentPackageWriter.save(...)` sorts saved tracks by `sortKey` and then title, so persisted manifest order is deterministic but not necessarily raw in-window table order.
  - The current project has only the app target plus test targets; there is no existing `.appex` target or `PlugIns` embedding phase.
  - The app target links libFLAC through a build script and bridging header, but the requested Quick Look preview can and should avoid that dependency by reading only the saved `.swifttag` package.
  - App extensions are separate bundles and processes, so the extension cannot assume access to the main app's resources or permissions.
  - Quick Look preview registration and cache invalidation can make development verification appear stale unless the extension install state is checked carefully.

## Current Implementation Snapshot
- `SwiftTagDocumentPackageReader.read(from:)` returns `SwiftTagDocumentImportResult` with:
  - the document URL and ID
  - the package fingerprint
  - ordered imported tracks
  - per-track tags
  - per-track pooled picture records
  - source FLAC URLs and security-scoped bookmark data
- `SwiftTagDocumentPackageWriter.save(...)` writes a `.swifttag` package with:
  - root `Info.plist`
  - root `Pictures/`
  - manifest keys `Id`, `Version`, `Fingerprint`, and `Tracks`
  - per-track `Tags` and `Pictures`
- `SwiftTag/Info.plist` already exports the `.swifttag` UTI and associates it with the main app as owner.
- `SwiftTagTests/SwiftTagDocumentTests.swift` already contains temporary package helpers and small image-data helpers that can seed preview tests without new checked-in `.swifttag` fixtures.
- `SwiftTag.xcodeproj/project.pbxproj` currently shows:
  - `MACOSX_DEPLOYMENT_TARGET = 26.2`
  - a filesystem-synchronized project layout
  - no existing app-extension target
  - no existing `PBXCopyFilesBuildPhase` for embedding app extensions in `PlugIns`

## Current Apple API Guidance
- Apple currently supports Quick Look Preview Extensions as app extensions that ship inside the containing app bundle.
- For custom document previews, Apple documents two extension styles:
  - view-controller based previews via `QLPreviewingController`
  - data-based previews via `QLPreviewProvider` and `QLPreviewReply`
- For this feature, the data-based path is the better fit because the requested result is a static composed preview, not an interactive document UI.
- Apple documents `QLPreviewingController.providePreview(for:) async throws -> QLPreviewReply` on macOS 12+, which is the current async API and should be preferred over the older completion-handler shape.
- Apple documents `QLFilePreviewRequest.fileURL` as the file URL passed to the provider, which means the extension can read the `.swifttag` package directly from the preview request.
- Apple documents that Quick Look preview extensions must declare supported content types in the extension `Info.plist` under `QLSupportedContentTypes`.
- Apple documents that app extensions are separate processes and do not automatically share the containing app's resources or permissions, so the extension should rely only on the previewed package plus its own bundled resources.
- Apple documents `QLPreviewReply` initializers for:
  - drawing into a Core Graphics context
  - returning file-backed preview data
  - returning PDF-backed previews
- Apple documents SwiftUI `ImageRenderer` on macOS 13+ as the current way to render SwiftUI views into `CGContext` or PDF output. Given this project targets macOS 26.2, a SwiftUI-authored preview view rendered through `ImageRenderer` into a PDF-backed `QLPreviewReply` is the most current and maintainable implementation direction.

## Confirmed Decisions
- The preview renders strictly from the saved `.swifttag` package contents and does not reopen referenced FLAC files or use FLAC bookmarks.
- If `TRACKNUMBER` is missing, non-numeric, or duplicated, the preview uses the saved document order as the fallback and tie-breaker.
- The background image fills the preview, crops as needed, and is blurred behind the text for legibility.
- When the track list overflows, the last visible track row is replaced with a single `...` row.
- This plan covers the Quick Look preview extension only, not a thumbnail extension.
- The preview continues to use the file's saved package contents as the source of truth even when those contents differ from current live FLAC files on disk.

## Data Access Behavior
- Preserved data:
  - the `.swifttag` package remains the only data source used by the extension
  - the saved manifest order remains available as a deterministic fallback for track ordering
  - saved pooled picture assets remain the only source for cover-art background selection
- Replaced data:
  - none; the extension is read-only and does not modify the document or its referenced FLAC files
- Removed data:
  - no preview-time dependency on live FLAC file access, security-scoped bookmark resolution, or the libFLAC bridge
- File-access source of truth:
  - `QLFilePreviewRequest.fileURL` is the preview input
  - bundled extension resources provide the app-icon fallback image
  - no App Group or cross-process state sharing is required for the initial implementation

## Dependencies And Constraints
- The extension target should declare:
  - `NSExtensionPointIdentifier = com.apple.quicklook.preview`
  - `NSExtensionPrincipalClass` pointing at a `QLPreviewProvider` subclass
  - `NSExtensionAttributes.QLSupportedContentTypes = [com.toowalks.swifttag-document]`
- The containing app target must embed the `.appex` into `SwiftTag.app/Contents/PlugIns`.
- Because the extension is package-only, it should not link libFLAC, reuse the app target's bridging header, or depend on `FlacMetadataService`.
- Because the extension is a separate bundle, the fallback SwiftTag icon should be copied into the extension's own resources rather than referenced indirectly through the containing app's asset catalog.
- The provider should stay thin. Preview-specific derivation and layout logic should live in shared, testable helper types that can be compiled into both the extension target and `SwiftTagTests`.
- The preview should rely only on SwiftUI-renderable content if `ImageRenderer` is used, because Apple documents that `ImageRenderer` does not faithfully render arbitrary AppKit-backed controls.
- The row-fit algorithm should be parameterized by available canvas height and typography rather than hard-coded around a single window size so future visual tuning does not rewrite the ordering or overflow logic.
- Long values for album, artist, and title need explicit truncation behavior so overflow is deterministic rather than dependent on accidental text wrapping.
- Finder and Quick Look often cache extension registration and preview output, so the verification plan must distinguish build success from extension-registration success.

## High-Risk Concerns
### Product / Behavioral Risks
- If front-cover selection is not based on deterministic saved package order, different previews of the same document can show different artwork.
- If album, artist, or title wrapping is underspecified, the row-fit algorithm can miscount available lines and either hide tracks too early or overdraw the canvas.
- If numeric `TRACKNUMBER` parsing is inconsistent, duplicated or malformed values can lead to unstable order between previews.
- Very bright or very dark cover art can reduce readability unless the blur treatment is paired with a predictable overlay or shadow treatment.
- If the preview model leaks editor-only assumptions, future document-format changes can require touching extension code and app UI code in lockstep.

### Tooling / Environment / Sandbox Risks
- Quick Look extension registration and cache invalidation can mislead development validation even when the build is correct.
- App extensions do not automatically inherit the containing app's resources, so missing fallback art is an easy failure mode if resource membership is not explicit.
- `ImageRenderer` plus PDF output is the modern path, but it still needs a quick smoke test on the target OS to confirm the blurred background and text render acceptably in Quick Look.
- The Xcode project currently has no extension target, so project-file edits must add both the target itself and the embed phase without disturbing the existing filesystem-synchronized setup.

## Implementation Phases
1. Add The Quick Look Preview Extension Target
- Create a new macOS Quick Look Preview app extension target, for example `SwiftTagQuickLookPreview`.
- Set the extension deployment target to macOS 26.2 to match the containing app.
- Configure the extension `Info.plist` for `com.apple.quicklook.preview` and `QLSupportedContentTypes` with `com.toowalks.swifttag-document`.
- Add the new `.appex` product to the host app's embed phase so it is installed to `SwiftTag.app/Contents/PlugIns`.
- Keep the extension target independent from libFLAC, the bridging header, and unrelated app-only resources.

2. Extract Shared Preview Snapshot Helpers
- Add a small shared preview-support layer compiled into both the extension target and `SwiftTagTests`.
- Reuse `SwiftTagDocumentPackageReader.read(from:)` to load the `.swifttag` package from `QLFilePreviewRequest.fileURL`.
- Introduce a pure snapshot model, for example `SwiftTagDocumentQuickLookSnapshot`, that captures:
  - album display text
  - optional album-artist display text
  - optional shared-artist display text
  - ordered track rows
  - chosen background source
  - whether overflow requires an ellipsis row
- Define the background-image scan order as the first type-3 picture encountered while walking tracks in saved manifest order and pictures in saved picture order.

3. Build Track Ordering, Formatting, And Fit Logic
- Add a pure formatter for `TRACKNUMBER TITLE` rows.
- Parse `TRACKNUMBER` numerically for sorting and display; when numeric parsing succeeds, render the integer form so zero padding is removed.
- Use saved manifest order as the fallback and tie-breaker for missing, invalid, or duplicated track numbers.
- Add pure rules for the optional shared tag lines:
  - `ALBUM` always occupies the first text slot
  - `ALBUMARTIST` appears only when non-empty
  - `ARTIST` appears only when every track shares the same non-empty `ARTIST` and it differs from `ALBUMARTIST`
- Add a fit algorithm that measures available rows from the chosen canvas size and text metrics, then replaces the final visible track row with `...` when not all tracks fit.

4. Build The Rendering Pipeline
- Create a SwiftUI preview view that renders only SwiftUI-native content:
  - background image
  - blur treatment
  - darkening overlay or equivalent legibility treatment
  - stacked text rows
- Use AppKit or Core Graphics only where needed to decode image data into SwiftUI-displayable form.
- Prefer `ImageRenderer.render(...)` into a PDF context and return a `QLPreviewReply(forPDFWithPageSize:createDocumentUsing:)` so text and simple shapes remain resolution-independent.
- Keep the canvas size as a small set of tunable constants rather than a hard-coded scattering of magic numbers.
- Leave the provider responsible only for:
  - reading `request.fileURL`
  - building the snapshot
  - calling the renderer
  - returning `QLPreviewReply`

5. Add The Fallback SwiftTag Icon Resource
- Add a dedicated preview fallback image derived from the SwiftTag app icon artwork.
- Include that resource explicitly in the extension target so preview fallback does not depend on the containing app bundle's compiled assets.
- Ensure the fallback asset renders well when scaled, cropped, and blurred.

6. Add Targeted Tests And Verification
- Add pure unit tests for snapshot derivation, tag-line visibility rules, track ordering, and overflow behavior.
- Add a narrow render smoke test that produces non-empty PDF or image output from a stable preview snapshot.
- Add a fixture-driven test path that creates temporary `.swifttag` packages with and without front-cover art using existing package-writer helpers.
- Perform manual Quick Look verification after build by confirming:
  - the `.appex` is embedded in the app bundle
  - the extension is registered by the system
  - Finder or another Quick Look host shows the expected preview
- Document any Quick Look cache-reset steps needed during development if registration proves sticky.

## Test Strategy
Order:
1. Pure unit tests:
  - snapshot uses the first type-3 picture when one exists
  - snapshot falls back to the bundled SwiftTag icon when no type-3 picture exists
  - album-artist line is omitted when empty
  - artist line appears only when all tracks share the same non-empty `ARTIST` and it differs from `ALBUMARTIST`
  - numeric `TRACKNUMBER` values sort ascending and display without zero padding
  - invalid or duplicated `TRACKNUMBER` values fall back to saved manifest order
  - overflow replaces the final visible track row with `...`
2. Service tests using temporary packages:
  - create a `.swifttag` package with front-cover art and verify the snapshot selects that art
  - create a `.swifttag` package without type-3 pictures and verify the fallback background path
  - verify saved manifest order is preserved strongly enough to support the chosen fallback behavior
3. Render smoke tests:
  - render a representative preview snapshot to PDF or image output and assert the output is non-empty
  - if practical, inspect basic output metadata such as page size or image size to catch obviously broken rendering
4. Manual verification workflow:
  - build the app and extension
  - confirm the `.appex` is present under `SwiftTag.app/Contents/PlugIns`
  - verify Quick Look preview from Finder on a representative `.swifttag` package with front-cover art
  - verify Quick Look preview from Finder on a representative `.swifttag` package without front-cover art
  - if stale output appears, refresh Quick Look registration or cache before treating it as an implementation defect

## Acceptance Criteria
- The built app embeds a Quick Look Preview `.appex` inside `SwiftTag.app/Contents/PlugIns`.
- The extension declares support for `com.toowalks.swifttag-document` and Quick Look can preview `.swifttag` files owned by SwiftTag.
- The preview reads only the `.swifttag` package passed through `QLFilePreviewRequest.fileURL` and does not require live FLAC access.
- When the document contains one or more front-cover pictures with FLAC picture type `3`, the preview background uses the first such picture found in saved package order.
- When the document contains no front-cover picture, the preview background uses the bundled SwiftTag icon fallback.
- The chosen background fills the preview, crops as needed, and is blurred behind the text for legibility.
- `ALBUM` is rendered at 1.5x system label font size.
- All other preview tag lines are rendered at regular system label font size.
- `ALBUMARTIST` appears only when non-empty.
- `ARTIST` appears only when all tracks share the same non-empty `ARTIST` and that value differs from `ALBUMARTIST`.
- Track rows are sorted by numeric `TRACKNUMBER` with saved manifest order as the fallback and tie-breaker.
- Displayed track numbers are not zero padded.
- When not all tracks fit, the final visible track row is replaced with `...`.
- Automated tests cover snapshot derivation, ordering, conditional line visibility, overflow handling, and a render smoke path sufficiently for implementation sign-off.

## Open Questions
- None currently.