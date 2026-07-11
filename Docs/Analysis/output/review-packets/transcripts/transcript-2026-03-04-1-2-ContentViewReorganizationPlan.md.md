# Transcript Review: transcript-2026-03-04-1-2-ContentViewReorganizationPlan.md

- Path: `Docs/Plans/Transcripts/transcript-2026-03-04-1-2-ContentViewReorganizationPlan.md.md`
- Content digest: `fc2f5046c96b2bac9afc96164eb2dd4669f8199cf0a8229fc89c412b914d85fa`
- Review-input digest: `87a62e9c43d3bd5faddd66e410ea847e9a8c2aac535da81a9e2271d2a8f57987`
- Current status: `reviewed`

## Base Segments

### transcript-2026-03-04-1-2-ContentViewReorganizationPlan.md:segment-001 (lines 12-50)

ContentView.swift is getting large. I think it may be time to reorganize the project. What project organization suggestions do you have that would be idiomatic of SwiftUI projects. Before anything is implemented, write to a file at SwiftTag/Docs (where FLACBridgeExecution.md is located) a plan with adding tests including SwiftUI tests on the current code at the top of that plan. Wrote the requested plan file here: - ContentViewReorganizationPlan.md Project organization suggestions that are idiomatic for SwiftUI (and reflected in that plan): 1. Organize by feature first (Features/TagEditor, Features/AlbumArt, Features/FlacImport) instead of by file type. 2. Keep ContentView thin and move mutable editor state/commands into a @MainActor view model. 3. Extract pure logic (tag normalization, date parsing/formatting, validation) into Shared/Utilities so it is unit-testable. 4. Move domain models (Track, TagKey, MiscTagRow) into Shared/Models and keep them UI-agnostic. 5. Use SwiftTagUITests for end-to-end SwiftUI behavior and SwiftTagTests (Testing framework) for logic-level tests, with a test-first migration gate before each refactor phase. I have added a file named test.flac at SwiftTa

### transcript-2026-03-04-1-2-ContentViewReorganizationPlan.md:segment-002 (lines 51-221)

Ok, execute plan Implemented the first execution slice of the plan (test-first + low-risk extraction), and updated the plan doc with fixture-observed behavior. What I changed: 1. Updated plan doc with fixture behavior correction: - ContentViewReorganizationPlan.md - TOTALDISCS expectation now reflects observed bridge output ("1" for current test.flac). 2. Extracted shared models/utilities out of ContentView: - Track.swift - MiscTagRow.swift - TagKey.swift - DateTagFormatter.swift - TagNormalization.swift 3. Extracted FLAC mapping logic: - FlacImportMapper.swift 4. Refactored ContentView to use extracted logic: - ContentView.swift - Replaced inline FLAC mapping with FlacImportMapper. - Replaced inline date parsing/formatting with DateTagFormatter. - Replaced explicit-key logic with TagNormalization. - Added deterministic UI-test import hook via UITEST_FLAC_PATH. 5. Added fixture-backed unit and UI tests: - SwiftTagTests.swift - SwiftTagUITests.swift Validation run - Build: BuildProject succeeded. - Unit tests (new 4): passed (4/4). - UI spot checks: - testFlacFixtureImportBindsExpectedValues() passed. - testMiscTagsAddAndDeleteRow() passed. Note: bulk UI test runs via MCP timed out 

### transcript-2026-03-04-1-2-ContentViewReorganizationPlan.md:segment-003 (lines 222-245)

Create a plan to implement getting all pictures from imported flac files, assigning the first found image of type 3, front cover, to TagEditorAlbumView’s AlbumArtWellView and storing images associated with tracks matching flac picture type to albumArtTypes.number. Perhaps refactor albumArtTypes so that it contains a data structure holding flac picture type and description replacing the current number field (feel free to refactor as needed). Write plan to a file in Docs/Plans folder. What Changed: - Plan created at /Docs/Plans/FlacPictureImportAlbumArtPlan.md - Refactored album-art typing from number to explicit FLAC metadata in SwiftTag/Features/AlbumArt/AlbumArtTypes.swift:29. - Updated albumArtTypes definitions to use flacPictureType/flacDescription in SwiftTag/ContentView.swift:13. - Added C bridge picture APIs/structs (FlacPicture, FlacPictureResult, read/free functions) in SwiftTag/FLACBridge/include/FlacMetadataBridge.h:21 and SwiftTag/FLACBridge/src/FlacMetadataBridge.c:170. - Extended Swift metadata service to return tags + pictures (FlacPictureRecord) in SwiftTag/FlacMetadataService.swift:14. - Added picture-type mapping helper (first per type) in SwiftTag/Features/FlacImp

## Candidate Commits

- `03227c22ec04d4a16f48e8159bca42426af9eac7` — fix(tags): treat total count aliases as equivalent (1.00; changed path mentioned, subject tokens: explicit, file, imported, include, key, misc, path/topic overlap)
- `0539816b5ba23a6e25ff44d6be08444b0f8dd6c7` — fix(album-art): reject oversized flac picture imports (1.00; changed path mentioned, subject tokens: album, art, bindings, cover, current, data, path/topic overlap)
- `0c2d38575541a8dada750da08698d78e75a4d3f0` — feat(applescript): support standard track tag scripting (1.00; changed path mentioned, subject tokens: bridge, delete, docs, during, flac, model, path/topic overlap)
- `1071c2e0ffd3bbc279f2cca6e15509e725518e25` — fix(flac): load files without Vorbis comment tags (1.00; changed path mentioned, subject tokens: blocks, bridge, coverage, files, fixture, flac, path/topic overlap)
- `11ba78598b25840b5e415e7410b8df4b75c964c5` — feat(applescript): expose FLAC pictures to scripts (1.00; changed path mentioned, subject tokens: album, art, cover, description, docs, editor, path/topic overlap)
- `126cc0a4b597443b882c65566c53e996d2cc62d2` — fix(tag-editor): preserve picture spec mismatches in save checks (1.00; changed path mentioned, subject tokens: behavior, checks, editor, export, image, keep, path/topic overlap)
- `1276536d7ce542d757187ed8e2a7a229c6741847` — feat(package): add SwiftTag document creation and serialization (1.00; changed path mentioned, subject tokens: command, current, data, docs, editor, file, path/topic overlap)
- `19369540b1a2f92b3ab4fd1cedb4db7cefe41498` — fix(editor): preserve track title editing and queued finder opens (1.00; changed path mentioned, subject tokens: actor, create, docs, editor, field, fields, path/topic overlap)
- `1c2bb82cfcda4a8e4043b7e883e42928b18064cf` — feat(document): add support for opening .swifttag documents (1.00; changed path mentioned, subject tokens: command, coordinator, docs, editor, file, import, path/topic overlap)
- `1e4ea8e60ed212c41a1f3f43a972ccad5855a07a` — feat(ui): track picture info overlay and navigation enhancements (1.00; changed path mentioned, subject tokens: navigation, picture, track, path/topic overlap)
- `1fcd08274065e59e148cb05d16e592e98f02bced` — Build ​FLAC from source and link as stais lib • configure FLAC CMake build for app use:    • static lib only (BUILD​_​SHARED​_​LIBS​=​OFF)    • disable programs (BUILD​_​PROGRAMS​=​OFF)    • disable C++ lib (BUILD​_​CXXLIBS​=​OFF)    • disable Ogg dependency (WITH​_​OGG​=​OFF) • remove dependency on bundled prebuilt Resources​/bin FLAC/metaflac artifacts (1.00; changed path mentioned, subject tokens: build, flac, shared, path/topic overlap, commit before transcript within 7d)
- `2298c43c00492de67ad920a395d3ec7a8c8fb722` — feat(applescript): update tag normalization to invalidate white space contents (1.00; changed path mentioned, subject tokens: docs, normalization, tag, transcript, path/topic overlap)
- `2302109d0c43a41cb71c36e47cf2b4b8973a63d6` — Refine track metadata ​UI and import mapping for discs​/genres​/misc tags - add dictionary-backed handling for new explicit fields: DISC and GENRE - add Disc of total​Discs controls with selected-track binding and numeric validation - style total​Discs in bold red when non-empty TOTALDISCS tags mismatch entered value - add hover help messaging for total tracks/discs consistency indicators - convert total tracks display to read-only track-count text with mismatch highlighting and help (1.00; changed path mentioned, subject tokens: backed, binding, discs, explicit, fields, genre, path/topic overlap, commit before transcript within 3d)
- `24428a1548324e06268c9174e358e22e9559801b` — fix(applescript): support making tags from track tell contexts (1.00; changed path mentioned, subject tokens: command, coverage, create, data, docs, field, path/topic overlap)
- `25fde2c3d0c01acd97eb967b5903f6336c57b6ae` — fix(applescript): preserve picture IDs after deleting same-type pictures (1.00; changed path mentioned, subject tokens: album, all, art, coverage, instead, picture, path/topic overlap)
- `27b32d888ac16fcaa31f6735b29d960131a8315c` — feat(save): add FLAC tag and picture writing workflow (1.00; changed path mentioned, subject tokens: actions, behavior, bridge, commands, coverage, current, path/topic overlap)

## Candidate Plans

- Plan `2` — ContentView Reorganization Plan

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
