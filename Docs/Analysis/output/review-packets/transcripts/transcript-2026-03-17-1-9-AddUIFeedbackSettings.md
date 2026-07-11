# Transcript Review: transcript-2026-03-17-1-9-AddUIFeedbackSettings

- Path: `Docs/Plans/Transcripts/transcript-2026-03-17-1-9-AddUIFeedbackSettings.md`
- Content digest: `f7b28b2330e960598a64fc7f392d5f79067090afd1cdc6042d08f3963bc47ce1`
- Review-input digest: `be84fc988722bb1bbca27d96bc40560ebfcb72275b0c1cc24f1f973e84d34eeb`
- Current status: `reviewed`

## Base Segments

### transcript-2026-03-17-1-9-AddUIFeedbackSettings:segment-001 (lines 12-67)

Create a plan to: Add UI Feedback Settings: - Update total tracks tag field logic so that it is user editable by converting totalTracks Text view to TextField view. - Move totalTracks of TagEditorCoreTagsView to Track struct so that totalTracks can differ between tracks. - Regardless of other color formatting rules, if the totalTracks Field value is mot the count a tracks then totalTracks TextEdit text should be red. - Move album from TagEditorViewModel to Track struct so that ALBUM can differ between tracks. - Move albumArtist from TagEditorViewModel to Track struct so that ALBUMARTIST can differ between tracks. - Add to SettingsView, following “Tags” tab, a TabView labeled “Feedback” - Add to Feedback tab a Picker labeled “Send Save Notifications” and segmented with “Always”, “When Not Frontmost”, “Never”. Default selection is “When Not Frontmost”. Use @AppStorage to save selection. - When “When Not Frontmost” is selected, the app will not send save notifications when the app is not frontmost. - When “Always” is selected, the app will always send save notifications when applicable. - When “Never” is selected, the app will never send save notifications. - Below the “Send Save Noti

### transcript-2026-03-17-1-9-AddUIFeedbackSettings:segment-002 (lines 68-103)

- For When Not Frontmost, notifications should be sent only when the app is not frontmost. - After moving album, albumArtist, and totalTracks onto Track, those top editor controls should edit only selected tracks. With the case of mixed selected values show a bold “*”. - Italic On File Diff should target both external file diff and internal cross-track diff. - If a field has both internal and external diff at once, which color/emphasis should win? - “How should the Diff Tools utility window be opened?” According to [Apple’s Documentation](https://developer.apple.com/documentation/swiftui/utilitywindow), the UtilityWindow will automatically add a menu item to show/hide itself in the “View” menu. We should confirm this behavior. - Per-tag toggles should cover the built-in visible tag editors and misc tags. To handle the variability of Misc tags, create a toggle at the bottom of all the per-tag toggles labeled Misc that will apply the diff formatting On/Off for any/all misc tags, this toggle should be enabled/disabled by the “Italic On File Diff” toggle. - Also, source track files that have no value for a given tag, in terms of formatting, are not to be considered different. I’m updat

### transcript-2026-03-17-1-9-AddUIFeedbackSettings:segment-003 (lines 104-117)

- If a field has both an internal diff and an external diff at the same time, then the external diff formatting takes precedence. I’m applying that final precedence decision to the plan so the open questions section can be cleared. I’ve applied the final decision and removed the last open question from the plan. I’m doing one quick read-back, then I’ll close with the updated status. The plan is fully updated in 9-AddUIFeedbackSettings.md. The final precedence rule is now explicit: when a field has both internal and external diff states, external diff formatting wins. The open questions section has been cleared. [ 2026-03-17T04:41:58Z (39s since Assistant start) ]

### transcript-2026-03-17-1-9-AddUIFeedbackSettings:segment-004 (lines 118-162)

Ok, start plan 9-AddUIFeedbackSettings.md implementation. I’m starting implementation from the plan and first mapping the concrete edit set across the model, settings, diff-style, and save-notification seams so the migration happens in one pass instead of leaving duplicate state behind. I’ve got the current tests and the save/diff call sites. Next I’m reading the view-model snapshot and save paths directly, because the per-track field migration has to update diff detection and write mapping together or it will break save gating. I’m adding the shared settings and diff-formatting infrastructure first so the later view/model edits can land against stable types instead of repeating raw UserDefaults logic everywhere. The shared settings types and diff-style modifier are in. I’m moving the per-track metadata into Track next and wiring import/write mapping to those stored values so the rest of the editor can bind against one source of truth. The view-model patch partly applied, but the trailing hunk missed the current footer shape. I’m reading the exact lower section and then I’ll land the migration/helpers in smaller chunks. I’m updating ContentView now to stop using the removed global 

## Candidate Commits

- `83083cbcdf9667c18e3a5c3c11c66d2cfa24f4a6` — plan(feedback): update plan to latest implemented state and add targeted settings diff tests (1.00; changed path mentioned, subject tokens: diff, feedback, settings, state, targeted, path/topic overlap)
- `94246bbd4bebc8a284577f2d68b82ff5db235599` — docs(transcript): 8-AddTrackStatusPlan.md finalization and introduction of ViewInspector (1.00; subject tokens: docs, inspector, status, track, transcript, view, path/topic overlap, commit before transcript within 1d)
- `ac28a73112d2a5170ee56f4f05fe6081f4376eb6` — feat(diff-tools): implement track/file diff states and mismatch warning customization (1.00; archive provenance only, changed path mentioned, subject tokens: apply, behavior, bindings, changes, color, content, path/topic overlap)
- `ae13badc1a2a880e7b374fa67010992d398fa737` — test(swiftui): add viewinspector coverage and read-only fixture ui-test support (0.93; subject tokens: album, behavior, can, content, docs, editor, path/topic overlap, commit before transcript within 7d)
- `c56695645a5579bac37f1f716650754ccc5750a1` — feat(track-status): add file-monitor-based track status and lock-aware tag editor behavior (0.93; subject tokens: album, behavior, change, detection, docs, editor, path/topic overlap, commit before transcript within 7d)
- `e0cd7da70c303f9524054cf6e150d7fbfca3d9d1` — feat(save-status): add save progress overlay and save-state UI guards (0.93; subject tokens: album, behavior, editor, final, implementation, per, path/topic overlap, commit before transcript within 7d)
- `fa93fee5de699542d9c5b51f16ffc9acac505d9c` — docs(transcripts): tighten transcript export rules and template (0.91; subject tokens: assistant, current, docs, file, metadata, one, path/topic overlap, commit before transcript within 7d)
- `03227c22ec04d4a16f48e8159bca42426af9eac7` — fix(tags): treat total count aliases as equivalent (0.85; subject tokens: count, differences, explicit, file, imported, key, path/topic overlap)
- `0539816b5ba23a6e25ff44d6be08444b0f8dd6c7` — fix(album-art): reject oversized flac picture imports (0.85; subject tokens: album, bindings, cover, current, docs, file, path/topic overlap)
- `063c138d4ad746588a85c0be70cc1c5c75854e87` — feat(applescript): expose diff tools settings (0.85; subject tokens: apple, backed, behavior, defaults, diff, docs, path/topic overlap)
- `0c2d38575541a8dada750da08698d78e75a4d3f0` — feat(applescript): support standard track tag scripting (0.85; subject tokens: apple, class, docs, errors, flac, implementation, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (0.85; subject tokens: album, apple, cover, docs, editor, edits, path/topic overlap)
- `1276536d7ce542d757187ed8e2a7a229c6741847` — feat(package): add SwiftTag document creation and serialization (0.85; subject tokens: current, differences, docs, editor, file, focused, path/topic overlap)
- `19369540b1a2f92b3ab4fd1cedb4db7cefe41498` — fix(editor): preserve track title editing and queued finder opens (0.85; subject tokens: after, already, change, create, docs, editing, path/topic overlap)
- `1b08404c005806083a5443603d98c10c5510ee70` — feat(applescript): model color settings as records (0.85; subject tokens: apple, change, class, color, docs, implementation, path/topic overlap)
- `1c2bb82cfcda4a8e4043b7e883e42928b18064cf` — feat(document): add support for opening .swifttag documents (0.85; subject tokens: coordinator, docs, editable, editor, existing, file, path/topic overlap)

## Candidate Plans

- Plan `9` — Add UI Feedback Settings Plan

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
