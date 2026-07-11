# Transcript Review: transcript-2026-04-06-3-ReuseEmptyEditorIssue

- Path: `Docs/Plans/Transcripts/transcript-2026-04-06-3-ReuseEmptyEditorIssue.md`
- Content digest: `8c683158c0059b4a200ee8db88d6850ae376012d319d8c9e3df2c094209d2466`
- Review-input digest: `de07bad4319ef62d2047dae3bd6cfaf93c05bc95cfb8c7dcc6507b9ec7f72db3`
- Current status: `reviewed`

## Base Segments

### transcript-2026-04-06-3-ReuseEmptyEditorIssue:segment-001 (lines 12-49)

There is a subtle bug where the first available empty window is not always used when opening a .swifttag document. So update the code to always open .swiftag documents in a new window unless the document is already associated with a window in which case make that window key window. Remove test `testSwiftTagDocumentOpenReusesMultipleUnusedWindowsInOrderBeforeOpeningNewOnes` and replace with test for new behavior. I’m tracing the document-opening flow first so we can change the reuse behavior safely and update the affected test to match. After that I’ll patch the app logic, run a targeted build/test pass, and report what changed. I found the existing seam in EditorWindowCoordinator and the exact unit tests covering the current reuse rule. I’m reading those sections closely now so we can switch from “reuse unused windows” to “always open a new window unless the document is already tied to one” without disturbing the associated-window path. The coordinator currently builds a sorted list of “unused” sessions and routes new .swifttag files into them before creating a fresh session. I’m checking the app-side window opener next, because for the new rule we want the coordinator to stop sele

### transcript-2026-04-06-3-ReuseEmptyEditorIssue:segment-002 (lines 50-71)

Fix `testFileMenuSavePicturesDoesNotPersistTagOnlyEditsAcrossRelaunch`. The issue is that the menu item name has changed to “Save Pictures” and is now available only when option is held down in conjunction with command s. I’m locating that relaunch test and the save-menu helper it uses so I can update the UI interaction to the new Option-Command-S “Save Pictures” path without disturbing the rest of the flow. I found the failing seam: that test still clicks a literal File > Save Pictures... item, but the app now exposes the pictures-only save as the Option-Command-S alternate. I’m switching the test to drive the actual keyboard shortcut, which is a closer match to the current UI contract and avoids menu alternate visibility quirks. I’ve got the exact test block now. I’m patching it to use a dedicated keyboard-shortcut helper so the intent stays obvious and any future save-pictures UI adjustments only need one test helper change. The test is updated. I’m running that one UI case now to verify the Option-Command-S path works end to end across relaunch, since UI menu/shortcut changes are exactly where regressions like this like to hide. The targeted UI test passed, so the failure reall

## Candidate Commits

- `03227c22ec04d4a16f48e8159bca42426af9eac7` — fix(tags): treat total count aliases as equivalent (1.00; changed path mentioned, subject tokens: file, key, shared, source, tag, when, path/topic overlap)
- `0539816b5ba23a6e25ff44d6be08444b0f8dd6c7` — fix(album-art): reject oversized flac picture imports (1.00; changed path mentioned, subject tokens: current, docs, file, flow, single, status, path/topic overlap)
- `063c138d4ad746588a85c0be70cc1c5c75854e87` — feat(applescript): expose diff tools settings (1.00; changed path mentioned, subject tokens: assert, assertions, behavior, coverage, diff, docs, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (1.00; changed path mentioned, subject tokens: docs, editor, edits, pictures, tag, transcript, path/topic overlap)
- `1276536d7ce542d757187ed8e2a7a229c6741847` — feat(package): add SwiftTag document creation and serialization (1.00; changed path mentioned, subject tokens: command, current, docs, document, editor, file, path/topic overlap, commit before transcript within 7d)
- `17b6c1045af4a5e5e2c465dded80f53ff5695df5` — feat(applescript): expose settings preferences (1.00; changed path mentioned, subject tokens: behavior, coverage, diff, save, tag, unit, path/topic overlap)
- `19369540b1a2f92b3ab4fd1cedb4db7cefe41498` — fix(editor): preserve track title editing and queued finder opens (1.00; changed path mentioned, subject tokens: after, already, bug, change, covering, create, path/topic overlap)
- `1c2bb82cfcda4a8e4043b7e883e42928b18064cf` — feat(document): add support for opening .swifttag documents (1.00; changed path mentioned, subject tokens: command, coordinator, docs, document, documents, editor, path/topic overlap, commit before transcript within 3d)
- `24428a1548324e06268c9174e358e22e9559801b` — fix(applescript): support making tags from track tell contexts (1.00; changed path mentioned, subject tokens: after, bug, changes, command, coverage, create, path/topic overlap)
- `25fde2c3d0c01acd97eb967b5903f6336c57b6ae` — fix(applescript): preserve picture IDs after deleting same-type pictures (1.00; changed path mentioned, subject tokens: after, all, coverage, instead, only, pictures, path/topic overlap)
- `27b32d888ac16fcaa31f6735b29d960131a8315c` — feat(save): add FLAC tag and picture writing workflow (1.00; changed path mentioned, subject tokens: app, behavior, both, coverage, current, docs, path/topic overlap)
- `27b4d85ec22c4165acb415ef3929bd10d4c35202` — feat(save): add SwiftTag document follow-on save options (1.00; changed path mentioned, subject tokens: after, code, command, coverage, docs, document, path/topic overlap)
- `29444d740b06ee147a5690f1070d56abfa8be162` — feat(tag-editor): add track file rename workflow (1.00; changed path mentioned, subject tokens: all, before, docs, editor, file, files, path/topic overlap)
- `2976159836a41160b0a462b26c952968c19a7923` — fix(applescript): refresh album-art state after picture imports (1.00; changed path mentioned, subject tokens: after, conversation, coverage, docs, order, status, path/topic overlap)
- `29c8eed7decacebe51ab53c9150e9b5b86cd9f3b` — fix(tag-editor): when MixedStateCheckbox is disabled it does not display checkbox state (1.00; changed path mentioned, subject tokens: bug, coverage, docs, does, editor, flow, path/topic overlap)
- `2aee7213d2467ac765cf2f834b3e8b0a5409064e` — feat(settings): add duplicate picture overlay controls (1.00; changed path mentioned, subject tokens: 2026, coverage, diff, docs, multi, new, path/topic overlap)

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
