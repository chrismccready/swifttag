# Transcript Review: transcript-2026-04-06-2-ReuseEmptyEditorIssue

- Path: `Docs/Plans/Transcripts/transcript-2026-04-06-2-ReuseEmptyEditorIssue.md`
- Content digest: `cdb4e977e1acfb7f7a495f444bb59dd83c2d17c69145e076a2fda4cee3090f42`
- Review-input digest: `1c57ded61342b3ea56713508e8f6180d0b02a84e3961316c000901de42a71b24`
- Current status: `reviewed`

## Base Segments

### transcript-2026-04-06-2-ReuseEmptyEditorIssue:segment-001 (lines 12-58)

Why does ``` onDisappear { teardownEditorSession() } ``` on on line 927 of ContentView prevent opened swiftag documents fron loading content in window? Why is this code needed to make sure that loading swiftag documents always uses an empty editor first before creating a new window? Right now testSwiftTagDocumentOpenReusesUnusedWindowBeforeOpeningNewOne is failing because this code was removed to fix the not loading of document content bug. I would expext each window to have its own session period. Editor windows are not to be hidden, they are either there or destroyed. What do we do to fix this. I’m looking at the ContentView teardown path and the failing window-reuse test first so we can pin down which lifecycle assumption is wrong: document window state, editor session state, or both. I found two separate teardown hooks already: onDisappear and the native window-close callback. I’m reading both the teardown implementation and the reuse test now, because the failure smells like one hook is being asked to cover two different lifecycle events. The coordinator side confirms the mismatch: it treats an “unused window” as a still-live session with active handlers, but teardownEditorSes

### transcript-2026-04-06-2-ReuseEmptyEditorIssue:segment-002 (lines 59-88)

Ok, there is a subtle bug where the first available window is not always used. If I launch app, load a flac in the first window, then make a new window, then open a .swiftag document, the document will load into the latest empty window, now make a new window, then close the document associated window, then open the document again, it will not load into the latest empty window, it will load into a new window instead. I’m tracing that exact window sequence through the coordinator now, because it sounds like a routing-order bug after a document session is removed, not the earlier teardown issue. I found a likely culprit: when the coordinator decides “reuse session X,” it still opens via whichever window action is currently active, instead of preferring X’s own window action. That would explain why the first open works when the empty window is key, but reopening after closing the doc window can hop to a brand-new window when focus has shifted elsewhere. I’m adding a regression test for the exact bad shape: one loaded active window, one inactive empty reusable window, then reopen the document and make sure the reusable window’s own action is the one that fires. The regression test passe

### transcript-2026-04-06-2-ReuseEmptyEditorIssue:segment-003 (lines 89-104)

Didn't fix the issue. It looks like once a document window is closed (without becoming key window) behind a new window it will always be opened in a new window. If I select different saved document to open then it will use the unused window, but then If I repeat a new window and close of the document window behind it, the behavior will be the same for that document. Create a UI test that reproduces the issue and then fix. I’m reproducing this in the existing window-routing code and UI test harness first so we can lock the failing sequence down before touching the coordinator again. I found the existing UI harness already has enough hooks to script this without new app-side test plumbing. I’m reading the launch/window helpers now so the new test can reliably pick the right windows and verify “reused existing empty window” versus “opened a brand-new one.” The symptom pattern points to a stale document-to-session association: same document path remembers a dead session and gets reopened as that stale session in a brand-new window, while a different document still uses the empty live window. I’m checking where window delegates and close notifications are wired, because that’s the likel

### transcript-2026-04-06-2-ReuseEmptyEditorIssue:segment-004 (lines 105-177)

[ interrupted agent ] Thats fine to use UI-test control hooks to close the window, but I wanted to make note that I closed the window without bringing forward by clicking in the close button. I’m using the control-hook route for the close step, and I’ll keep it faithful to what you described: it will close the specific background document window directly, without first making it key. After that I’ll run the UI sequence end to end and fix the actual stale-session path it exposes. I’ve got the reproduction shape: load FLAC, reuse an empty window for a .swifttag, open another empty window, close the document window in the background, then reopen the same document and assert the window count does not grow. I’m adding a UI-test-only control file that asks AppKit to performClose on the background document window by its document URL, without bringing it forward. I’ve added the control hook and the new UI regression for the exact close-behind-a-new-window sequence. I’m running that single UI test now to see the current failure mode before I touch the routing logic again. The UI test itself is in place; the current blocker is just the new control hook not compiling cleanly. I’m fixing that 

### transcript-2026-04-06-2-ReuseEmptyEditorIssue:segment-005 (lines 178-214)

The closeBackgroundUITestDocumentWindow function could be called using another something other than the DEBUG only menu button yes? Lets try to get that working as it would be preferable not to have that menu item in debug builds. I’m swapping the temporary debug menu hook for a direct test-only signal into the app, reusing the close logic that already works. Then I’ll rerun the focused UI/regression tests to make sure we keep the same behavior without exposing a menu item. I’ve got a cleaner path: keep the close behavior, but trigger it with a test-only distributed notification instead of a visible menu command. I’m wiring that in now and then rerunning the same focused tests so we know we didn’t regress the fix. The menu item is gone; the UI test now talks straight to the app through a hidden notification. I’m running the same build and focused tests to make sure the close path is still reliable. The hidden signal is wired, but the UI test is still failing on the same reopen assertion, which usually means the background close didn’t actually happen from the test process. I’m checking the exact failing line and then I’ll make the notification observer stricter so it definitely fir

### transcript-2026-04-06-2-ReuseEmptyEditorIssue:segment-006 (lines 215-218)

Not a deterministic fix, come back to later.

## Candidate Commits

- `0015089006f52550ef2f4ed4fdd0057bb9e521b9` — feat(ui): help menu now opens user docs (1.00; changed path mentioned, subject tokens: docs, menu, now, opens, user, path/topic overlap)
- `03227c22ec04d4a16f48e8159bca42426af9eac7` — fix(tags): treat total count aliases as equivalent (1.00; changed path mentioned, subject tokens: count, explicit, fallback, file, key, out, path/topic overlap)
- `0539816b5ba23a6e25ff44d6be08444b0f8dd6c7` — fix(album-art): reject oversized flac picture imports (1.00; changed path mentioned, subject tokens: button, cover, current, docs, file, flac, path/topic overlap)
- `063c138d4ad746588a85c0be70cc1c5c75854e87` — feat(applescript): expose diff tools settings (1.00; changed path mentioned, subject tokens: assert, assertions, behavior, branch, docs, harness, path/topic overlap)
- `0c2d38575541a8dada750da08698d78e75a4d3f0` — feat(applescript): support standard track tag scripting (1.00; changed path mentioned, subject tokens: docs, during, flac, implementation, model, script, path/topic overlap)
- `0c4e80ab485f4ddfd5292c23962ece5bce8ebb9d` — feat(toml​-ui): present ​TOML in sheet rather than utility window (1.00; changed path mentioned, subject tokens: present, rather, than, window, path/topic overlap)
- `1071c2e0ffd3bbc279f2cca6e15509e725518e25` — fix(flac): load files without Vorbis comment tags (1.00; changed path mentioned, subject tokens: empty, existing, failure, files, fixture, flac, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (1.00; changed path mentioned, subject tokens: cover, docs, editor, edits, flac, harness, path/topic overlap)
- `1276536d7ce542d757187ed8e2a7a229c6741847` — feat(package): add SwiftTag document creation and serialization (1.00; changed path mentioned, subject tokens: command, current, docs, document, editor, file, path/topic overlap, commit before transcript within 7d)
- `17b6c1045af4a5e5e2c465dded80f53ff5695df5` — feat(applescript): expose settings preferences (1.00; changed path mentioned, subject tokens: back, behavior, notification, save, script, tag, path/topic overlap)
- `19369540b1a2f92b3ab4fd1cedb4db7cefe41498` — fix(editor): preserve track title editing and queued finder opens (1.00; changed path mentioned, subject tokens: action, actor, after, already, bug, change, path/topic overlap)
- `1c2bb82cfcda4a8e4043b7e883e42928b18064cf` — feat(document): add support for opening .swifttag documents (1.00; changed path mentioned, subject tokens: command, coordinator, docs, document, documents, editor, path/topic overlap, commit before transcript within 3d)
- `2302109d0c43a41cb71c36e47cf2b4b8973a63d6` — Refine track metadata ​UI and import mapping for discs​/genres​/misc tags - add dictionary-backed handling for new explicit fields: DISC and GENRE - add Disc of total​Discs controls with selected-track binding and numeric validation - style total​Discs in bold red when non-empty TOTALDISCS tags mismatch entered value - add hover help messaging for total tracks/discs consistency indicators - convert total tracks display to read-only track-count text with mismatch highlighting and help (1.00; changed path mentioned, subject tokens: count, empty, explicit, import, mismatch, new, path/topic overlap)
- `24428a1548324e06268c9174e358e22e9559801b` — fix(applescript): support making tags from track tell contexts (1.00; changed path mentioned, subject tokens: action, after, bug, changes, clear, command, path/topic overlap)
- `25fde2c3d0c01acd97eb967b5903f6336c57b6ae` — fix(applescript): preserve picture IDs after deleting same-type pictures (1.00; changed path mentioned, subject tokens: after, attached, instead, only, reference, resolve, path/topic overlap)
- `27b32d888ac16fcaa31f6735b29d960131a8315c` — feat(save): add FLAC tag and picture writing workflow (1.00; changed path mentioned, subject tokens: app, behavior, both, commands, count, current, path/topic overlap)

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
