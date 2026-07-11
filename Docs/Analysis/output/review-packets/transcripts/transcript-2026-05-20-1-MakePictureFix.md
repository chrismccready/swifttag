# Transcript Review: transcript-2026-05-20-1-MakePictureFix

- Path: `Docs/Plans/Transcripts/transcript-2026-05-20-1-MakePictureFix.md`
- Content digest: `9d4b25ef4a4d3d0b37d883cb7150a53ae8b32cc3547430ba107acda8a61c0e56`
- Review-input digest: `f623e9e4909b1a2aefa55b7b60d326e959709b7972e34a0b447bcef06783b6ba`
- Current status: `reviewed`

## Base Segments

### transcript-2026-05-20-1-MakePictureFix:segment-001 (lines 10-89)

The following AppleScript will fail with `execution error: SwiftTag got an error: Can’t make class picture. (-2710)`: ```applescript on run set testPNGData to "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO3ZbZ0AAAAASUVORK5CYII=" tell application "SwiftTag" tell firstTrack set newLeafletPicture to make new picture with properties {data:testPNGData, picture type:leaflet, description:"New Leaflet"} end tell end tell end run ``` The error is currently expected as there have been issues with AppleScript handling binary data and typing (consequently there is a custom command `import picture` in place to handle the failure of `make`). I just want to confirm/deny that if the above `make` is used where the `data` property can be known (or forced) to be a base64 encoded string that `make` will not work. It would be preferable to get `make with properties` to work for the `picture` class. Add tests including UI tests as needed. Use Apple Docs Scout agent to review Apple’s AppleScript documentation to confirm use of latest technology, coding patterns, etc. Ask questions for clarification as needed. Using project docs + Apple docs path first. Need inspect AppleScript ob

### transcript-2026-05-20-1-MakePictureFix:segment-002 (lines 90-134)

Now that `make` command works for pictures, remove custom `import picture` command definition in [SwiftTag.sdef](SwiftTag/SwiftTag.sdef) and application code support for it (scripting bridge, tests, user documentation, etc.). Need cut out import picture cleanly now that make picture owns path. First map command surface, tests, docs hits. Need replace tests rather than delete coverage: existing import tests become make new picture tests for duplicate, delete, status restore. Historical transcript docs stay untouched unless active user docs require update. [ Context automatically compacted ] Code already shaped for standard make. Removing old custom AppleScript hook now: sdef command, bridge plumbing, tests, docs. Search shows old command lives in sdef, one command subclass, track/application handlers, scenario tests, generated user docs, and two implementation plans. Editing those now; transcript archive left untouched. Apple docs check done through Xcode docs. NSCreateCommand maps to AppleScript make; docs say properties from with properties are set via setScriptingProperties, so standard command path now fits. Tests moving from custom verb to standard make new picture with propert

## Candidate Commits

- `063c138d4ad746588a85c0be70cc1c5c75854e87` — feat(applescript): expose diff tools settings (1.00; changed path mentioned, subject tokens: apple, applescript, application, assertions, behavior, coverage, path/topic overlap)
- `0c2d38575541a8dada750da08698d78e75a4d3f0` — feat(applescript): support standard track tag scripting (1.00; changed path mentioned, subject tokens: apple, applescript, bridge, class, delete, deletion, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (1.00; changed path mentioned, subject tokens: apple, applescript, description, descriptors, docs, edits, path/topic overlap)
- `17b6c1045af4a5e5e2c465dded80f53ff5695df5` — feat(applescript): expose settings preferences (1.00; changed path mentioned, subject tokens: apple, applescript, application, back, behavior, bridge, path/topic overlap)
- `192eaacabaecbe09ee3ee59d935f0d3ab2d86a02` — feat(applescript): initial AppleScript support (1.00; changed path mentioned, subject tokens: app, apple, applescript, docs, make, script, path/topic overlap)
- `1b08404c005806083a5443603d98c10c5510ee70` — feat(applescript): model color settings as records (1.00; changed path mentioned, subject tokens: accept, apple, applescript, class, descriptors, docs, path/topic overlap)
- `2298c43c00492de67ad920a395d3ec7a8c8fb722` — feat(applescript): update tag normalization to invalidate white space contents (1.00; changed path mentioned, subject tokens: applescript, contents, docs, tag, transcript, path/topic overlap)
- `24428a1548324e06268c9174e358e22e9559801b` — fix(applescript): support making tags from track tell contexts (1.00; changed path mentioned, subject tokens: apple, applescript, bug, clear, command, context, path/topic overlap)
- `25fde2c3d0c01acd97eb967b5903f6336c57b6ae` — fix(applescript): preserve picture IDs after deleting same-type pictures (1.00; changed path mentioned, subject tokens: apple, applescript, attached, coverage, deleted, deletion, path/topic overlap)
- `2e24923ec49954fa4d4b17f56f3d26c10265a51b` — fix(applescript): support track file comparisons (1.00; changed path mentioned, subject tokens: applescript, coverage, descriptor, descriptors, expose, file, path/topic overlap)
- `380be212ade022a481997efbb4051584360a9b92` — fix(applescript): return missing value for unavailable picture metrics (1.00; changed path mentioned, subject tokens: allow, applescript, date, descriptors, expose, missing, path/topic overlap)
- `3fd6771aa6fbbc5afe81722f5d39ce0c171019cd` — feat(applescript): add locked track support to scripting commands (1.00; changed path mentioned, subject tokens: apple, applescript, bridge, command, coverage, default, path/topic overlap)
- `43b64835145b64f3346d6298de67754019b36df8` — feat(applescript): support deleting tracks from editor windows (1.00; changed path mentioned, subject tokens: applescript, bridge, coverage, date, delete, deletion, path/topic overlap)
- `46a24e9e98968ea9d3bfa50853be92e35d857f8e` — fix(applescript): expose tag IDs for key-filtered references (1.00; changed path mentioned, subject tokens: apple, applescript, expose, first, key, lookup, path/topic overlap)
- `546e43d639eb9d7eceb46aa966b8a592b187b12c` — feat(applescript): support selected tracks and track list filtering (1.00; changed path mentioned, subject tokens: apple, applescript, application, back, coverage, docs, path/topic overlap)
- `5944288d9bd94e8186dd374b0aec6090ad90fc96` — docs(user): applescript make and import picture examples update (1.00; subject tokens: applescript, docs, import, make, picture, user, path/topic overlap, commit before transcript within 1d)

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
- `user-docs` — User Docs
