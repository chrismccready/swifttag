# Transcript Review: transcript-2026-03-02-1-MiscTagEditorDev

- Path: `Docs/Plans/Transcripts/transcript-2026-03-02-1-MiscTagEditorDev.md`
- Content digest: `09cc7c2c14f451239f07c72f46ec1a060b4f00056785875688f79289a9b26156`
- Review-input digest: `18237edca2aa021c63938c883a526e0f4c2b6eeda1a0c3e99fc81d9701ad76d0`
- Current status: `reviewed`

## Base Segments

### transcript-2026-03-02-1-MiscTagEditorDev:segment-001 (lines 12-30)

Add under the tracks table a TextField labeled "Number”, the edit field should have a width that allows for 2 characters, followed by a label named "of" followed by a TextField with no label, but referenced as totalTracks, this edit field should also have a width that allows for 2 characters. Update tracks data structure so that each track will have a unique id but the track tags are in a tag name indexed dictionary/map. This will allow the structure to store any number of tags even if they do not map to a specific UI element. Then update the code so that the new structure works on existing UI and any other references that need to be updated. feat(UI): added separate track number an total fields - Refactored Track to: - id: UUID - tags: [String: String] - Added tag-key constants (NUMBER, TITLE, FILENAME, ARTIST, COMPOSER, LOCATION, DATE, DESCRIPTION). - Updated table/UI bindings to read/write through tag dictionary. - Replaced keyPath-based selection editing with tag-name-based selection editing. - Updated date handling to store date as tag text (yyyy-MM-dd) and parse/format for UI. - Updated FLAC import to map metadata into tags while preserving required UI fields. - Updated TOML 

### transcript-2026-03-02-1-MiscTagEditorDev:segment-002 (lines 31-41)

Update TextField labeled "Number” to be bound with “number” in track tags dictionary and remove obsolete state var “number”. - Removed obsolete @State private var number: String = "". - Added selectedNumberBinding that binds to track tag TagKey.number. - Updated the TextField labeled Number to use selectedNumberBinding. - Kept disabled fallback behavior when no track is selected (consistent with your other tag-bound fields).

### transcript-2026-03-02-1-MiscTagEditorDev:segment-003 (lines 42-55)

Remove “Number” column from tracks table and update importFlacFiles function to assign track tags number to either “TRACKNUMBER” or “TRACK” in returned tags from FlacMetadataService.readTags call. - Removed the Number column from the tracks table. - Updated importFlacFiles so imported track tag NUMBER is assigned from: - TRACKNUMBER if present, else - TRACK, else - empty string. - Removed sequential-number assignment logic tied to nextTrackNumber. - Kept first-file album/album-artist behavior using importedTracks.isEmpty.

### transcript-2026-03-02-1-MiscTagEditorDev:segment-004 (lines 56-61)

Update Number TextField and following totalTracks bound TextField to accept positive integers above 0, the data structures are still of type String. Update Number TextField and following totalTracks bound TextField to center displayed text. Update importFlacFiles function to strip any leading zeros before trackTags[TagKey.number] assignment.

### transcript-2026-03-02-1-MiscTagEditorDev:segment-005 (lines 62-86)

Add a Table named miscTags below Description with the columns Key and Value, both columns are editable and rows are multi-selectable and deletable and new rows can be added, add small add “+” and delete “-“ buttons that will add and delete rows accordingly (I welcome suggestions on add/delete icons to use instead of “+”/“-“). Bind table rows to the track tags not explicitly defined by TagKey. - New miscTags table below Description with editable columns: - Key - Value - Multi-row selection for misc tag rows. - Add/remove controls (small icon buttons): - + via Image(systemName: "plus") - - via Image(systemName: "minus") - Row add/delete behavior: - Add inserts a new empty row. - Delete removes selected rows. - Data binding behavior: - Table rows are loaded from the selected track’s tags excluding explicit TagKey keys. - Key/value edits update selected tracks’ non-explicit tags. - Keys are normalized to uppercase on apply, and explicit keys are protected. Notes: - This uses SF Symbols (plus/minus) which are cleaner than literal +/-. - If you want alternatives, good options are plus.circle / minus.circle or plus.square / minus.square.

### transcript-2026-03-02-1-MiscTagEditorDev:segment-006 (lines 87-101)

Update miscTags Table so that all tags, except explicitTagKeys, found in any track are visible and editable when any track(s) are selected. If selected track(s) do not have a given tag display the tag key and an empty string for value. - When any track(s) are selected, the table shows the union of all non-explicit tag keys found in any track. - For each key, displayed value is computed from selected tracks: - same value across all selected tracks -> show that value - missing in one or more selected tracks (or mixed values) -> show empty string - Editing Value updates that tag for all selected tracks. - Editing Key renames that tag across selected tracks (excluding explicit keys). - Deleting selected misc-tag rows removes those tags from selected tracks only. - Explicit TagKey fields remain excluded.

### transcript-2026-03-02-1-MiscTagEditorDev:segment-007 (lines 102-124)

Lets update the miscTags Table so that row additions can be made at any time and make sure that the table is updated with any new tags (those not already in the table or defined in explicitTagKeys) when tracks are imported. miscTags now supports your two requirements: 1. Row additions at any time: - The + button is always enabled (no track selection required). - The misc tags table is no longer disabled when no tracks are selected. 2. Auto-include new imported tags: - After importFlacFiles appends tracks, it now calls reloadMiscTagRowsFromSelection(). - reloadMiscTagRowsFromSelection() now builds keys from: - all non-explicit tags found in any track, plus - any existing table keys already present in miscTagRows - This ensures newly imported non-explicit tags appear in the table even if they were not previously listed. Also preserved: - Selected-track value behavior (shared value shown, mixed/missing shown as empty). - Explicit tag keys remain excluded.

### transcript-2026-03-02-1-MiscTagEditorDev:segment-008 (lines 125-146)

Create git commit message. Git commit message Refine tag-driven track editor and misc tag table behavior - migrate track model to dictionary-backed tags with stable id - keep existing UI functionality mapped to tag keys (TITLE, ARTIST, DATE, etc.) - remove Number column from tracks table - bind Number field to selected track NUMBER tag and validate positive integer input - validate totalTracks as positive integer string and center-align both numeric fields - normalize imported track number from TRACKNUMBER/TRACK and strip leading zeros - add miscTags editable table (Key/Value) with multi-select, add, and delete actions - exclude explicit tag keys from misc tags handling - misc tags show union of non-explicit tags across all tracks - show empty value when selected tracks are missing/mixed for a tag - allow misc tag row creation at any time (even with no selection) - refresh misc tags after FLAC import so new non-explicit tags appear

## Candidate Commits

- `80b722ee0e77887149ebfd307538cac12a5907c3` — feat(notifications): reopen saved tracks from save success notifications (1.00; archive provenance only, subject tokens: editor, feat, imported, references, refresh, responses, path/topic overlap)
- `c965c3feb354452704670af683ab541da3c43f71` — Refine tag​-driven track editor and misc tag table behavior (0.88; subject tokens: across, actions, after, align, all, allow, path/topic overlap, commit before transcript within 1d)
- `03227c22ec04d4a16f48e8159bca42426af9eac7` — fix(tags): treat total count aliases as equivalent (0.85; subject tokens: explicit, fallback, file, imported, include, key, path/topic overlap)
- `0539816b5ba23a6e25ff44d6be08444b0f8dd6c7` — fix(album-art): reject oversized flac picture imports (0.85; subject tokens: album, bindings, button, data, description, docs, path/topic overlap)
- `063c138d4ad746588a85c0be70cc1c5c75854e87` — feat(applescript): expose diff tools settings (0.85; subject tokens: backed, behavior, docs, feat, map, new, path/topic overlap)
- `0c2d38575541a8dada750da08698d78e75a4d3f0` — feat(applescript): support standard track tag scripting (0.85; subject tokens: delete, docs, feat, flac, keys, model, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (0.85; subject tokens: album, description, docs, editor, edits, feat, path/topic overlap)
- `1276536d7ce542d757187ed8e2a7a229c6741847` — feat(package): add SwiftTag document creation and serialization (0.85; subject tokens: creation, data, docs, editor, etc, feat, path/topic overlap)
- `19369540b1a2f92b3ab4fd1cedb4db7cefe41498` — fix(editor): preserve track title editing and queued finder opens (0.85; subject tokens: after, allow, already, create, docs, editing, path/topic overlap)
- `1b08404c005806083a5443603d98c10c5510ee70` — feat(applescript): model color settings as records (0.85; subject tokens: accept, docs, feat, key, model, name, path/topic overlap)
- `1c2bb82cfcda4a8e4043b7e883e42928b18064cf` — feat(document): add support for opening .swifttag documents (0.85; subject tokens: docs, editable, editor, existing, feat, file, path/topic overlap)
- `24428a1548324e06268c9174e358e22e9559801b` — fix(applescript): support making tags from track tell contexts (0.85; subject tokens: after, create, data, docs, field, first, path/topic overlap)
- `27b32d888ac16fcaa31f6735b29d960131a8315c` — feat(save): add FLAC tag and picture writing workflow (0.85; subject tokens: actions, behavior, both, docs, editor, feat, path/topic overlap)
- `27b4d85ec22c4165acb415ef3929bd10d4c35202` — feat(save): add SwiftTag document follow-on save options (0.85; subject tokens: after, auto, code, docs, feat, flac, path/topic overlap)
- `29444d740b06ee147a5690f1070d56abfa8be162` — feat(tag-editor): add track file rename workflow (0.85; subject tokens: all, before, docs, editor, export, feat, path/topic overlap)
- `2976159836a41160b0a462b26c952968c19a7923` — fix(applescript): refresh album-art state after picture imports (0.85; subject tokens: after, album, conversation, data, docs, icon, path/topic overlap)

## Candidate Plans


## Candidate Themes

- `applescript` — AppleScript
- `diff` — Diff
- `flac-lib` — FLAC Lib
- `picture` — Picture
- `project` — Project
- `save` — Save
- `settings` — Settings
- `swifttag-document` — SwiftTag Document
- `tags` — Tags
- `user-docs` — User Docs
