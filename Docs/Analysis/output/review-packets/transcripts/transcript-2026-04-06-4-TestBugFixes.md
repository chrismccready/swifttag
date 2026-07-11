# Transcript Review: transcript-2026-04-06-4-TestBugFixes

- Path: `Docs/Plans/Transcripts/transcript-2026-04-06-4-TestBugFixes.md`
- Content digest: `c3b951bdbbe608f312389fb1832bf41f2ff6d259860f9163cdf419e38d9dc7b6`
- Review-input digest: `3470802470127bdcb2777bef63c1d89281e765086d9006d1e4c9e6558ced73c9`
- Current status: `reviewed`

## Base Segments

### transcript-2026-04-06-4-TestBugFixes:segment-001 (lines 12-37)

Fix `testFinderOpenQueuesFilesUntilNewSessionRegistersHandler`. I’m reproducing that specific coordinator test first and then tracing the pending-file bootstrap path around it so we can fix the failure at the right seam instead of papering over it. The failure is clear now: inactive Finder opens are currently treated as “bootstrap later” whenever no sessions are registered, even if the app already has an open-window action ready to create a new editor immediately. I’m checking the neighboring tests to preserve the intended bootstrapping case while making this queued-new-session case work again. I found the behavioral split: “inactive and no registered sessions” is serving two different cases right now. For launch/bootstrap there really is nowhere to open yet, but in this test there is already an open-window action available, so we should create the new editor immediately and queue the files on that session. I’ve patched the coordinator so bootstrap queuing only happens when there truly isn’t any window-opening action available yet. I’m rerunning the failing test plus the neighboring bootstrap case to make sure we fixed the regression without breaking launch-time Finder opens. The f

### transcript-2026-04-06-4-TestBugFixes:segment-002 (lines 38-81)

First text change applied to track name in tracks table causes a loss of focus on track name editing. Create a UI test that confirms the issue and fix. I’m tracing the track-name editing flow and the existing UI-test harness first so we can capture the focus-loss bug in a failing test before touching the view code. After that I’ll patch the editor state handling and rerun a focused UI pass. I found the likely hotspot: the track table’s Title column is using inline TextFields inside a sorted Table, and there’s no explicit focus or stable edit identity there right now. I’m reading that view and the title-binding path next, because this kind of “first edit kicks you out” usually comes from row identity or resort/rebuild behavior after the first mutation. I’ve got a stronger suspect now: the track table view is wrapped in .id(statusRefreshID), which forces SwiftUI to recreate the entire Table whenever that refresh token changes. If the token changes after the first title mutation, that would explain an immediate focus drop even though the row itself didn’t move. I’m tracing where statusRefreshID is computed and whether title edits currently tick it. Plan: 1. Add a focused UI regression

### transcript-2026-04-06-4-TestBugFixes:segment-003 (lines 82-106)

Fix `Extra argument 'statusRefreshID' in call` error in tests. I’m searching for the remaining TagEditorTrackFileView call sites now, because that error means one of them still passes the old statusRefreshID argument after the initializer change. I found the stale calls: they’re all in TrackStatusViewInspectorTests.swift, still constructing TagEditorTrackFileView with the removed statusRefreshID parameter. I’m updating those initializers now and then I’ll rerun a focused build/tests pass. I found one more thing beyond the initializer arguments: one inspector test also asserts inspectedView.statusRefreshID, which no longer exists. I’m removing both the stale arguments and that dead assertion in one pass. The stale test API usage is patched. I’m running a focused build plus the affected inspector tests now to make sure we cleared the compile/runtime fallout cleanly. Fixed the stale test call sites in [TrackStatusViewInspectorTests.swift](Swift/SwiftTag/SwiftTagTests/TrackStatusViewInspectorTests.swift) by removing the old `statusRefreshID` argument from `TagEditorTrackFileView` construction, and I removed the dead assertion that inspected `statusRefreshID` directly. Verification: `Bu

### transcript-2026-04-06-4-TestBugFixes:segment-004 (lines 107-128)

Fix Warning on line 313 of SwiftTagDocumentTests. I’m checking the warning at that exact test location first so we can make the smallest safe fix and verify it doesn’t hide anything else nearby. The file-level diagnostics are clean in the current build, so this looks like one of those source warnings Xcode can show from a specific expression shape rather than a failing compile. I’m reading the local test setup around sharedPicture next so I can target the exact expression on line 313. I’ve narrowed it to that array-equality assertion. Since the file builds cleanly, this is likely the expression shape Xcode dislikes rather than a behavioral problem, so I’m switching it to smaller, explicit checks against the first picture and count. I confirmed FlacWritablePictureRecord is already Equatable, so we can keep the same intent while breaking the expression into simpler expectations. I’m patching that test now to compare count plus the first loaded picture explicitly. The warning-prone assertion is split now. I’m doing a quick build plus the nearby document reader test so we know the behavior is unchanged and the test still reads cleanly. Updated [SwiftTagDocumentTests.swift](Swift/SwiftT

### transcript-2026-04-06-4-TestBugFixes:segment-005 (lines 129-148)

The warning: `Main actor-isolated conformance of 'FlacWritablePictureRecord' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode` is still there. I’m tracing that specific actor-isolation warning at the type level now, because the issue is likely the Equatable conformance itself rather than the test expression we just changed. After that I’ll patch the model declaration and rerun a focused build/test check. The warning is coming from using Equatable on FlacWritablePictureRecord in the test, not from the reader behavior itself. I’m removing that protocol-based comparison entirely and switching the test to field-by-field expectations so the warning goes away without changing the model’s concurrency surface. I’ve removed the last Equatable use from that test. I’m rebuilding with warnings surfaced and rerunning the document test so we can confirm the actor-isolation warning is actually gone now. The warning is gone now. The build log is clean for SwiftTagDocumentTests, and the round-trip reader test still passes with the explicit field checks. Updated [SwiftTagDocumentTests.swift](Swift/SwiftTag/SwiftTagTests/SwiftTagDocumentTests.swift) 

## Candidate Commits

- `0539816b5ba23a6e25ff44d6be08444b0f8dd6c7` — fix(album-art): reject oversized flac picture imports (1.00; changed path mentioned, subject tokens: current, docs, drop, file, flac, flow, path/topic overlap)
- `063c138d4ad746588a85c0be70cc1c5c75854e87` — feat(applescript): expose diff tools settings (1.00; changed path mentioned, subject tokens: behavior, branch, coverage, diff, docs, harness, path/topic overlap)
- `0c2d38575541a8dada750da08698d78e75a4d3f0` — feat(applescript): support standard track tag scripting (1.00; changed path mentioned, subject tokens: docs, flac, lookup, model, related, replacement, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (1.00; changed path mentioned, subject tokens: docs, editor, edits, flac, harness, picture, path/topic overlap)
- `1276536d7ce542d757187ed8e2a7a229c6741847` — feat(package): add SwiftTag document creation and serialization (1.00; changed path mentioned, subject tokens: current, docs, document, editor, file, focused, path/topic overlap, commit before transcript within 7d)
- `17b6c1045af4a5e5e2c465dded80f53ff5695df5` — feat(applescript): expose settings preferences (1.00; changed path mentioned, subject tokens: back, behavior, coverage, diff, tag, user, path/topic overlap)
- `19369540b1a2f92b3ab4fd1cedb4db7cefe41498` — fix(editor): preserve track title editing and queued finder opens (1.00; archive provenance only, changed path mentioned, subject tokens: action, actor, after, already, argument, bug, path/topic overlap)
- `1c2bb82cfcda4a8e4043b7e883e42928b18064cf` — feat(document): add support for opening .swifttag documents (1.00; changed path mentioned, subject tokens: coordinator, docs, document, editor, existing, file, path/topic overlap, commit before transcript within 3d)
- `1e4ea8e60ed212c41a1f3f43a972ccad5855a07a` — feat(ui): track picture info overlay and navigation enhancements (1.00; changed path mentioned, subject tokens: picture, track, path/topic overlap)
- `2302109d0c43a41cb71c36e47cf2b4b8973a63d6` — Refine track metadata ​UI and import mapping for discs​/genres​/misc tags - add dictionary-backed handling for new explicit fields: DISC and GENRE - add Disc of total​Discs controls with selected-track binding and numeric validation - style total​Discs in bold red when non-empty TOTALDISCS tags mismatch entered value - add hover help messaging for total tracks/discs consistency indicators - convert total tracks display to read-only track-count text with mismatch highlighting and help (1.00; changed path mentioned, subject tokens: binding, count, explicit, fields, handling, new, path/topic overlap)
- `24428a1548324e06268c9174e358e22e9559801b` — fix(applescript): support making tags from track tell contexts (1.00; changed path mentioned, subject tokens: action, after, bug, changes, clear, context, path/topic overlap)
- `25fde2c3d0c01acd97eb967b5903f6336c57b6ae` — fix(applescript): preserve picture IDs after deleting same-type pictures (1.00; changed path mentioned, subject tokens: after, all, attached, coverage, instead, only, path/topic overlap)
- `27b32d888ac16fcaa31f6735b29d960131a8315c` — feat(save): add FLAC tag and picture writing workflow (1.00; changed path mentioned, subject tokens: app, behavior, both, count, coverage, current, path/topic overlap)
- `27b4d85ec22c4165acb415ef3929bd10d4c35202` — feat(save): add SwiftTag document follow-on save options (1.00; changed path mentioned, subject tokens: after, code, coverage, docs, document, flac, path/topic overlap)
- `29444d740b06ee147a5690f1070d56abfa8be162` — feat(tag-editor): add track file rename workflow (1.00; changed path mentioned, subject tokens: all, before, docs, editor, file, files, path/topic overlap)
- `2976159836a41160b0a462b26c952968c19a7923` — fix(applescript): refresh album-art state after picture imports (1.00; changed path mentioned, subject tokens: after, context, conversation, coverage, docs, icon, path/topic overlap)

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
