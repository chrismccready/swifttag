# Transcript Review: transcript-2026-03-24-1-11-AddMultiPicturePerTrackSupport

- Path: `Docs/Plans/Transcripts/transcript-2026-03-24-1-11-AddMultiPicturePerTrackSupport.md`
- Content digest: `7a79a7ccd4fd109baa2b3a24af1939f5a19e03760aaa7e93cffe10231e9f9b3b`
- Review-input digest: `66c514d2683f608d093e4dc0df762901fa014d5d8b4e4f54c15eca607838b9a0`
- Current status: `reviewed`

## Base Segments

### transcript-2026-03-24-1-11-AddMultiPicturePerTrackSupport:segment-001 (lines 12-50)

Create a plan to: - Add to chooseFrontCoverDropAction another case “add” for a new button titled “Add” that when selected will append picture to Front Cover list. - Remove "Pin Album Pictures" and albumArt.sheet.trackPictureScopePicker. - When the "Save all Pictures to all Tracks" setting is On it sets “Pin Track Pictures” On and albumArt.sheet.typePictureScopePicker is set to allTrackPictures and all regardless of selection, all, except locked, track pictures for a given slot are pinned and any added pictures are pinned including unique pictures added by loaded/added track files. - When "Save all Pictures to all Tracks" setting is Off all pictures loaded/added when are pinned based on the state of albumArt.sheet.typePictureScopePicker for that given slot that picture is associated with. - When "Save all Pictures to all Tracks" setting toggled Off it sets “Pin Track Pictures” Off and and albumArt.sheet.typePictureScopePicker is set to selectedTrackPictures and no action is taken on pin state. - "Save all Pictures to all Tracks" setting defaults to Off. - albumArt.sheet.typePictureScopePicker defaults to Off. - When “Save Front Cover to all Tracks” setting is On the “Pin Track Pictu

### transcript-2026-03-24-1-11-AddMultiPicturePerTrackSupport:segment-002 (lines 51-70)

1. Oops, yes, “albumArt.sheet.typePictureScopePicker” defaults to selectedTrackPictures. 2. When Save all Pictures to all Tracks toggles Off, existing unlocked picture references should stay pinned as-is. 3. For Front Cover Add, appended front covers should remain appended in both UI browsing order and FLAC write order. I’m updating the plan with your three clarifications so the implementation rules are explicit and no longer split between the plan and chat history. The first patch missed because that line had already shifted. I’m re-reading the current file and applying a narrower update against the actual text. The plan now includes your clarifications in Confirmed Decisions, implementation phases, tests, and acceptance criteria, and the open questions section is cleared. I’m doing one final read to make sure the plan no longer carries any stale ambiguity. The plan at Docs/Plans/11-v4-AddMultiPicturePerTrackSupport.md is updated with your clarifications. It now explicitly states that albumArt.sheet.typePictureScopePicker defaults to selectedTrackPictures, turning Save all Pictures to all Tracks Off preserves existing unlocked pinned references, and Front Cover Add must preserve a

### transcript-2026-03-24-1-11-AddMultiPicturePerTrackSupport:segment-003 (lines 71-118)

Read plan 11-v4-AddMultiPicturePerTrackSupport.md and implement. If further clarification is needed during implementation, stop and ask. I’m reading the implementation plan and the album-art/FLAC paths it affects first, then I’ll wire the changes through the model, mapper, and UI layers before validating with targeted diagnostics/builds. The resource reader isn’t exposing project files directly here, so I’m switching to the Xcode file tools to inspect the plan and current implementation surfaces. I’ve got the plan and the main album-art model open. Next I’m tracing the forcing/pinning helpers, the sheet UI, and existing tests so I can change the behavior without leaving dead state behind. I’ve confirmed the current code still has the exact competing controls the plan removes. I’m drilling into the AlbumArtViewModel helper layer and ContentView bindings now because that’s where most of the behavior change will actually land. The core issue is clear now: the model still relies on a hidden “effective pinned references” overlay. I’m replacing that with explicit per-slot state updates so the UI and save payload come from the same source of truth. I have enough context to edit. I’m updat

### transcript-2026-03-24-1-11-AddMultiPicturePerTrackSupport:segment-004 (lines 119-140)

- When the "Save all Pictures to all Tracks" setting is On or toggled On it does set “Pin Track Pictures” On and albumArt.sheet.typePictureScopePicker is set to allTrackPictures and both disabled, the current behavior implemented and perform the same pinning behavior that has been implemented, however, at time of toggle off it should just enable “Pin Track Pictures” and albumArt.sheet.typePictureScopePicker, nothing else. When "Save all Pictures to all Tracks" setting is Off the default pinning of pictures upon being added/loaded is based on the current albumArt.sheet.typePictureScopePicker state. - When the "Save Front Cover to all Tracks" setting is On or toggled On it does set, for Front Cover, “Pin Track Pictures” On and albumArt.sheet.typePictureScopePicker is set to allTrackPictures and both disabled, the current behavior implemented and perform the same pinning behavior that has been implemented, however, when toggled off it should just enable (unless "Save all Pictures to all Tracks" is On) “Pin Track Pictures” and albumArt.sheet.typePictureScopePicker, nothing else. When “Save Front Cover to all Tracks" setting is Off the default pinning of pictures upon being added/loaded

### transcript-2026-03-24-1-11-AddMultiPicturePerTrackSupport:segment-005 (lines 141-162)

1. When a forcing setting turns On and materializes all-track pinned references for unlocked tracks, turning that setting Off should leave those created references exactly as-is. 2. Yes, in non-forced mode with albumArt.sheet.typePictureScopePicker == .allTrackPictures, should add/load attach immediately to all unlocked loaded tracks. 3. No, in non-forced mode with albumArt.sheet.typePictureScopePicker == .selectedTrackPictures and no explicit track selection, it should not continue to mean all loaded tracks. However if selectedTrackPictures is selected, then when tracks are added/loaded those track pictures are pined to the track as if individually selected (this allows tracks to be added/loaded, have tags edited and be saved without losing their original pictures). I’m folding your three answers into the plan’s Confirmed Decisions and tightening the non-forced selectedTrackPictures language so it matches the track-load preservation rule you just specified. I updated 11-v4-AddMultiPicturePerTrackSupport.md with your confirmed decisions. The plan now explicitly states: - forced all-track references remain in place when the forcing toggle turns Off - non-forced .allTrackPictures add

### transcript-2026-03-24-1-11-AddMultiPicturePerTrackSupport:segment-006 (lines 163-199)

[ new context ] Read plan 11-v4-AddMultiPicturePerTrackSupport.md and implement. If further clarification is needed during implementation, stop and ask. I’m reading the current plan and the relevant album-art/track models first, then I’ll implement against the existing code paths and stop if the plan leaves destructive behavior or selection semantics ambiguous. I have the plan and the main album-art model. Next I’m tracing the UI bindings, save settings defaults, and the current tests so I can remove the obsolete controls without leaving mismatched behavior behind. I’ve confirmed the settings default and the current sheet source already removed the track-scope picker, but the model logic still carries the older effective/stored pin split. I’m reading the remaining helper methods now because the implementation hinges on replacing that hidden layer cleanly. Plan for implementation: 1. Refactor AlbumArtViewModel so the two settings drive control state and materialize all-track references without resetting manual state on disable. 2. Keep the sheet/API surface aligned with that model, including the default selected scope and front-cover append behavior. 3. Update affected tests for the

## Candidate Commits

- `68e340f508e0f0f5b0ac2fbbcae259abf6155b6e` — fix(tag-editor): canonicalize picture records for snapshot and reload diff checks (1.00; subject tokens: album, behavior, current, destructive, docs, editor, path/topic overlap, commit before transcript within 1d)
- `9e1ce62bf296678be8aa16075285d1f9e0cb453c` — feat(album-art): add scoped multi-picture browser and per-track picture save behavior (1.00; subject tokens: album, art, behavior, browsing, controls, coverage, path/topic overlap, commit before transcript within 3d)
- `b4593bad7a73d4737a89fa81f52b0a0c853f2bce` — feat(album-art): revise picture scope forcing and front cover append behavior (1.00; archive provenance only, changed path mentioned, subject tokens: action, active, adjust, album, all, append, path/topic overlap)
- `68f7c7b1c66c1a7acd0564610efe03ceff89180b` — feat(editor): add track management commands, safeguards, and additive import flows (0.93; subject tokens: action, context, default, destructive, disable, drop, path/topic overlap, commit before transcript within 7d)
- `ac28a73112d2a5170ee56f4f05fe6081f4376eb6` — feat(diff-tools): implement track/file diff states and mismatch warning customization (0.93; subject tokens: behavior, bindings, changes, content, date, editor, path/topic overlap, commit before transcript within 7d)
- `03227c22ec04d4a16f48e8159bca42426af9eac7` — fix(tags): treat total count aliases as equivalent (0.85; subject tokens: exclusion, explicit, file, initial, out, read, path/topic overlap)
- `0539816b5ba23a6e25ff44d6be08444b0f8dd6c7` — fix(album-art): reject oversized flac picture imports (0.85; subject tokens: album, art, bindings, button, cover, current, path/topic overlap)
- `063c138d4ad746588a85c0be70cc1c5c75854e87` — feat(applescript): expose diff tools settings (0.85; subject tokens: assert, assertions, behavior, coverage, defaults, docs, path/topic overlap)
- `0c2d38575541a8dada750da08698d78e75a4d3f0` — feat(applescript): support standard track tag scripting (0.85; subject tokens: docs, during, flac, flows, implementation, model, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (0.85; subject tokens: album, art, cover, docs, editor, flac, path/topic overlap)
- `1276536d7ce542d757187ed8e2a7a229c6741847` — feat(package): add SwiftTag document creation and serialization (0.85; subject tokens: current, data, docs, editor, file, list, path/topic overlap)
- `19369540b1a2f92b3ab4fd1cedb4db7cefe41498` — fix(editor): preserve track title editing and queued finder opens (0.85; subject tokens: action, after, already, change, create, docs, path/topic overlap)
- `1c2bb82cfcda4a8e4043b7e883e42928b18064cf` — feat(document): add support for opening .swifttag documents (0.85; subject tokens: docs, editor, existing, file, load, loaded, path/topic overlap)
- `1fcd08274065e59e148cb05d16e592e98f02bced` — Build ​FLAC from source and link as stais lib • configure FLAC CMake build for app use:    • static lib only (BUILD​_​SHARED​_​LIBS​=​OFF)    • disable programs (BUILD​_​PROGRAMS​=​OFF)    • disable C++ lib (BUILD​_​CXXLIBS​=​OFF)    • disable Ogg dependency (WITH​_​OGG​=​OFF) • remove dependency on bundled prebuilt Resources​/bin FLAC/metaflac artifacts (0.85; subject tokens: app, build, configure, disable, flac, off, path/topic overlap)
- `24428a1548324e06268c9174e358e22e9559801b` — fix(applescript): support making tags from track tell contexts (0.85; subject tokens: action, after, attach, changes, clear, context, path/topic overlap)
- `25fde2c3d0c01acd97eb967b5903f6336c57b6ae` — fix(applescript): preserve picture IDs after deleting same-type pictures (0.85; subject tokens: after, album, all, art, coverage, instead, path/topic overlap)

## Candidate Plans

- Plan `11` — Add Multi Picture Per Track Support Plan

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
