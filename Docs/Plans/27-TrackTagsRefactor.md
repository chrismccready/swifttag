# Track Tags Refactor Plan

## Goal
Refactor `Track.album`, `Track.albumArtist`, and `Track.totalTracks` so their source of truth is `Track.tags`, while keeping existing UI, scripting, and test call sites working through accessors.

Fix AppleScript read/write behavior so script properties and `tag` elements update the same underlying tag values in both directions.

## Scope
In scope:
- Make `Track.album`, `Track.albumArtist`, and `Track.totalTracks` tag-backed accessors instead of stored fields.
- Preserve current accessor names where practical to minimize call-site churn.
- Normalize tag aliases consistently:
  - `album` maps to `ALBUM`.
  - `albumArtist` maps to `ALBUMARTIST`.
  - `totalTracks` reads `TOTALTRACKS`, then `TRACKTOTAL`.
  - `totalTracks` writes canonical in-memory `TOTALTRACKS`; `TRACKTOTAL` remains a read alias and save-strategy output key only.
- Update UI bindings, document export/import, FLAC write mapping, external-difference logic, and AppleScript bridge code to rely on accessors or direct tags without dual storage.
- Keep current `SwiftTag.sdef` terms and four-character codes stable.
- Add focused regression coverage for UI bindings and AppleScript property/tag-element two-way mutation.

Out of scope:
- Renaming AppleScript terms such as `album`, `album artist`, or `track count`.
- Replacing Cocoa scripting with another automation technology.
- Changing `.swifttag` package schema beyond resulting tag payload normalization.
- Changing save-scope, save-payload, or selected-track semantics.
- Broad UI refactors unrelated to tag storage.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed:
  - `Docs/Plans/26-AddAppleScriptSupport.md`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
  - `Docs/AppleDocsIndex/apple-docs-scout-agent.md`
  - `Docs/AppleDocsIndex/README.md`
- Relevant implementation files reviewed:
  - `SwiftTag/Shared/Models/Track.swift`
  - `SwiftTag/Shared/Models/TagKey.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/Features/FlacImport/FlacImportMapper.swift`
  - `SwiftTag/Features/FlacImport/FlacWriteMapper.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagAppleScriptSupport.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentSupport.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackageReader.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackageWriter.swift`
  - `SwiftTag/SwiftTag.sdef`
  - `SwiftTagTests/SwiftTagAppleScriptTests.swift`
  - `SwiftTagTests/SwiftTagDocumentTests.swift`
  - `SwiftTagTests/TrackStatusViewInspectorTests.swift`
  - `SwiftTagUITests/SwiftTagUITests.swift`
- Relevant fixtures inspected:
  - `SwiftTagTestFiles/test.flac`
    - has `ALBUM=Test Album`, `ALBUMARTIST=Test AlbumArtist`, `TOTALTRACKS=01`, and picture blocks.
  - `SwiftTagTestFiles/test-with_padding.flac`
    - has same core Vorbis comments plus padding for writeback-oriented tests.
- Apple documentation reviewed:
  - Xcode DocumentationSearch for `NSScriptCommand`, `NSScriptSuiteRegistry`, `NSSetCommand`, `NSGetCommand`, `NSCreateCommand`, `NSScriptObjectSpecifier`, `NSUniqueIDSpecifier`, and KVC to-many collection behavior.
  - `Docs/AppleDocsIndex/Generated` exists, but local exact search found no Cocoa scripting / KVC scripting hits.

## Current Implementation Snapshot
- `Track` currently stores:
  - `var album: String`
  - `var albumArtist: String`
  - `var totalTracks: String`
  - `var tags: [String: String]`
- `Track.init(...)` derives the stored fields from explicit initializer arguments or from tags.
- UI code reads and writes the stored fields through key paths:
  - `selectedAlbumBinding()`
  - `selectedAlbumArtistBinding()`
  - `selectedTotalTracksBinding()`
  - `TagEditorViewModel.album`
  - `TagEditorViewModel.albumArtist`
  - `setTrackTotal(_:)`
- `TagEditorViewModel.selectedTrackValueBinding(_:)` currently special-cases album and album artist to also write `tags`, but does not do the same generic sync for total tracks.
- `swiftTagDocumentTags(forTrackAt:)`, `currentEditorTagsForExternalComparison(...)`, and `FlacWriteMapper` re-overlay stored fields onto tag dictionaries before saving/exporting/comparing.
- `SwiftTagScriptTrack.album`, `albumArtist`, and `trackCount` already expose stable KVC properties and call `updateTagValue(...)` on set.
- `SwiftTagAppleScriptTagKey.snapshots(for:)` currently injects stored `track.totalTracks` into the script tag collection, which can mask stale or missing tag storage.
- Deleting an AppleScript tag can remove `tags[ALBUM]` while stored `track.album` remains non-empty, which is current stale-dual-storage bug.

## Apple Documentation Review
- Current Apple guidance still supports Cocoa scripting through:
  - bundled SDEF terminology
  - `NSScriptSuiteRegistry`
  - `NSScriptCommand` and standard command subclasses
  - KVC/KVO-visible scriptable `NSObject` wrappers
  - object specifiers and KVC to-many collection methods
- `NSGetCommand` and `NSSetCommand` work through KVC; script-facing properties must remain KVC-visible on wrapper objects.
- `NSSetCommand` uses scripting class descriptions to choose property set versus to-many replacement, then calls KVC setters or `replaceValue(at:inPropertyWithKey:withValue:)`.
- `NSCreateCommand` can create objects and insert them into to-many relationships with `insertValue(_:at:inPropertyWithKey:)`.
- SwiftTag's current `tags` element shape matches the Apple pattern:
  - `tags`
  - `countOfTags`
  - `objectInTagsAtIndex`
  - `valueInTagsWithUniqueID`
  - insert/remove/replace mutators
- There is no newer SwiftUI-native AppleScript object model in reviewed docs. Keep AppKit/Foundation Cocoa scripting bridge.

## Confirmed Decisions
- `album`, `albumArtist`, and `totalTracks` belong in `Track.tags`.
- Existing convenience accessors should remain available for UI/tests/scripts.
- Current `SwiftTag.sdef` design goals from `26-AddAppleScriptSupport.md` remain valid.
- Keep AppleScript terms and Cocoa keys stable:
  - `album` / `album`
  - `album artist` / `albumArtist`
  - `track count` / `trackCount`
  - `tag` elements under `track.tags`
- AppleScript property syntax and tag-element syntax must mutate the same tag storage.
- Existing UI, scripting, and test layers should see minimal collateral change.
- Canonical in-memory total-track key is `TOTALTRACKS`; `TRACKTOTAL` is a read alias and save-strategy output key only.
- AppleScript `set album of track 1 to ""` does not delete `ALBUM`; it sets `ALBUM` to an empty string.
- AppleScript empty-string set behavior applies to all writable tag-backed script properties and `tag.value`.
- AppleScript `delete album of track 1` and `delete tag id "ALBUM"` remove the tag key.
- UI reads an empty scripted tag value as empty string and shows the existing empty/secondary/default presentation.
- Compatibility initializer arguments for `album`, `albumArtist`, and `totalTracks` remain available as migration/test convenience inputs.

## Dependencies And Constraints
- `Track` is a Swift struct, not script-facing directly. AppleScript talks to `NSObject` wrappers in `SwiftTagAppleScriptSupport.swift`.
- `WritableKeyPath<Track, String>` should continue to work with computed get/set accessors, preserving current SwiftUI binding code shape.
- Assignment order matters once accessors are tag-backed:
  - assigning `album` before assigning `tags` can be overwritten by later `tags` assignment.
  - refresh/import paths must set base tags first or use one helper that normalizes tags and overlay values together.
- `TOTALTRACKS` and `TRACKTOTAL` are aliases in FLAC-world input, but current script tag normalization exposes canonical `TOTALTRACKS`.
- Save settings still determine whether writeback emits `TOTALTRACKS`, `TRACKTOTAL`, both, or neither.
- Existing `TagWriteOptions` behavior must remain owner of file-write key strategy.
- Existing locked-track behavior must continue to block scripted and UI tag mutation.
- Existing selected-track semantics remain source of truth:
  - UI selected track IDs drive selected field bindings.
  - `editor window.selected tracks` remains the script-facing selection state.

## Destructive / Write-Back Behavior
Preserved data:
- Unrelated tag keys and values are preserved in `Track.tags`.
- Picture data and picture metadata are preserved.
- FLAC audio bytes are unchanged except through existing save paths.
- `.swifttag` document references, bookmarks, and fingerprints keep existing semantics.
- SDEF terms and Apple event codes remain stable.

Replaced data:
- Stored duplicate values for `album`, `albumArtist`, and `totalTracks` are replaced by computed accessors over `tags`.
- Setting `album` replaces `tags[ALBUM]`.
- Setting `albumArtist` replaces `tags[ALBUMARTIST]`.
- Setting `totalTracks` replaces canonical in-memory `tags[TOTALTRACKS]`.
- AppleScript setting any writable tag-backed property or `tag.value` to `""` replaces the value with an empty string and preserves the key.

Removed data:
- AppleScript `delete` removes the targeted tag key.
- Setting `totalTracks` to a non-empty value removes stale `TRACKTOTAL` in memory and writes `TOTALTRACKS`.
- Normalization may remove stale `TRACKTOTAL` after canonical `TOTALTRACKS` is written, but scripted empty-string assignment preserves `TOTALTRACKS` with an empty value.
- File writeback can still omit or emit total-track keys according to `TagWriteOptions`.

Partial-save behavior:
- Tags-only saves write the normalized tag map through existing FLAC write paths.
- Pictures-only saves should not be affected.
- Tags-and-pictures saves combine existing picture behavior with normalized tags.

## High-Risk Concerns
### Product / Behavioral Risks
- Tests currently encode stale dual-storage behavior, for example deleting `ALBUM` while `track.album` still returns old stored value. Expected behavior must flip.
- Canonical in-memory `TOTALTRACKS` may surprise scripts or tests that start with only `TRACKTOTAL`; plan keeps `TRACKTOTAL` as read alias and save-strategy output, not primary in-memory key.
- Empty-string behavior must stay distinct from delete:
  - AppleScript `set ... to ""` preserves the tag key with an empty value.
  - AppleScript `delete ...` removes the tag key.
- Misc tag UI must continue excluding explicit/core tags, including album, album artist, and total-track aliases.
- Existing document export/import tests may need expected tag payload updates where duplicate fields used to override tag dictionaries.

### Tooling / Environment / Filesystem Risks
- AppleScript wrappers can compile while failing at runtime if KVC method names or SDEF Cocoa keys drift.
- `NSSetCommand` and `NSGetCommand` depend on KVC-visible wrapper properties; moving storage must not remove `@objc` wrapper properties.
- AppleScript UI tests remain brittle; use unit bridge tests first and targeted UI harness only for end-to-end coverage.
- Xcode MCP test timeouts are possible; run targeted tests before broader suites.

## Implementation Phases
1. Add tag-backed accessor helpers on `Track`
- Add a central helper for normalized tag reads/writes, likely in `Track.swift`.
- Keep initializer arguments `album`, `albumArtist`, and `totalTracks` as compatibility inputs.
- In `Track.init(...)`, build `self.tags` first, then apply optional overlay arguments through the same helpers.
- Convert stored fields into computed properties:
  - `album`
  - `albumArtist`
  - `totalTracks`
- Ensure numeric normalization matches existing behavior:
  - trim whitespace.
  - collapse integer strings with `Int(...).map(String.init)`.
  - leave non-integer strings trimmed.
- Preserve explicit empty tag values where AppleScript set paths create them; do not collapse those writes into deletes.
- Add small helpers if useful:
  - `tagValue(for:)`
  - `setTagValue(_:for:)`
  - `totalTracksValue`
  - `setTotalTracksValue(_:)`

2. Update model and mapper dependencies
- Update `FlacWriteMapper.makeTags(...)` so it relies on computed accessors and current `TagWriteOptions`.
- Remove any duplicated overlay logic that only exists to work around stored field drift.
- Update import and refresh assignment order in `TagEditorViewModel`:
  - construct mapped tags first.
  - initialize `Track` with tags plus optional overlay arguments, or assign `tags` before accessors.
  - avoid setting computed accessors and then overwriting `tags`.
- Update `.swifttag` export/import paths so exported tags are normalized from one source of truth.
- Keep `currentEditorTagsForExternalComparison(...)` and `expectedFileTags(...)` semantically unchanged but tag-backed.

3. Update UI binding paths
- Keep current selected field bindings if `WritableKeyPath<Track, String>` works with computed setters.
- Remove album/albumArtist special-case tag writes around `selectedTrackValueBinding(_:)` once accessors handle storage.
- Ensure selected total-tracks binding writes/removes `TOTALTRACKS` and `TRACKTOTAL` consistently.
- Ensure `TagEditorViewModel.album`, `albumArtist`, and `setTrackTotal(_:)` update tag-backed accessors and clear external differences.
- Verify `reloadMiscTagRowsFromSelection()` still treats explicit tags as explicit, not misc rows.

4. Update AppleScript bridge
- Keep `SwiftTag.sdef` unchanged unless tests reveal a terminology mismatch.
- Keep `SwiftTagScriptTrack` `@objc` properties unchanged:
  - `album`
  - `albumArtist`
  - `trackCount`
- Keep `scriptPropertyTagKeys` entries for delete/set routing.
- Update `SwiftTagAppleScriptTagKey.snapshots(for:)` to derive from `track.tags` only.
- Preserve alias normalization:
  - `TRACKTOTAL` appears as canonical script tag `TOTALTRACKS`.
  - `DISCTOTAL` appears as canonical script tag `TOTALDISCS`.
- Ensure property setters and tag element setters both call the same `appleScriptUpsertTag(...)` bridge path.
- Ensure `appleScriptUpsertTag(...)` preserves empty string values instead of deleting keys.
- Ensure property deletion and tag deletion both call the same `appleScriptDeleteTag(...)` bridge path.
- Remove stale fallback reads from stored fields, especially `trackCount` fallback to `\.totalTracks` if redundant.

5. Update tests
- Add or update pure model tests for `Track`:
  - initializer maps explicit album values into tags.
  - computed setters update tags.
  - computed setters can preserve empty values when caller explicitly writes an empty value.
  - `TRACKTOTAL` reads as `totalTracks`.
  - setting `totalTracks` writes `TOTALTRACKS` and removes `TRACKTOTAL`.
- Update `SwiftTagAppleScriptTests`:
  - setting `scriptTrack.album` updates `tags[ALBUM]` and `scriptTrack.valueInTags(...)`.
  - setting `scriptTrack.album` to `""` preserves `ALBUM` with empty `tag.value`.
  - setting `ALBUM` tag updates `scriptTrack.album`.
  - deleting `ALBUM` clears `scriptTrack.album`.
  - setting `scriptTrack.albumArtist` updates `ALBUMARTIST`.
  - setting `ALBUMARTIST` tag value to `""` preserves the tag wrapper and shows empty property text.
  - setting `scriptTrack.trackCount` updates canonical `TOTALTRACKS`.
  - setting `TOTALTRACKS` tag value to `""` preserves the tag wrapper and returns nil/empty property presentation as appropriate for typed integer coercion.
  - deleting `TOTALTRACKS` clears `scriptTrack.trackCount`.
- Update `SwiftTagDocumentTests`:
  - export uses tag-backed edited values.
  - no stale stored value overrides deleted/missing tag values.
- Add a `TagEditorViewModel` or ViewInspector-focused test:
  - selected album/album artist/total-tracks bindings write tags through accessors.
- Add fixture-backed service test if writeback behavior changes:
  - copy `SwiftTagTestFiles/test-with_padding.flac`.
  - update album artist and total tracks.
  - save tags-only.
  - re-read tags and confirm expected `ALBUMARTIST` and save-strategy total-track key output.
- Keep UI AppleScript tests targeted:
  - property/tag read-write through in-process `NSAppleScript` only if unit bridge coverage cannot prove runtime KVC behavior.

6. Verification
- Use Xcode MCP first:
  - `XcodeRefreshCodeIssuesInFile` on edited Swift files.
  - `BuildProject`.
  - targeted `RunSomeTests` for model/mapper tests once named tests exist.
  - targeted `RunSomeTests` for `SwiftTagAppleScriptTests`.
  - targeted `RunSomeTests` for `SwiftTagDocumentTests`.
- Use external shell fallback only when Xcode MCP is unavailable or insufficient:
  - `xcodebuild -scheme SwiftTag -destination 'platform=macOS' test -only-testing:SwiftTagTests/SwiftTagAppleScriptTests`
- Run full suite only near end or when targeted changes touch shared save/import behavior broadly.

## Acceptance Criteria
- `Track` no longer stores independent `album`, `albumArtist`, or `totalTracks` values.
- Existing app code can still call `track.album`, `track.albumArtist`, and `track.totalTracks`.
- UI edits to album, album artist, and total tracks update `Track.tags`.
- AppleScript property writes update tag elements.
- AppleScript tag-element writes update property reads.
- AppleScript empty-string writes preserve tag keys with empty values.
- AppleScript deletes clear both property reads and tag-element reads.
- `SwiftTag.sdef` terms and codes remain stable.
- FLAC tag writeback still honors `TagWriteOptions`.
- `.swifttag` export/import no longer depends on stale duplicate fields.
- Targeted tests cover model accessors, AppleScript bridge two-way mutation, document export, and selected UI bindings.

## Open Questions
- None.
