# Transcript Review: transcript-2026-04-07-2-DocumentPictureDiffFix

- Path: `Docs/Plans/Transcripts/transcript-2026-04-07-2-DocumentPictureDiffFix.md`
- Content digest: `3e9e9b2c37a9ce3399edfb4f45f3a93e599a0925ba72dbe41a56a5a5b536dd54`
- Review-input digest: `7b3996698da3c1e0065d7dcbd8dc1499b7fdf711d9d743faab791a50b40fa9d3`
- Current status: `reviewed`

## Base Segments

### transcript-2026-04-07-2-DocumentPictureDiffFix:segment-001 (lines 12-56)

Opened .swifttag document shows external differences in pictures when there are no differences: - Add two flac files to editor with one file having at least one more picture for a given type (e.g. one front cover in the first file and two front covers in the second). - Save as .swifttag document. - In a new window add the file that has less pictures for a type and edit tag, then save the flac file - Open saved .swifttag file, editor will show that all tracks have external differences in pictures with only one of the tracks showing in the window text that it has (by selection) an external difference. Neither actually have any picture difference. I suspect it has to do with seeing a difference based on picture ordering, but this is a guess. Create a UI test that confirms the issue and fix. I’m tracing the picture-diff flow first so we can reproduce the bug in the right layer, then I’ll add a UI test that locks the behavior down before fixing it. I’ve got the project layout and the likely planning docs; next I’m reading the testing guide plus the document/status code that computes picture differences so we can pin the regression to a specific comparison path. I found the exact compari

### transcript-2026-04-07-2-DocumentPictureDiffFix:segment-002 (lines 57-78)

[ interrupted agent ] When you typed to change a tag you lost focus and now text changes happened. I did steal focus with the XCUI run, and I’m stopping that path right now. I’m checking for any leftover test/app processes so nothing keeps typing or clicking. [ Context automatically compacted ] I’m stopping the focus-stealing UI automation path here. I’m going to finish the fix safely by cleaning up the UI test code so it builds, and I won’t run that XCUI test again unless you want me to. I’ve checked the UI test file, and the stale direct app-import helpers are no longer there. I’m reading the regression test and launch plumbing now so I can verify the safe state without re-running the focus-stealing test. The regression UI test is wired through launch-environment fixture overrides now, which means we can at least validate the code path by building without taking focus again. I’m running a project build next. I’ve got the safe verification now: the project builds cleanly, and I’m pulling the exact code locations so I can hand you a precise close-out without touching the UI again. [ 2026-04-07T08:57:41Z (2m 32s since Assistant start) ]

### transcript-2026-04-07-2-DocumentPictureDiffFix:segment-003 (lines 79-100)

[ interrupted agent ] No, continue with tests, I was just trying help point a potential false negative. I’m resuming with the targeted regression UI test only, so we can confirm the fix end-to-end without broad automation. If it exposes a real failure instead of the false negative you suspected, I’ll tighten the test or the fix from there. The test did fail, so this looks like a real remaining issue rather than just the earlier false negative. I’m pulling the failing assertion and the test log now so I can see whether the bug is still in comparison logic or in the test flow itself. The failure is at the first subtitle assertion after reopening. I’m checking the probe helpers and the underlying status logic next so I can tell whether the app is still reporting the wrong counts or the test is asserting the wrong post-save title/selection state. I’ve confirmed the UI probe is reading the same hidden subtitle text the window shows, so the failing assertion is about the actual computed counts. I’m looking at the subtitle derivation now to line the UI expectation up with the model behavior and see whether the first selected track should really show a selected tag difference count of 1 or

### transcript-2026-04-07-2-DocumentPictureDiffFix:segment-004 (lines 101-122)

[ interrupted agent ] Ok, if you are trying to change the track title in this test, you are failing, because as soon as you enter the track title field to change the title you lose focus and no changes happen. If this is your tag field to change, then either you will need to find out how to actually change this field or perhaps pick another field like Description to edit/change. You’re right, and that lines up with what the test is doing. I’m switching the external edit in the regression flow away from the title field and onto a stable tag field so the test validates the picture-diff bug instead of the title-focus bug. I’ve swapped the live-file edit to the album field, which should avoid the title-focus trap and keep the scenario true to “tag-only external change.” I’m rerunning that one UI test now. The targeted regression now passes with the album-field edit, so the focus problem was indeed producing a false negative in the first version of the UI test. I’m grabbing the final file locations and then I’ll give you a tight summary with the verification results. You were right: the first UI regression was getting a false negative because editing the title field drops focus before t

## Candidate Commits

- `03227c22ec04d4a16f48e8159bca42426af9eac7` — fix(tags): treat total count aliases as equivalent (1.00; changed path mentioned, subject tokens: count, differences, equivalent, file, key, out, path/topic overlap)
- `063c138d4ad746588a85c0be70cc1c5c75854e87` — feat(applescript): expose diff tools settings (1.00; changed path mentioned, subject tokens: behavior, coverage, diff, docs, harness, new, path/topic overlap)
- `0c2d38575541a8dada750da08698d78e75a4d3f0` — feat(applescript): support standard track tag scripting (1.00; changed path mentioned, subject tokens: docs, flac, model, session, tag, targets, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (1.00; changed path mentioned, subject tokens: album, art, cover, description, docs, editor, path/topic overlap)
- `126cc0a4b597443b882c65566c53e996d2cc62d2` — fix(tag-editor): preserve picture spec mismatches in save checks (1.00; changed path mentioned, subject tokens: behavior, canonicalization, checks, document, editor, export, path/topic overlap)
- `1276536d7ce542d757187ed8e2a7a229c6741847` — feat(package): add SwiftTag document creation and serialization (1.00; changed path mentioned, subject tokens: differences, docs, document, editor, file, list, path/topic overlap, commit before transcript within 7d)
- `17b6c1045af4a5e5e2c465dded80f53ff5695df5` — feat(applescript): expose settings preferences (1.00; changed path mentioned, subject tokens: behavior, coverage, diff, save, tag, through, path/topic overlap)
- `19369540b1a2f92b3ab4fd1cedb4db7cefe41498` — fix(editor): preserve track title editing and queued finder opens (1.00; changed path mentioned, subject tokens: after, already, avoid, bug, change, create, path/topic overlap, commit before transcript within 1d)
- `1c2bb82cfcda4a8e4043b7e883e42928b18064cf` — feat(document): add support for opening .swifttag documents (1.00; changed path mentioned, subject tokens: docs, document, editor, existing, file, import, path/topic overlap, commit before transcript within 7d)
- `1fcd08274065e59e148cb05d16e592e98f02bced` — Build ​FLAC from source and link as stais lib • configure FLAC CMake build for app use:    • static lib only (BUILD​_​SHARED​_​LIBS​=​OFF)    • disable programs (BUILD​_​PROGRAMS​=​OFF)    • disable C++ lib (BUILD​_​CXXLIBS​=​OFF)    • disable Ogg dependency (WITH​_​OGG​=​OFF) • remove dependency on bundled prebuilt Resources​/bin FLAC/metaflac artifacts (1.00; changed path mentioned, subject tokens: app, build, flac, link, only, shared, path/topic overlap)
- `24428a1548324e06268c9174e358e22e9559801b` — fix(applescript): support making tags from track tell contexts (1.00; changed path mentioned, subject tokens: after, bug, changes, context, coverage, create, path/topic overlap)
- `25fde2c3d0c01acd97eb967b5903f6336c57b6ae` — fix(applescript): preserve picture IDs after deleting same-type pictures (1.00; changed path mentioned, subject tokens: after, album, all, art, coverage, index, path/topic overlap)
- `27b32d888ac16fcaa31f6735b29d960131a8315c` — feat(save): add FLAC tag and picture writing workflow (1.00; changed path mentioned, subject tokens: app, behavior, both, count, coverage, docs, path/topic overlap)
- `27b4d85ec22c4165acb415ef3929bd10d4c35202` — feat(save): add SwiftTag document follow-on save options (1.00; changed path mentioned, subject tokens: after, code, coverage, docs, document, flac, path/topic overlap)
- `29444d740b06ee147a5690f1070d56abfa8be162` — feat(tag-editor): add track file rename workflow (1.00; changed path mentioned, subject tokens: all, before, cover, docs, editor, export, path/topic overlap)
- `2976159836a41160b0a462b26c952968c19a7923` — fix(applescript): refresh album-art state after picture imports (1.00; changed path mentioned, subject tokens: after, album, art, context, conversation, coverage, path/topic overlap)

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
