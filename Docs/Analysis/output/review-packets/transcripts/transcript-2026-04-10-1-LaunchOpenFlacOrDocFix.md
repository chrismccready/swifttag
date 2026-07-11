# Transcript Review: transcript-2026-04-10-1-LaunchOpenFlacOrDocFix

- Path: `Docs/Plans/Transcripts/transcript-2026-04-10-1-LaunchOpenFlacOrDocFix.md`
- Content digest: `eb0cd50e7dcaf50b10e1e4d05dd17f6d31ee8c5e9050a43a172b655feaabebf0`
- Review-input digest: `db0b56af64422d7e19565b24d17359f0fff29e904060b6971d20d1c281c01fab`
- Current status: `reviewed`

## Base Segments

### transcript-2026-04-10-1-LaunchOpenFlacOrDocFix:segment-001 (lines 12-55)

SwiftTag and FLAC files opened by the Finder do launch app, but swifttag/flac containing window is not visible unless a new window is made. Consult Apple documentation as needed, create UI Test, and fix. Note, it is probably preferable that when the app is launched via a Finder open event that the default starting window gets used, but do not break the general rule of a new window when opening a swiftag document, it would be just in this case. I’m going to trace the Finder-open path, inspect the app/window lifecycle around FLAC document handling, and check the project’s testing guidance before I patch anything. I found the Finder-open handlers in SwiftTagApp.swift; next I’m reading the window-routing code and the testing guide so we can fix the visibility issue without breaking the existing scene flow. The routing entry point is very likely fine; the more interesting part is EditorWindowCoordinator, because that’s where the app decides whether to reuse, open, or surface a window after Finder hands it a FLAC. I’m incorporating that constraint: Finder-open at launch should prefer the default startup editor window, while regular SwiftTag document opens should still create a new window

## Candidate Commits

- `063c138d4ad746588a85c0be70cc1c5c75854e87` — feat(applescript): expose diff tools settings (1.00; changed path mentioned, subject tokens: apple, application, assertions, behavior, coverage, diff, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (1.00; changed path mentioned, subject tokens: apple, docs, editor, edits, flac, harness, path/topic overlap)
- `1276536d7ce542d757187ed8e2a7a229c6741847` — feat(package): add SwiftTag document creation and serialization (1.00; changed path mentioned, subject tokens: current, data, docs, document, editor, file, path/topic overlap)
- `17b6c1045af4a5e5e2c465dded80f53ff5695df5` — feat(applescript): expose settings preferences (1.00; changed path mentioned, subject tokens: apple, application, back, behavior, coverage, diff, path/topic overlap)
- `19369540b1a2f92b3ab4fd1cedb4db7cefe41498` — fix(editor): preserve track title editing and queued finder opens (1.00; changed path mentioned, subject tokens: after, already, bug, create, docs, document, path/topic overlap, commit before transcript within 7d)
- `1c2bb82cfcda4a8e4043b7e883e42928b18064cf` — feat(document): add support for opening .swifttag documents (1.00; changed path mentioned, subject tokens: coordinator, docs, document, editor, existing, file, path/topic overlap, commit before transcript within 7d)
- `24428a1548324e06268c9174e358e22e9559801b` — fix(applescript): support making tags from track tell contexts (1.00; changed path mentioned, subject tokens: after, apple, bug, changes, coverage, create, path/topic overlap)
- `25fde2c3d0c01acd97eb967b5903f6336c57b6ae` — fix(applescript): preserve picture IDs after deleting same-type pictures (1.00; changed path mentioned, subject tokens: after, apple, coverage, instead, only, reference, path/topic overlap)
- `27b32d888ac16fcaa31f6735b29d960131a8315c` — feat(save): add FLAC tag and picture writing workflow (1.00; changed path mentioned, subject tokens: app, behavior, both, coverage, current, docs, path/topic overlap)
- `27b4d85ec22c4165acb415ef3929bd10d4c35202` — feat(save): add SwiftTag document follow-on save options (1.00; changed path mentioned, subject tokens: after, code, coverage, default, docs, document, path/topic overlap, commit before transcript within 3d)
- `29444d740b06ee147a5690f1070d56abfa8be162` — feat(tag-editor): add track file rename workflow (1.00; changed path mentioned, subject tokens: before, docs, editor, file, files, flac, path/topic overlap)
- `2976159836a41160b0a462b26c952968c19a7923` — fix(applescript): refresh album-art state after picture imports (1.00; changed path mentioned, subject tokens: after, apple, conversation, coverage, data, docs, path/topic overlap)
- `29c8eed7decacebe51ab53c9150e9b5b86cd9f3b` — fix(tag-editor): when MixedStateCheckbox is disabled it does not display checkbox state (1.00; changed path mentioned, subject tokens: bug, coverage, docs, editor, flow, keep, path/topic overlap, commit before transcript within 1d)
- `2aee7213d2467ac765cf2f834b3e8b0a5409064e` — feat(settings): add duplicate picture overlay controls (1.00; changed path mentioned, subject tokens: 2026, coverage, diff, docs, new, transcript, path/topic overlap)
- `2e24923ec49954fa4d4b17f56f3d26c10265a51b` — fix(applescript): support track file comparisons (1.00; changed path mentioned, subject tokens: coverage, file, path, through, unit, while, path/topic overlap)
- `352ff8c562657dc7ed4c0171d4448bdda0bec559` — fix: preserve picture diff state across refresh flows (1.00; changed path mentioned, subject tokens: 2026, behavior, clean, coordinator, current, diff, path/topic overlap)

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
