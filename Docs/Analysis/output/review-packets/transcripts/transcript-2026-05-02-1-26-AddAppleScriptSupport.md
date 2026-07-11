# Transcript Review: transcript-2026-05-02-1-26-AddAppleScriptSupport

- Path: `Docs/Plans/Transcripts/transcript-2026-05-02-1-26-AddAppleScriptSupport.md`
- Content digest: `c021a1364c47ca19050515ea9bbf607e250e6cfc57d41b2098828f030ef67993`
- Review-input digest: `688f8fed5c4b375482c70743e2984006934c0d694b491a5221e97b174480bcbe`
- Current status: `reviewed`

## Base Segments

### transcript-2026-05-02-1-26-AddAppleScriptSupport:segment-001 (lines 10-90)

1. Add to "SwiftTag Suite" "application" class of `SwiftTag.sdef` ```XML <property name="format on track to file diff" code="ftfd" type="boolean" access="rw" description="Perform text formatting on track to file diff (aka: Diff Tools: Format on Track to File Diff)."> <cocoa key="FormatOnTrackToFileDiffSetting"/> </property> <property name="format on track to track diff" code="fttd" type="boolean" access="rw" description="Perform text formatting on track to track diff (aka: Diff Tools: Format on Track to Track Diff)."> <cocoa key="FormatOnTrackToTrackDiffSetting"/> </property> <property name="format on externally modified diff" code="ftem" type="boolean" access="rw" description="Perform text formatting on externally modified diff (aka: Diff Tools: Format on Externally Modified Diff)."> <cocoa key="FormatOnExternallyModifiedDiffSetting"/> </property> <property name="format on track total mismatch" code="fttm" type="boolean" access="rw" description="Perform text formatting on track total mismatch (aka: Diff Tools: Format on Track Total Mismatch)."> <cocoa key="FormatOnTrackTotalMismatchSetting"/> </property> <property name="format on disc total mismatch" code="ftdm" type="boolean" acc

## Candidate Commits

- `063c138d4ad746588a85c0be70cc1c5c75854e87` — feat(applescript): expose diff tools settings (1.00; archive provenance only, changed path mentioned, subject tokens: accessibility, apple, application, assertions, behavior, defaults, path/topic overlap, commit before transcript within 1d)
- `0c2d38575541a8dada750da08698d78e75a4d3f0` — feat(applescript): support standard track tag scripting (1.00; changed path mentioned, subject tokens: access, apple, bridge, class, docs, expose, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (1.00; changed path mentioned, subject tokens: apple, cover, description, docs, edits, expose, path/topic overlap, commit before transcript within 7d)
- `17b6c1045af4a5e5e2c465dded80f53ff5695df5` — feat(applescript): expose settings preferences (1.00; changed path mentioned, subject tokens: apple, application, behavior, bridge, codes, color, path/topic overlap, commit before transcript within 3d)
- `192eaacabaecbe09ee3ee59d935f0d3ab2d86a02` — feat(applescript): initial AppleScript support (1.00; changed path mentioned, subject tokens: app, apple, docs, script, path/topic overlap)
- `1b08404c005806083a5443603d98c10c5510ee70` — feat(applescript): model color settings as records (1.00; changed path mentioned, subject tokens: apple, change, class, color, disc, docs, path/topic overlap, commit before transcript within 1d)
- `24428a1548324e06268c9174e358e22e9559801b` — fix(applescript): support making tags from track tell contexts (1.00; changed path mentioned, subject tokens: accessibility, after, apple, docs, expose, first, path/topic overlap, commit before transcript within 7d)
- `25fde2c3d0c01acd97eb967b5903f6336c57b6ae` — fix(applescript): preserve picture IDs after deleting same-type pictures (1.00; changed path mentioned, subject tokens: after, apple, index, only, picture, reference, path/topic overlap)
- `2aee7213d2467ac765cf2f834b3e8b0a5409064e` — feat(settings): add duplicate picture overlay controls (1.00; changed path mentioned, subject tokens: 2026, color, defaults, diff, docs, duplicate, path/topic overlap)
- `2e24923ec49954fa4d4b17f56f3d26c10265a51b` — fix(applescript): support track file comparisons (1.00; changed path mentioned, subject tokens: access, expose, file, path, scripting, through, path/topic overlap)
- `32d8411d0d981716488a64b235fa1c25240b90ba` — feat(diff-tools): UI cleanup, theme setting now propagated to Diff Tools and Settings windows (1.00; changed path mentioned, subject tokens: diff, now, setting, settings, tools, path/topic overlap)
- `380be212ade022a481997efbb4051584360a9b92` — fix(applescript): return missing value for unavailable picture metrics (1.00; changed path mentioned, subject tokens: codes, color, cover, date, expose, picture, path/topic overlap)
- `3fd6771aa6fbbc5afe81722f5d39ce0c171019cd` — feat(applescript): add locked track support to scripting commands (1.00; changed path mentioned, subject tokens: apple, bridge, docs, existing, expose, implementation, path/topic overlap)
- `43b64835145b64f3346d6298de67754019b36df8` — feat(applescript): support deleting tracks from editor windows (1.00; changed path mentioned, subject tokens: bridge, date, description, docs, script, scripting, path/topic overlap)
- `46a24e9e98968ea9d3bfa50853be92e35d857f8e` — fix(applescript): expose tag IDs for key-filtered references (1.00; changed path mentioned, subject tokens: apple, cover, expose, first, key, lookup, path/topic overlap, commit before transcript within 7d)
- `546e43d639eb9d7eceb46aa966b8a592b187b12c` — feat(applescript): support selected tracks and track list filtering (1.00; changed path mentioned, subject tokens: apple, application, docs, expose, harness, list, path/topic overlap)

## Candidate Plans

- Plan `26` — Add AppleScript Support Plan

## Candidate Themes

- `applescript` — AppleScript
- `diff` — Diff
- `picture` — Picture
- `project` — Project
- `save` — Save
- `settings` — Settings
- `swifttag-document` — SwiftTag Document
- `tags` — Tags
