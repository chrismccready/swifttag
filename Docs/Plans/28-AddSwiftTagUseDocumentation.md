# Add SwiftTag Use Documentation Plan

## Goal

Add user-facing HTML documentation for SwiftTag that opens with a Quick Start for basic app use and links to deeper reference material, workflows, examples, and AppleScript automation guidance.

The documentation should help a new user answer:

- How do I add FLAC files and edit common tags?
- How do I edit album-level data, track-level data, misc tags, and album art?
- What is saved by Save, Save Tags, Save Pictures, and Save SwiftTag Document?
- What do status icons, locked tracks, external changes, and settings mean?
- How do I automate SwiftTag through AppleScript?
- Where are concrete examples for common use cases?

## Scope

### In Scope

- Create a static HTML documentation source tree for SwiftTag user documentation.
- Add a Quick Start as the first entry point.
- Add deeper pages linked from Quick Start for:
  - adding and replacing FLAC files
  - editing album, core, track, and misc tags
  - managing album art and picture records
  - saving FLAC metadata and saving `.swifttag` documents
  - understanding settings, status icons, diffs, and locked tracks
  - using TOML preview and Quick Look where relevant
  - AppleScript automation
  - examples and use cases
  - troubleshooting
- Keep pages static, local, and dependency-free so they can work in a browser and in macOS Help Viewer.
- Add local cross-links, stable anchors, and copy-friendly code blocks.
- Include AppleScript examples backed by current `SwiftTag.sdef`, tests, and transcript findings.
- Add verification for links, anchors, required pages, required examples, and app bundling if Help Book integration is implemented.
- Integrate docs into app Help if chosen during implementation, using standard macOS Help Book bundle keys.

### Out Of Scope

- Redesigning SwiftTag UI.
- Changing FLAC import, writeback, `.swifttag`, or AppleScript behavior.
- Replacing existing developer docs or plans.
- Adding hosted website deployment.
- Adding localization.
- Rewriting historical transcripts into user docs.
- Documenting provisional or obsolete files such as `Docs/Plans/_SwiftTag.sdef`.

## Plan Input Checklist Coverage

- Latest numbered plan reviewed:
  - `Docs/Plans/27-TrackTagsRefactor.md`
- Relevant plans reviewed:
  - `Docs/Plans/26-AddAppleScriptSupport.md`
  - `Docs/Plans/25-AddPictureDescriptionEdit.md`
  - `Docs/Plans/23-AddSwiftTagDocumentQuickLook.md`
  - `Docs/Plans/22-AddSwiftTagDocumentSaveOptions.md`
- Relevant guides reviewed:
  - `Docs/Guides/testing-guide.md`
  - `Docs/Guides/git-commit-message-guide.md`
- Existing documentation reviewed:
  - `Docs/README.md`
  - generated Apple documentation index presence under `Docs/AppleDocsIndex/Generated`
- App implementation reviewed:
  - `SwiftTag/SwiftTagApp.swift`
  - `SwiftTag/ContentView.swift`
  - `SwiftTag/Info.plist`
  - `SwiftTag/SwiftTag.sdef`
  - `SwiftTag/Features/TagEditor/*`
  - `SwiftTag/Features/AlbumArt/*`
  - `SwiftTag/Features/Settings/*`
  - `SwiftTag/Features/FlacImport/*`
  - `SwiftTag/Features/SwiftTagDocument/*`
  - `SwiftTag/Shared/Models/*`
- Tests reviewed:
  - Active test plan exposes 410 enabled tests.
  - Unit tests cover FLAC import/write mapping, settings, document packages, status/diff behavior, Quick Look, and AppleScript bridge model behavior.
  - UI tests cover app workflows, settings, save flow, album art, document behavior, and AppleScript harness flows.
- Transcripts reviewed:
  - AppleScript support transcripts in `Docs/Plans/Transcripts` were inspected because this task explicitly asked for transcript review.
  - Key findings came from transcripts around selected tracks, picture IDs, settings windows, `whose its file is ...`, Base64 picture creation, empty tag values, and sandbox-limited external `osascript`.
- Apple documentation lookup:
  - Xcode Documentation Search found Bundle Resources keys `CFBundleHelpBookName`, `CFBundleHelpBookFolder`, `CFAppleHelpAnchor`.
  - Xcode Documentation Search found `NSHelpManager` as AppKit help-display API.
  - Local generated index did not provide richer Help Book guidance beyond general HTML/WebKit records.
- Fixture review:
  - This plan does not add FLAC write behavior.
  - Implementation examples and optional AppleScript smoke checks can use copied fixtures from `SwiftTagTestFiles`, especially `test.flac`, without modifying originals.

## Current Implementation Snapshot

### App Workflows

- App opens with an editor window.
- Users add FLAC files through menu commands, file import panels, drag/drop, or AppleScript.
- Import can append to existing tracks or replace current tracks.
- Import can use read-only lock mode so tracks do not write back accidentally.
- Editor surface combines:
  - Album fields
  - Track table
  - Core tag fields
  - Misc tag table
  - Album art browser and front-cover image well
  - Save status and notification feedback
- Track rows expose status icons, track number, title, duration/fingerprint columns when enabled, filename, and context menu actions.
- Selected tracks are the source of truth for selection-scoped edits and saves.
- Locked tracks block writeback.
- External file changes and internal/external diffs are tracked and surfaced by status/diff UI.

### Menu And Command Surface

Current user-visible commands include:

- Add FLAC files...
- Add FLAC files (replace existing)...
- Add FLAC files (read-only)...
- Add FLAC files (read-only)(replace existing)...
- Open SwiftTag Document...
- Close Window
- Toggle Selected Tracks Lock
- Set Track Total
- Reload Selected Tracks
- Remove Selected Tracks
- Show TOML...
- Show Picture Browser / Hide Picture Browser
- Save
- Save Tags
- Save Pictures
- Save SwiftTag Document...

Documentation must use current command names and describe alternate commands where they appear in menus.

### Tag Editing

- Album fields write album-level tags across track state.
- Track title and track number can be edited in the table.
- Core tags include artist, album artist, composer, conductor, genre, date, location, description, disc number/count, track number/count, and compilation.
- Misc tags allow custom key/value pairs.
- Empty values and deleted tags are distinct behavior in the model and in AppleScript.
- FLAC import maps common aliases and normalizes certain fields.
- FLAC writeback applies settings for zero padding, total tag key strategies, and compilation normalization.

### Album Art

- Album art supports FLAC picture records with type, MIME type, description, dimensions, color depth, color count, and data.
- Front cover is surfaced prominently in the album section.
- Picture browser supports more complete picture management.
- Settings control whether front cover or all pictures are applied to all tracks.
- Picture identity has stable IDs and pool IDs so repeated pictures can be tracked safely.
- Docs must distinguish picture type, picture data, picture description, and per-track versus shared album behavior.

### Saving And Documents

- `Save` writes FLAC metadata using current default save payload and save scope settings.
- `Save Tags` writes tag payload only.
- `Save Pictures` writes picture payload only.
- Save scope can be all tracks or selected tracks.
- `.swifttag` document save stores a package manifest, references to FLAC files, security-scoped bookmark data, tags, pictures, and document metadata.
- `.swifttag` document save is not the same operation as FLAC metadata writeback.
- Settings can ask whether to save a new `.swifttag` document after FLAC save.
- Settings can save referenced documents after FLAC save.

### Settings

- General settings include default save payload, default save scope, save referenced document, and ask-to-save-new-document behavior.
- Tags settings include zero-padding, total-track/disc key strategy, automatic track-total update, compilation propagation, and picture propagation.
- Feedback settings include save notifications, status theme, and diff color controls.
- Documentation should include defaults and describe impact before users save files.

### AppleScript Functionality

Current SDEF exposes:

- Standard app/document/window commands and elements.
- Application properties for settings and editor/settings windows.
- Editor window elements and properties, including tracks, document, selected tracks, and modified state.
- Track elements and many tag-backed properties.
- Tag elements with key and value.
- Picture elements with IDs, pool IDs, type, MIME type, description, dimensions, colors, and data.
- Commands:
  - `add`
  - `open settings window`
  - standard `save`, `delete`, `make`, `close`, and related commands
- Enumerations for:
  - save scope
  - save payload
  - picture type
  - settings choices
  - status themes and diff colors

Docs should treat `SwiftTag/SwiftTag.sdef` as the AppleScript source of truth.

## Documentation Review Findings

- `Docs/README.md` has useful developer-facing product notes but is not a complete user manual.
- There is no existing static HTML user documentation tree.
- `SwiftTag/Info.plist` currently enables AppleScript and points to `SwiftTag.sdef`, but no Help Book keys are present.
- AppleScript transcripts contain user-facing knowledge that should be distilled into stable docs:
  - `selected tracks` returns a list; scripts often need `item 1 of selected tracks`.
  - File comparisons in `whose` filters need syntax like `whose its file is POSIX file ...`.
  - Creating picture data is most reliable when using Base64 text converted through Foundation data.
  - `make new picture with properties {data:...}` is the supported picture creation path.
  - Setting a tag value to empty string is different from deleting the tag.
  - Picture IDs and pool IDs should be described separately.
  - Settings window can be opened and closed by AppleScript.
  - External `osascript` can hit sandbox/TCC limits during tests; user docs should focus on normal Script Editor or automation use, while developer notes can mention test harness constraints.

## Apple Documentation Review

- macOS Help Book integration uses bundle resource keys:
  - `CFBundleHelpBookName`
  - `CFBundleHelpBookFolder`
  - optional `CFAppleHelpAnchor`
- AppKit provides `NSHelpManager` for showing app help.
- Static HTML is compatible with Help Viewer expectations.
- JavaScript-heavy docs should be avoided for bundled app help.
- Local links and anchors must remain stable after resource bundling.

## Confirmed Decisions

- Plan file name is `Docs/Plans/28-AddSwiftTagUseDocumentation.md`.
- Documentation format is HTML.
- Documentation must start from a Quick Start for basic app use.
- Quick Start must link to deeper and more comprehensive pages.
- Examples and use cases are required.
- AppleScript functionality must be covered from current app code, SDEF, tests, plans, and transcripts.
- Historical transcripts are input material only; final user docs should be distilled, current, and task-oriented.

## Documentation Architecture

### Recommended Source Tree

Create:

```text
Docs/UserDocumentation/
  index.html
  quick-start.html
  workflows/
    adding-flac-files.html
    tags.html
    album-art.html
    saving.html
    swifttag-documents.html
    settings.html
    status-and-diffs.html
  automation/
    applescript.html
    applescript-examples.html
  examples/
    clean-up-album.html
    batch-edit-tags.html
    manage-cover-art.html
    re-tag-with-applescript.html
    create-session-document.html
  troubleshooting.html
  assets/
    swifttag-docs.css
```

If Help Book integration is implemented in the same change, bundle this tree or a copied build output as app resources under a stable Help Book folder name such as `SwiftTagHelp`.

### Navigation Requirements

- Every page includes:
  - SwiftTag documentation title
  - current section label
  - link to Quick Start
  - link to AppleScript documentation
  - link to Examples
  - link to Troubleshooting
- `index.html` should make Quick Start the primary path.
- Quick Start should link to deeper pages at each step.
- Deep pages should link back to relevant examples.
- AppleScript examples should link to exact concept pages where possible.
- Links should be relative so the docs work in browser, repository preview, and bundled Help Viewer.

### Style Requirements

- Use plain HTML and CSS.
- No external fonts, scripts, CDNs, or remote assets.
- Use readable page width, responsive layout, and accessible contrast.
- Use semantic headings and landmarks.
- Use code blocks with language labels.
- Use short callouts for destructive or writeback behavior.
- Keep visual design calm and utility-focused.

## Content Plan

### Index And Quick Start

Quick Start should cover:

1. Open SwiftTag.
2. Add FLAC files.
3. Select one or more tracks.
4. Edit album fields.
5. Edit track title, track number, core tags, and misc tags.
6. Add or change front cover art.
7. Review status icons and locked state.
8. Choose Save, Save Tags, Save Pictures, or Save SwiftTag Document.
9. Confirm successful save feedback.
10. Continue to deep pages for advanced cases.

Required Quick Start links:

- Add FLAC Files
- Edit Tags
- Manage Album Art
- Save Changes
- SwiftTag Documents
- Settings
- AppleScript
- Examples
- Troubleshooting

### Workflow Reference Pages

Add FLAC Files:

- Add versus replace behavior.
- Read-only import and locked tracks.
- Drag/drop behavior if documented from app UI.
- Folder/file behavior as supported by current importer.
- External file access expectations.

Edit Tags:

- Album section.
- Track table edits.
- Core tags.
- Misc tags.
- Multi-selection behavior.
- Empty value versus removed tag where user-visible.
- Track total and disc total behavior.
- Compilation behavior.

Album Art:

- Front cover quick edit.
- Picture browser.
- Picture type, MIME type, description, dimensions, and data.
- Per-track picture records.
- Settings that propagate cover art or all pictures.
- Difference between replacing a cover and adding additional picture records.

Save Changes:

- `Save`.
- `Save Tags`.
- `Save Pictures`.
- Save scope: selected tracks versus all tracks.
- Save payload: tags, pictures, tags and pictures.
- Locked tracks.
- File changes outside SwiftTag.
- Save notifications and status feedback.
- What existing data is preserved, replaced, and removed by each save type.

SwiftTag Documents:

- What a `.swifttag` package stores.
- Relationship to referenced FLAC files.
- Difference between saving FLAC metadata and saving the document.
- Security-scoped bookmarks at user level: files may need access if moved or unavailable.
- Quick Look behavior.
- When to use a `.swifttag` document as a session file.

Settings:

- General tab.
- Tags tab.
- Feedback tab.
- Defaults.
- Consequences of total key strategy choices.
- Consequences of propagation settings.
- Consequences of save referenced document settings.

Status And Diffs:

- Current status icons and what they mean.
- Locked state.
- Modified state.
- External differences.
- Duplicate picture or mismatch indicators where surfaced.
- Reload selected tracks.
- Remove selected tracks.

Troubleshooting:

- FLAC file missing, renamed, or moved.
- Cannot save due to lock state.
- Save affected more or fewer tracks than expected.
- Album art did not propagate as expected.
- AppleScript cannot find a track or file.
- AppleScript automation permission prompts.
- `.swifttag` document references unavailable files.

### AppleScript Documentation

AppleScript docs should be split into overview and examples.

Overview page:

- Enablement: SwiftTag is scriptable through AppleScript.
- Object model:
  - application
  - editor windows
  - settings windows
  - tracks
  - tags
  - pictures
  - documents
- Core command summary:
  - `add`
  - `save`
  - `make`
  - `delete`
  - `open settings window`
- Important properties:
  - `selected tracks`
  - `modified`
  - `locked`
  - `file`
  - `picture type`
  - `pool id`
  - default save settings
- Enumerations:
  - save scope
  - save payload
  - picture type
  - track/disc total key settings
  - feedback settings

Examples page:

- Add FLAC files to front editor window.
- Add FLAC files as locked/read-only.
- Select tracks.
- Read and set title, album, artist, album artist, track number, and genre.
- Create, update, empty, and delete misc tags.
- Save selected tracks with tags only.
- Save all tracks with tags and pictures.
- Create front cover art from Base64 data.
- List pictures and read picture IDs/pool IDs.
- Delete pictures by type or ID.
- Open and close settings window.
- Read and write default save settings.

AppleScript caveats:

- `selected tracks` is a list.
- Use `item 1 of selected tracks` before reading scalar track properties from a selection.
- Use `whose its file is POSIX file "/path/to/file.flac"` for file filters.
- Use `make new picture with properties {data:...}` for image data examples.
- Prefer Base64 text to pass binary picture data across AppleScript.
- Empty tag values and deleted tags are different operations.
- Save commands can write FLAC files; examples must make scope and payload explicit.

Representative example shapes:

```applescript
tell application "SwiftTag"
    set addedTracks to add POSIX file "/path/to/track.flac" to front editor window with lock false
end tell
```

```applescript
tell application "SwiftTag"
    tell front editor window
        set selected tracks to every track whose its file is POSIX file "/path/to/track.flac"
        set selectedTrack to item 1 of selected tracks
        set title of selectedTrack to "New Title"
    end tell
end tell
```

```applescript
tell application "SwiftTag"
    save front editor window with scope selected with payload tags only
end tell
```

## Example And Use Case Requirements

Add use cases that combine app UI steps with links to reference pages:

- Clean up a downloaded album:
  - add files
  - set album and album artist
  - correct track numbers
  - set total tracks
  - save tags
- Batch edit artist and genre across selected tracks.
- Add front and back cover art.
- Save pictures only after art edits.
- Use read-only import to inspect metadata without writeback.
- Save a `.swifttag` session before changing source FLAC files.
- Script a repeatable metadata cleanup through AppleScript.
- Script picture creation through AppleScript.
- Recover after source files were moved or externally edited.

## Dependencies And Constraints

- Static docs must remain valid when opened from the repository and from an app bundle.
- If docs are bundled, Xcode project/resource membership must include the documentation folder or generated output.
- If Help Book is bundled, `Info.plist` needs Help Book keys and resource paths must match those keys.
- App Help integration may require AppKit bridging through `NSHelpManager` or a SwiftUI command that opens bundled docs.
- Current AppleScript source of truth is `SwiftTag/SwiftTag.sdef`.
- AppleScript examples must use terms supported by current SDEF and tested bridge behavior.
- Save examples must not hide writeback effects.
- Documentation should not depend on network access.
- Verification should avoid full UI suite unless needed.
- Developer-only testing limitations, such as sandboxed `osascript` in UI tests, should not dominate user docs.

## Destructive / Write-Back Documentation Requirements

The save documentation must explicitly state:

- Existing FLAC tags preserved by tag-only save.
- Existing FLAC pictures preserved by picture-only save.
- Tags that SwiftTag owns may be replaced or removed when saving tags.
- Pictures that SwiftTag owns may be replaced or removed when saving pictures.
- Locked tracks are skipped or protected according to current app behavior.
- Selected-track save uses current editor selection.
- All-track save applies to every loaded track eligible for saving.
- `.swifttag` document save stores session metadata and references; it does not by itself rewrite FLAC tags unless paired with FLAC save behavior.
- Picture propagation settings can cause an album-level art change to affect multiple tracks.

## High-Risk Concerns

### Product Or Behavioral Risks

- Docs may accidentally imply `Save` is always all tracks or always selected tracks; actual default depends on settings.
- Users may confuse `.swifttag` document save with FLAC metadata writeback.
- AppleScript examples may become stale if SDEF terms change.
- Picture docs may blur per-track pictures, front cover shortcut behavior, and shared picture pool identity.
- Examples may understate that scripts can write files.
- Quick Start may become too long and stop serving as a quick path.

### Tooling, Environment, Sandbox, Or Filesystem Risks

- Help Book resource folder may not be copied into app bundle correctly.
- Help Viewer may resolve anchors differently from a normal browser.
- Link verification may miss case-sensitive path issues.
- HTML validation tool may not be installed in local environment.
- AppleScript smoke checks may need automation permissions or gated harness behavior.
- Xcode build or targeted UI checks can time out.

## Implementation Phases

### Phase 1: Choose Docs Packaging

- Create `Docs/UserDocumentation` as source tree.
- Decide whether first implementation also bundles docs as app Help Book.
- If bundling:
  - choose resource folder name, recommended `SwiftTagHelp`
  - add Help Book keys to `SwiftTag/Info.plist`
  - add docs resources to SwiftTag app target
  - add or verify Help menu behavior
- Keep source files readable without generated build steps unless a copy step is necessary for bundle layout.

### Phase 2: Build Information Architecture

- Add `index.html` and page skeletons.
- Add shared stylesheet.
- Add top navigation and footer links.
- Add stable IDs for major sections.
- Add page titles and metadata.
- Ensure Quick Start is first page and primary entry.

### Phase 3: Write Basic App Use Docs

- Write Quick Start.
- Write adding FLAC files page.
- Write editing tags page.
- Write album art page.
- Write save behavior page.
- Include concrete menu command names and current settings terms.

### Phase 4: Write Advanced Workflow Docs

- Write `.swifttag` documents page.
- Write settings page.
- Write status and diffs page.
- Write troubleshooting page.
- Add use-case pages and cross-link each use case to reference pages.

### Phase 5: Write AppleScript Docs

- Extract public terms from `SwiftTag/SwiftTag.sdef`.
- Cross-check examples against AppleScript unit and UI tests.
- Distill transcript caveats into current guidance.
- Add command overview.
- Add object model overview.
- Add examples page.
- Add warnings around writeback, selection lists, file filters, and binary picture data.

### Phase 6: Add Help Book Integration If Included

- Add resource membership.
- Add `CFBundleHelpBookName` and `CFBundleHelpBookFolder` to `SwiftTag/Info.plist`.
- Add `CFAppleHelpAnchor` if a stable default anchor is needed.
- Add or adjust Help menu command only if the standard Help menu does not open the docs.
- Verify bundled resource paths.

### Phase 7: Verification

- Run static link and anchor verification.
- Verify every page links to Quick Start, Examples, AppleScript, and Troubleshooting.
- Verify required pages exist.
- Verify required examples exist.
- Verify AppleScript code blocks use supported SDEF terms.
- Run `BuildProject` if app resources or `Info.plist` changed.
- Run targeted tests only when app behavior or Help integration code changes.
- If Help Book integration is included, manually verify Help opens expected page in app bundle.

## Test Strategy

### Static Documentation Checks

- Add or run a lightweight script/check that verifies:
  - all local `href` targets exist
  - all `#anchor` targets exist
  - all image/CSS asset paths exist
  - no links point to `Docs/Plans/Transcripts`
  - no links point to obsolete `Docs/Plans/_SwiftTag.sdef`
  - `index.html` links to Quick Start, Examples, AppleScript, and Troubleshooting
- If `tidy`, `xmllint --html`, or another local HTML checker is available, run it.
- If no HTML checker is available, document fallback verification used.

### Content Checks

- Check Quick Start includes:
  - add FLAC files
  - select tracks
  - edit album/track/misc tags
  - album art
  - save command choice
  - links to deeper pages
- Check save docs include:
  - selected versus all tracks
  - tags versus pictures versus both
  - locked tracks
  - `.swifttag` document distinction
- Check AppleScript docs include:
  - `selected tracks` list caveat
  - `whose its file is ...` file filter caveat
  - Base64 picture creation guidance
  - empty tag versus delete guidance
  - writeback warning on save examples

### App Build And Integration Checks

- If only static docs are added outside app target:
  - no app build is required, but running `BuildProject` is acceptable as final confidence.
- If `Info.plist`, Xcode resources, or Help command code changes:
  - run `BuildProject`
  - inspect bundled app resources if needed
  - verify Help menu opens docs
- If AppleScript examples are executable during implementation:
  - run a small gated smoke check against copied FLAC fixture
  - avoid full AppleScript UI suite unless app code changes justify it

## Acceptance Criteria

- `Docs/UserDocumentation/index.html` exists and opens as a documentation entry point.
- Quick Start appears as primary first path.
- Quick Start covers basic app use from adding FLAC files through saving.
- Quick Start links to deeper pages for workflows, settings, AppleScript, examples, and troubleshooting.
- HTML docs include comprehensive workflow references for tags, album art, saving, `.swifttag` documents, settings, and status/diff behavior.
- Examples/use cases show realistic SwiftTag tasks, not abstract placeholders.
- AppleScript docs cover object model, key commands, settings, tracks, tags, pictures, save behavior, and known scripting caveats.
- AppleScript examples match current `SwiftTag/SwiftTag.sdef` terms and tested behavior.
- Save documentation distinguishes FLAC metadata writeback from `.swifttag` document save.
- Documentation states writeback effects for tags, pictures, selected tracks, all tracks, and locked tracks.
- No local documentation links or anchors are broken.
- If Help Book integration is included, app bundle contains docs and Help opens the expected entry point.
- Verification results are recorded in implementation summary.

## Open Questions

- Should first implementation bundle HTML docs as macOS Help Book immediately, or land repository HTML docs first and integrate app Help in a follow-up?
- Should AppleScript examples include complete runnable scripts only, or a mix of snippets and full scripts?
- Should documentation include screenshots after core HTML content lands?
