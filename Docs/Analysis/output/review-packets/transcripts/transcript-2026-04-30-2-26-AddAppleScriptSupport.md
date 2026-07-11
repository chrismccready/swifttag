# Transcript Review: transcript-2026-04-30-2-26-AddAppleScriptSupport

- Path: `Docs/Plans/Transcripts/transcript-2026-04-30-2-26-AddAppleScriptSupport.md`
- Content digest: `fc6307f9b189a4b2ffca601324a854815c7fb296975b2d260a6b981d597cb898`
- Review-input digest: `b6a7491a981d06558634e81c5a15dad5ae3f153f3879ef55cc16e79d10ee38be`
- Current status: `reviewed`

## Base Segments

### transcript-2026-04-30-2-26-AddAppleScriptSupport:segment-001 (lines 12-93)

Review plan `26-AddAppleScriptSupport.md` and app’s current `SwiftTag/SwiftTag.sdef`. Add AppleScript `delete` functionality so the following can be done: ```applescript tell application "SwiftTag" tell front editor window tell first track set firstCover to item 1 of (every picture whose picture type is front cover) delete firstCover delete (every picture whose description is "delete me") end tell end tell end tell ``` Add tests including UI tests. Use Apple Docs Scout agent to review Apple’s AppleScript documentation to confirm use of latest technology, coding patterns, etc. Ask questions for clarification as needed. Review start. Need read plan, sdef, Apple docs profile, current AppleScript bridge. Then patch narrow. Need AppleScript map. Reading plan, sdef, support file, tests, docs scout profile now. Existing delete handles track tags, not pictures. Need add picture deletion path plus UI harness. Looking for picture APIs and osascript tests. Need exact wrapper shape. Reading script track/picture classes and bridge registration points. Apple Docs Scout requested. Delegating docs lookup while local patch work continues. Need confirm delete command pattern, not block on it. Spawni

### transcript-2026-04-30-2-26-AddAppleScriptSupport:segment-002 (lines 94-137)

AppleScript call to `delete` does not actually remove picture from AlbumArtImageWell. The following: ```applescript tell application "SwiftTag" tell front editor window tell first track set firstCover to item 1 of (every picture whose picture type is front cover) delete firstCover end tell end tell end tell ``` Works in terms of counts and references. The app side also works in terms of showing modifications of the track, but opening the picture browser reveals that actual picture is still displayed. Fix issue and create a UI test that confirms issue/fix. Repro clear. Count layer fixed; album-art presentation cache stale. Inspecting AlbumArtViewModel refresh path and current UI probes. Cause found: album-art merge keeps unmatched old references. Script delete removes track record, then presentation merge preserves stale picture. Fixing merge to mirror current track records while preserving stable IDs/pin state for matches. Fix done: script delete now throws away stale album-art cache for target track before rebuilding from track records. Added hidden UI probe for browser image presence. Next: UI test asserts probe is absent after delete. Build green. Running focused AppleScript UI 

## Candidate Commits

- `03227c22ec04d4a16f48e8159bca42426af9eac7` — fix(tags): treat total count aliases as equivalent (1.00; changed path mentioned, subject tokens: count, file, key, presence, read, shared, path/topic overlap)
- `0539816b5ba23a6e25ff44d6be08444b0f8dd6c7` — fix(album-art): reject oversized flac picture imports (1.00; changed path mentioned, subject tokens: album, art, cover, current, description, docs, path/topic overlap)
- `063c138d4ad746588a85c0be70cc1c5c75854e87` — feat(applescript): expose diff tools settings (1.00; changed path mentioned, subject tokens: apple, applescript, application, coverage, diff, docs, path/topic overlap)
- `0c2d38575541a8dada750da08698d78e75a4d3f0` — feat(applescript): support standard track tag scripting (1.00; changed path mentioned, subject tokens: access, apple, applescript, bridge, collection, delete, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (1.00; changed path mentioned, subject tokens: album, apple, applescript, art, cover, description, path/topic overlap, commit before transcript within 3d)
- `126cc0a4b597443b882c65566c53e996d2cc62d2` — fix(tag-editor): preserve picture spec mismatches in save checks (1.00; changed path mentioned, subject tokens: editor, image, paths, picture, records, regression, path/topic overlap)
- `1276536d7ce542d757187ed8e2a7a229c6741847` — feat(package): add SwiftTag document creation and serialization (1.00; changed path mentioned, subject tokens: command, current, docs, editor, etc, file, path/topic overlap)
- `17b6c1045af4a5e5e2c465dded80f53ff5695df5` — feat(applescript): expose settings preferences (1.00; changed path mentioned, subject tokens: apple, applescript, application, back, bridge, coverage, path/topic overlap)
- `192eaacabaecbe09ee3ee59d935f0d3ab2d86a02` — feat(applescript): initial AppleScript support (1.00; changed path mentioned, subject tokens: app, apple, applescript, count, docs, editor, path/topic overlap)
- `19369540b1a2f92b3ab4fd1cedb4db7cefe41498` — fix(editor): preserve track title editing and queued finder opens (1.00; changed path mentioned, subject tokens: actor, after, already, change, create, docs, path/topic overlap)
- `1b08404c005806083a5443603d98c10c5510ee70` — feat(applescript): model color settings as records (1.00; changed path mentioned, subject tokens: apple, applescript, change, docs, implementation, key, path/topic overlap)
- `1c2bb82cfcda4a8e4043b7e883e42928b18064cf` — feat(document): add support for opening .swifttag documents (1.00; changed path mentioned, subject tokens: command, docs, editor, existing, file, import, path/topic overlap)
- `1df3dd0c798507ee9db2c2005d577ac499b3e933` — docs(user): more applescript examples and links (1.00; changed path mentioned, subject tokens: applescript, docs, more, user, path/topic overlap)
- `2298c43c00492de67ad920a395d3ec7a8c8fb722` — feat(applescript): update tag normalization to invalidate white space contents (1.00; changed path mentioned, subject tokens: applescript, docs, tag, transcript, path/topic overlap)
- `2302109d0c43a41cb71c36e47cf2b4b8973a63d6` — Refine track metadata ​UI and import mapping for discs​/genres​/misc tags - add dictionary-backed handling for new explicit fields: DISC and GENRE - add Disc of total​Discs controls with selected-track binding and numeric validation - style total​Discs in bold red when non-empty TOTALDISCS tags mismatch entered value - add hover help messaging for total tracks/discs consistency indicators - convert total tracks display to read-only track-count text with mismatch highlighting and help (1.00; changed path mentioned, subject tokens: count, import, new, read, tags, track, path/topic overlap)
- `24428a1548324e06268c9174e358e22e9559801b` — fix(applescript): support making tags from track tell contexts (1.00; changed path mentioned, subject tokens: after, apple, applescript, clear, collections, command, path/topic overlap, commit before transcript within 3d)

## Candidate Plans

- Plan `26` — Add AppleScript Support Plan

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
