# Add AppleScript Support Plan

## Goal
Add first-party AppleScript support to SwiftTag with a bundled SDEF, a scriptable object model for application/editor window/document/track/tag/picture data, and command routing for file add/open/save/quit flows that matches SwiftTag's existing editor behavior.

## Scope
In scope:
- Add a bundled SDEF based on a pruned Standard Suite plus a new `SwiftTag Suite`.
- Define script terminology for:
  - `application`
  - `editor window`
  - `document`
  - `swift tag`
  - `track`
  - `tag`
  - `picture`
  - `settings`
- Support AppleScript access to editor windows, tracks, `.swifttag` documents, FLAC tags, FLAC pictures, and application settings.
- Support AppleScript commands for:
  - standard `open`
  - standard `close`
  - standard `delete`
  - standard `exists`
  - standard `make`
  - standard `move`
  - standard `save`
  - standard `set`
  - standard `quit`
  - custom `add`
  - custom `add picture`
  - custom `delete picture`
- Define how script getters/setters map onto the existing SwiftUI session, `TagEditorViewModel`, FLAC import/save flows, and `.swifttag` package metadata.
- Add targeted automation coverage for terminology shape, command routing, and scriptable value coercion.

Out of scope:
- General Automation support beyond AppleScript terminology and command handling.
- Reworking the app into an `NSDocument`-based architecture.
- Shipping every possible FLAC picture-slot list property in v1 unless explicitly finalized during this plan.
- Exposing internal testing-only controls or save-notification debug hooks to AppleScript.
- Replacing existing menu/import/save UI flows; AppleScript should route through the same core logic where practical.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed:
  - `Docs/Plans/25-AddPictureDescriptionEdit.md`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
- Relevant implementation files reviewed:
  - `SwiftTag/SwiftTagApp.swift`
  - `SwiftTag/ContentView.swift`
  - `SwiftTag/FlacMetadataService.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/Shared/Utilities/EditorWindowCoordinator.swift`
  - `SwiftTag/Shared/Models/EditorSessionModels.swift`
  - `SwiftTag/Shared/Models/Track.swift`
  - `SwiftTag/Shared/Models/TagKey.swift`
  - `SwiftTag/Shared/Models/SaveSettings.swift`
  - `SwiftTag/Shared/Models/FeedbackSettings.swift`
  - `SwiftTag/Shared/Models/FlacPictureModels.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentSupport.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackageManifest.swift`
  - `SwiftTag.xcodeproj/project.pbxproj`
  - `SwiftTag/Info.plist`
- Relevant fixtures inspected:
  - `SwiftTagTestFiles/test.flac`
  - `SwiftTagTestFiles/test-with_padding.flac`
- Prototype artifact created:
  - `Docs/Plans/_SwiftTag.sdef`
- Constraints accounted for:
  - SwiftTag is a SwiftUI `WindowGroup` app with no `NSDocument`-based editor object model in the app target.
  - `AppDelegate` and `EditorWindowCoordinator` already route Finder/menu/open events into the active or newly created editor session.
  - `ContentView.importSelectedURLs(...)` already supports append-vs-replace import behavior and is the current root seam for a scriptable `add` command.
  - Editor-window identity already exists as `EditorSessionValue.sessionID`, but it is not currently exposed as a script object.
  - Current editor-session fingerprints in `EditorWindowCoordinator` are normalized path strings, not SHA256 hashes.
  - `Track.fingerprint` currently stores the FLAC STREAMINFO MD5 audio fingerprint returned by `FlacMetadataService`, not a tags-and-pictures digest.
  - `.swifttag` manifests already contain a `SwiftTags` payload, but that payload currently contains only `Author` and is not an arbitrary key/value store.
  - Settings are split across `@AppStorage` declarations plus `SaveSettingsKey` / `FeedbackSettingsKey`; no aggregate settings model exists today.
  - SwiftTag now sets `NSAppleScriptEnabled = Yes` and `OSAScriptingDefinition = SwiftTag.sdef`.
  - Cocoa scripting requires Objective-C-visible classes, selectors, and KVC/KVO-compatible keys; SwiftTag's current core editor models are mostly Swift structs and `@State` view-model state.

## Current Implementation Snapshot
- App-level file open routing already exists:
  - Finder/open-file events enter through `AppDelegate.application(_:openFile:)`, `application(_:openFiles:)`, and `application(_:open:)`.
  - Those routes normalize into `EditorWindowCoordinator.routeOpenedDocuments(...)`.
  - Active-window FLAC opens append into the focused editor session when the app is active.
- Menu-level add/import behavior already distinguishes replace-vs-append:
  - `ContentView.showWritableImporter()` and `showReadOnlyImporter()` replace the current track set after destructive-action confirmation.
  - `ContentView.showAddWritableImporter()` and `showAddReadOnlyImporter()` append imported FLAC files.
  - `ContentView.importSelectedURLs(...)` is the shared async import seam.
- Editor-window identity already exists independently of `NSWindow.uniqueID`:
  - `EditorSessionValue.sessionID` is a UUID.
  - `WindowCloseGuardRepresentable.Coordinator` exposes that session UUID through `EditorWindowSessionIdentifying.editorSessionID`.
- SwiftTag document identity and persistence already exist:
  - `SwiftTagDocumentSaveState` stores `destinationURL`, `documentID`, `securityScopedBookmarkData`, and availability.
  - `SwiftTagDocumentPackageWriter` writes a package manifest with document id and fingerprint.
  - `SwiftTagDocumentPackageReader` reads `.swifttag` packages back into the editor.
- Track data already has broad metadata coverage, but not as typed script properties:
  - `Track` stores shared album/album artist/track totals plus a raw `[String: String]` tag dictionary.
  - Many requested AppleScript track properties are not dedicated typed fields today; they would have to map through string tags with coercion.
  - `Track.flacPictureRecords` already stores full picture metadata and bytes.
- Picture slot modeling already exists in UI logic:
  - `ContentView.albumArtTypes` defines FLAC picture-slot mappings.
  - `AlbumArtViewModel` already builds picture metadata and track-reference groupings by slot.
  - Initial AppleScript picture access uses the raw per-track picture collection rather than slot-list properties.
  - Slot-list properties remain unresolved beyond collection filtering such as `every picture whose picture type is front cover`.
- AppleScript infrastructure now exists for the initial app/editor/document/track/tag surface:
  - `SwiftTag/SwiftTag.sdef` is enabled through `NSAppleScriptEnabled` and `OSAScriptingDefinition`.
  - `SwiftTagAppleScriptSupport.swift` provides ObjC-visible wrappers and command routing.
  - `SwiftTagScriptPicture` exposes read/query access to track pictures and writable picture descriptions.

## Confirmed Decisions
- Standard terminology should use a pruned copy of Cocoa's Standard Suite rather than relying on an in-bundle `xi:include` at runtime.
- SwiftTag should define its own top-level `application` class instead of inheriting Cocoa's stock `application` definition untouched.
- `editor window id` should be based on the existing editor session UUID rather than `NSWindow.uniqueID`.
- `application`, `editor window`, `document`, `track`, `tag`, `picture`, `swift tag`, and `settings` are the intended script-facing nouns.
- The prototype SDEF should live in `Docs/Plans/_SwiftTag.sdef` until bundle integration work begins.
- The prototype SDEF may use provisional payload shapes for unresolved custom commands as long as those unresolved areas are called out explicitly in the plan.
- AppleScript support should reuse existing import/save core logic where practical instead of forking separate scripting-only mutation paths.
- Track `tag` manipulation should prefer Standard Suite collection/class commands (`make`, `set`, `delete`, `exists`, `move`) over custom `add tag` / `delete tag` verbs.
- `save` on `editor window` should write FLAC files only; `save` on `document` should write the `.swifttag` package only.
- `editor window` save should accept optional `selected tracks` / `all tracks` scope overrides and `tags` / `pictures` payload overrides.
- When `editor window` save omits those overrides, it should use `settings.defaultSaveScope` and `settings.defaultSavePayload`.
- Track queries should use standard AppleScript object specifiers and `whose` filters such as `every track whose title is "..."`.
- AppleScript track collection order should match the visible SwiftUI track table order: numeric track number ascending, tracks without a numeric track number after numbered tracks, then localized filename sort.
- `editor window.selected tracks` is the script-facing UI selection state and should be mutated via `set`, not by a custom `select` verb.
- FLAC pictures are exposed as `picture` elements of `track`, backed by the existing `Track.flacPictureRecords` order.
- Picture `picture type` is exposed as the `flac picture type` enumeration so AppleScript can filter with `whose picture type is front cover`.
- The picture type property uses code `pcty` and Cocoa key `pictureType`; the AppleScript term is not `type` because that conflicts with AppleScript's built-in `type` term in `whose` filters.
- Picture `description` is writable through standard `tdsc` terminology and routes through the same in-memory track picture record used by the SwiftUI editor.
- Scripted picture `description` mutations also refresh album-art references so `AlbumArtPictureMetadata.descriptionText()` and `metadataForSlot` reflect the updated value.
- Picture `data` is exposed as an SDEF `data` value type backed by `NSData` plus a `scriptingDataDescriptor`, avoiding Swift `Data` Apple event coercion failures.

## Apple Documentation Review Update
- Apple Docs Scout reviewed current primary Apple docs for Cocoa scripting.
- Findings confirmed there is no native SwiftUI AppleScript object-model API in current searched docs.
- Additional review for picture bytes confirmed SDEF custom value types can use a Cocoa `NSData` backing class; runtime verification showed returning `NSData` with a data descriptor is the compatible Cocoa scripting path.
- Current implementation should continue using:
  - bundled SDEF terminology
  - `NSObject` / KVC-compatible script wrapper objects
  - `NSScriptCommand` command routing
  - `NSScriptObjectSpecifier` / `NSWhoseSpecifier` collection filtering
  - SwiftUI-to-AppKit bridge seams for app/window integration

## Dependencies And Constraints
- Bundle integration:
  - The app bundle will need `NSAppleScriptEnabled = Yes`.
  - The app bundle will need `OSAScriptingDefinition = SwiftTag.sdef`.
  - The runtime SDEF must live in the app target's bundled resources, not only in `Docs/Plans`.
- Object-model bridge:
  - Cocoa scripting needs ObjC-exposed wrapper objects or ObjC-compatible surface methods.
  - Current editor state lives in `ContentView`, `TagEditorViewModel`, `AlbumArtViewModel`, and value types like `Track`; those are not directly usable as Cocoa scripting objects.
- Identity and fingerprint mismatches:
  - window fingerprint requested in the SDEF is a tracks SHA256 hash, but current `EditorWindowCoordinator` uses a newline-joined normalized path string for lookup.
  - track fingerprint requested in the SDEF is a tags-and-pictures SHA256 hash, but current `Track.fingerprint` is the FLAC audio MD5.
  - document fingerprint requested in the SDEF is a tracks SHA256 hash, but current `.swifttag` manifest fingerprint semantics may need to be confirmed before reusing the name directly.
- Data coercion:
  - Many scriptable track properties are currently raw text tags.
  - AppleScript-facing `boolean`, `integer`, and `date` properties will need deterministic string-to-value and value-to-string rules.
  - Empty/missing values need explicit semantics for nullable tags.
- File access and sandboxing:
  - AppleScript-provided file URLs still need to respect security-scoped access and the app's existing bookmark flows.
  - Scripted add/open/save commands cannot bypass the current access rules.
- Settings surface:
  - Settings currently span `ContentView`, settings views, save settings models, and feedback settings models.
  - There is no single existing `settings` object to expose to AppleScript.
- Document terminology:
  - SwiftTag does not currently use `NSDocument` windows for editing.
  - A scriptable `document` object therefore needs custom wrapper semantics even if it preserves Standard Suite naming.

## Destructive / Write-Back Behavior
- Preserved data:
  - AppleScript getters must not mutate editor state.
  - Track audio bytes remain unchanged unless an existing FLAC save path writes metadata back.
  - `.swifttag` package structure remains unchanged unless the plan explicitly expands document metadata.
- Replaced data:
  - Script-set track/tag/picture values should replace in-memory editor values for the targeted objects.
  - Save commands should reuse the same write mappers already used by the UI.
- Removed data:
  - `delete tag` removes only the targeted FLAC metadata tag(s).
  - `delete picture` removes only the targeted picture object(s).
  - No other tag or picture data should be removed as collateral.
- Partial-save behavior confirmed:
  - `save` on `editor window` writes FLAC metadata only, using AppleScript-provided payload/scope overrides or default save settings.
  - `save` on `document` writes only the `.swifttag` package.
  - `editor window` save does not implicitly save a referenced `.swifttag` document; scripts can save the `document` object separately.
- Selection/source-of-truth semantics:
  - AppleScript object collections should be driven by the current editor-session state, not by UI table selection.
  - `editor window.tracks` and `document.tracks` should reflect the full current session/document track set.
  - `editor window.selected tracks` should reflect the current track-table UI selection and `set selected tracks ...` should update that UI selection.
  - Querying tracks should continue to use standard AppleScript object specifiers (`every track`, `tracks of ...`, `whose`) rather than repurposing selection state.

## High-Risk Concerns
### Product / Behavioral Risks
- The requested fingerprint names do not match current stored values, so exposing them without renaming or recomputing would be misleading.
- The requested writable `track URL` property is ambiguous:
  - it could mean rebinding the in-memory file reference
  - moving/renaming the FLAC file on disk
  - or it should be read-only despite the current prototype text
- `swift tag` currently implies a generic document metadata collection, but the current manifest only has `Author`.
- Many requested typed track properties are currently free-form text tags, so naive coercion could lose original formatting or make empty values impossible.
- Custom picture verbs still need clear boundaries against Standard Suite collection semantics.
- Picture-slot list properties are unresolved beyond `front cover`, and write behavior for those lists is not yet specified.
- `add` without an explicit target window needs deterministic routing behavior when no editor window is frontmost.

### Tooling / Environment / Filesystem Risks
- Cocoa scripting in a SwiftUI-first app often needs ObjC runtime seams that are easy to get wrong without careful KVC/object-specifier testing.
- Script-command selectors and wrapper classes can compile while still failing in Script Editor if object specifiers or KVC keys are incomplete.
- Sandboxed file access may behave differently for AppleScript-supplied files than for NSOpenPanel-supplied files if bookmark/access handling is not reused correctly.
- AppleScript verification can be brittle in automated environments; tests will likely need a small `osascript` harness and targeted script fixtures.

## Implementation Phases
1. Finalize terminology and unresolved semantics
- Freeze suite/class/property/command names.
- Decide what `fingerprint` means for window/document/track objects.
- Decide whether `track URL` is writable.
- Decide whether `swift tag` remains `Author`-only in v1 or expands the `.swifttag` manifest schema.
- Decide which settings belong in the initial scripting surface.
- Decide exact payload syntax for `add picture` and `delete picture`.
- Decide which picture-slot list properties ship in v1 beyond `front cover`.

2. Build scriptable wrapper layer
- Add ObjC-visible scripting wrapper objects for:
  - application
  - editor window
  - document
  - track
  - tag
  - picture
  - settings
- Add object-specifier support and collection accessors.
- Bridge wrappers back to `EditorWindowCoordinator`, `ContentView`, `TagEditorViewModel`, and `AlbumArtViewModel`.

3. Bundle SDEF and enable scripting in the app target
- Move the finalized SDEF into the app bundle resources.
- Add `NSAppleScriptEnabled` and `OSAScriptingDefinition` to the app plist/build settings.
- Ensure the app target actually packages the SDEF resource.

4. Implement read-only script surface first
- Expose application/editor window/document collections.
- Expose track/tag/picture/document metadata getters.
- Add deterministic UUID and URL accessors.
- Add hash computation helpers if v1 keeps the requested SHA256 fingerprint names.
- Expose a placeholder or complete `settings` object depending on the finalized scope.

5. Implement mutating commands and setters
- Route `add` through existing import flows with append semantics.
- Add track/tag/picture mutation APIs that update the same in-memory state the UI edits.
- Route `save` and `close` to existing unsaved-changes/save flows.
- Ensure script mutations mark the session dirty in the same way UI edits do.

6. Verification and automation
- Add terminology-shape tests for wrapper object collections and property mappings.
- Add coercion tests for `boolean`, `integer`, `date`, and URL-backed properties.
- Add picture collection tests for count, properties, `whose picture type is front cover`, and description mutation.
- Add album-art refresh regression tests so scripted picture description edits update current metadata and preserve duplicate picture references.
- Add raw picture data tests for descriptor type/bytes and real `/usr/bin/osascript` access to `data of firstCover`.
- Add targeted command-routing tests for `add`, `save`, `close`, and `quit`.
- Add at least one `osascript`-driven integration test that opens SwiftTag, adds a fixture FLAC, reads a few properties, mutates a tag, and saves.
- Manually verify the dictionary in Script Editor.

## Test Strategy
- Prefer pure/unit tests first for:
  - fingerprint/hash helpers
  - tag coercion helpers
  - wrapper-to-model mapping
  - settings mapping
- Add focused service tests for:
  - scripted add/import routing against copied FLAC fixtures
  - scripted save routing against copied FLAC fixtures and copied `.swifttag` packages
- Add focused wrapper tests for:
  - `pictures of track`
  - `count pictures`
  - `every picture whose picture type is front cover`
  - picture `description` setter routing
- Use targeted script integration tests instead of broad UI automation where possible:
  - invoke `osascript` with fixture paths
  - assert stdout/stderr and file-side effects
- Reserve XCUI only for behaviors that depend on frontmost window focus or responder-chain routing that cannot be exercised through scripting/unit seams.

## Acceptance Criteria
- SwiftTag bundles a valid runtime SDEF and advertises it through `OSAScriptingDefinition`.
- Script Editor shows a Standard Suite plus SwiftTag Suite for SwiftTag.
- `application` exposes `editor windows` and `settings`.
- `editor window`, `document`, `track`, `tag`, `picture`, and `swift tag` objects can be queried from AppleScript.
- `track` exposes `picture` elements with type, MIME type, description, dimensions, color depth, colors, and data.
- AppleScript can count pictures and filter pictures by properties such as `picture type is front cover`.
- `add` can append one or more FLAC files to a targeted/default editor window and returns the added track object(s).
- Requested read-only properties work with the finalized fingerprint semantics.
- Requested writable properties update in-memory editor state and participate in existing dirty/save flows.
- `save`, `close`, `open`, and `quit` respect finalized unsaved-changes behavior.
- The finalized v1 `settings` surface is scriptable.
- Targeted automated tests cover wrapper mapping, command routing, and at least one end-to-end AppleScript scenario.

## Open Questions
- Should `track URL` be writable, and if so, what exact behavior should setting it trigger?
- Should `document` mean only a saved `.swifttag` package, or also the current unsaved editor-session document abstraction?
- Should `swift tag` v1 expose only current manifest `Author`, or should SwiftTag document metadata become an arbitrary key/value collection?
- Which picture slot list properties beyond `front cover` should ship in v1?
- Should picture-slot list properties be read-only filtered collections or writable replacement properties?
- Which application settings belong in the first scriptable `settings` surface?
- Should requested window/document/track `fingerprint` properties remain named `fingerprint` if the implementation cannot provide the requested SHA256 semantics?
- What exact string formatting rules should AppleScript setters/getters use for FLAC-backed `date`, `integer`, and `boolean` properties?
- When `add` omits a target editor window, should SwiftTag use the front window, active session, or open a new editor window?
