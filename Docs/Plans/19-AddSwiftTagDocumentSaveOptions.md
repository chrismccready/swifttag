# Add SwiftTag Document Save Options Plan

## Goal
Add two save-related options that affect the existing `Save` (`⌘S`) FLAC workflow:
- `SaveSettingsKey.saveReferencedSwiftTagDocument`
- `SaveSettingsKey.askToSaveNewSwiftTagDocument`

The intended result is:
- when `saveReferencedSwiftTagDocument` is on and the current window already references a `.swifttag`
  document, a successful `⌘S` FLAC save also updates that referenced `.swifttag` document
- when `saveReferencedSwiftTagDocument` is on but the current window does not yet reference a
  `.swifttag` document, `⌘S` either does nothing extra or prompts to create a new `.swifttag`
  document, depending on the `askToSaveNewSwiftTagDocument` setting and the window-scoped
  `askToSaveNewSwiftTagDocumentOk` gate
- when `saveReferencedSwiftTagDocument` is off, `⌘S` continues to save FLAC changes only

## Scope
In scope:
- Add the `⌘S` follow-on save behavior for referenced `.swifttag` documents.
- Add a window-scoped `askToSaveNewSwiftTagDocumentOk` Boolean defaulting to `true`.
- Prompt to create a new `.swifttag` document only after a successful FLAC `⌘S` when all required
  settings and gate conditions are satisfied.
- Route the prompt's save action through the existing SwiftTag document save panel flow.
- Remember newly created `.swifttag` destinations so later `⌘S` operations can auto-save the
  referenced document.
- Add targeted automated coverage for the decision logic and the end-to-end prompt/save behavior.

Out of scope:
- Changing `Save Tags`, `Save Pictures`, or `Save SwiftTag Document...` command semantics.
- Changing manual `Save SwiftTag Document...` destination selection behavior beyond reusing it from
  the new `⌘S` flow.
- Adding document auto-save on events other than `⌘S` FLAC save.
- Persisting the prompt-suppression gate across windows or app launches.
- Reworking SwiftTag document package contents, reopen logic, or file-monitoring behavior.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed: `Docs/Plans/18-UpdateWindowTitleText.md`.
- Relevant prior plans reviewed:
- `Docs/Plans/15-AddSwiftTagDocumentCreation.md`
- `Docs/Plans/16-AddSwiftTagDocumentRead.md`
- `Docs/Plans/17-SwiftTagDocumentReadLiveFileResolution.md`
- `Docs/Plans/18-UpdateWindowTitleText.md`
- Current implementation files reviewed:
- `SwiftTag/ContentView.swift`
- `SwiftTag/SwiftTagApp.swift`
- `SwiftTag/Features/Settings/GeneralSettingsView.swift`
- `SwiftTag/Shared/Models/SaveSettings.swift`
- `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
- `SwiftTag/Shared/Utilities/SwiftTagDocumentPackage.swift`
- `SwiftTagUITests/SwiftTagUITests.swift`
- Relevant guides reviewed:
- `AGENTS.md`
- `Docs/Guides/testing-guide.md`
- Relevant fixtures inspected:
- No FLAC-specific fixture changes are required for the planning pass; existing save/UI-test
  fixture helpers should be reused.
- Constraints accounted for:
- `⌘S` currently routes through `ContentView.save()` via `performDefaultSave`.
- SwiftTag document saving is currently a separate `saveSwiftTagDocument()` path.
- `saveSwiftTagDocument()` currently guards on `!isSaveOperationRunning`, so it cannot be called
  directly from within the in-progress FLAC save task without extracting a reusable internal save
  helper.
- The remembered `.swifttag` destination/source-of-truth already lives in
  `TagEditorViewModel.swiftTagDocumentSaveState()`.
- Save-panel interaction already exists and is UI-testable through current helpers.
- The new `askToSaveNewSwiftTagDocumentOk` flag is explicitly window-scoped, so it should not live
  in `AppStorage`.

## Current Implementation Snapshot
- `ContentView` exposes `performDefaultSave` and `performSaveSwiftTagDocument` through focused scene
  values, with `⌘S` mapped to `save()` and `⌃⌘S` mapped to `saveSwiftTagDocument()`.
- `save()` currently:
- syncs album-art-backed picture state
- validates whether the requested FLAC save can proceed
- performs the asynchronous FLAC save through `TagEditorViewModel.save(...)`
- refreshes monitoring/session state after success
- shows save errors through the existing save error alert
- `saveSwiftTagDocument()` currently:
- syncs picture state
- uses the remembered SwiftTag document URL when present
- otherwise prompts with `NSSavePanel`
- writes the `.swifttag` package and remembers the resulting destination/document ID
- `SaveSettings.swift` now contains AppStorage keys/defaults for:
- `saveReferencedSwiftTagDocument`
- `askToSaveNewSwiftTagDocument`
- `GeneralSettingsView` already exposes both toggles.
- There is already targeted XCUI coverage around `Save SwiftTag Document...` and save-panel
  interaction that can be extended rather than replaced.

## Confirmed Decisions
- `saveReferencedSwiftTagDocument` applies to the `⌘S` FLAC save flow.
- When `saveReferencedSwiftTagDocument` is on and a referenced `.swifttag` document exists,
  `⌘S` should save the FLAC changes first and then save the referenced `.swifttag` document.
- When `saveReferencedSwiftTagDocument` is on and no referenced `.swifttag` document exists,
  `⌘S` does nothing extra unless `askToSaveNewSwiftTagDocument` is on and
  `askToSaveNewSwiftTagDocumentOk` is `true`.
- The new-document prompt happens only after the FLAC save succeeds.
- If the user chooses to save a new `.swifttag` document and then cancels the save panel, the
  window should ask again on the next eligible `⌘S`.
- If the user chooses not to save a new `.swifttag` document, set
  `askToSaveNewSwiftTagDocumentOk` to `false` for that window.
- `askToSaveNewSwiftTagDocumentOk` resets only when a new window is created.
- If the FLAC save succeeds but the follow-on SwiftTag document save fails, show a SwiftTag
  document save error while keeping the FLAC save treated as successful.

## Dependencies And Constraints
- The new flow should reuse the existing remembered `.swifttag` destination state in
  `TagEditorViewModel` rather than introducing a second document-association store.
- The implementation needs a reusable internal SwiftTag document save helper that can be invoked:
- from the manual `Save SwiftTag Document...` command
- from the post-success branch of `save()` while the overall save flow is still active
- The post-FLAC branch should only consider `.swifttag` follow-on behavior after the FLAC save has
  completed successfully.
- The window-scoped suppression gate should be owned by the window/editor view layer, most likely a
  `@State` property on `ContentView`, not a persisted setting.
- Prompt handling should not regress the current save-status UI, save error alerts, or focused-scene
  command routing.
- When a `.swifttag` destination becomes associated through either manual save or prompted save,
  future `⌘S` operations should use that remembered URL automatically when the setting is on.
- The prompt should not appear when `saveReferencedSwiftTagDocument` is off, even if
  `askToSaveNewSwiftTagDocument` is on.
- The prompt should not appear for alternate save commands unless the product requirement changes
  later.

## Write-Back Behavior
- Preserved data:
- FLAC save semantics remain unchanged for the primary `⌘S` operation.
- Existing remembered `.swifttag` document URL/document ID behavior remains the source of truth.
- A canceled save panel does not suppress future prompts for the same window.
- Replaced data:
- When a referenced `.swifttag` exists and auto-save is enabled, that package is rewritten using the
  existing SwiftTag document writer after the FLAC save succeeds.
- Removed data:
- None beyond the normal overwrite behavior already defined by the SwiftTag document package writer.
- Selection semantics:
- The follow-on `.swifttag` save remains session-scoped and writes the full current editor session,
  matching the existing `Save SwiftTag Document...` behavior.

## High-Risk Concerns
### Product / Behavioral Risks
- If the prompt is shown before FLAC save completion, the flow will not match the confirmed user
  behavior and can create documents for failed or canceled FLAC saves.
- If the prompt-suppression flag is stored outside the window scope, one window could incorrectly
  suppress prompts for another.
- If the follow-on SwiftTag document save failure is surfaced as a generic `⌘S` failure, the app may
  imply that FLAC writes were rolled back when they were not.
- If the flow accidentally hooks into alternate save commands, users may get unexpected prompts from
  `Save Tags` or `Save Pictures`.

### Tooling / Environment / Sandbox Risks
- Calling the existing `saveSwiftTagDocument()` directly from within `save()` will currently fail
  the `!isSaveOperationRunning` guard, so implementation must avoid that dead path.
- Prompt plus save-panel behavior is runtime/AppKit-driven, so a thin targeted XCUI path is likely
  still required even if most decision logic is extracted into unit-testable helpers.
- The save panel and follow-on prompt need deterministic UI-test hooks to avoid brittle timing.

## Implementation Phases
1. Define The `⌘S` Follow-On Decision Seam
- Add a small, testable decision/helper seam that determines the post-FLAC action after a
  successful `⌘S`.
- Encode the gating inputs explicitly:
- `saveReferencedSwiftTagDocument`
- `askToSaveNewSwiftTagDocument`
- `askToSaveNewSwiftTagDocumentOk`
- current remembered SwiftTag document destination presence
- whether the triggering action is the default FLAC save flow
- Model the three outcomes:
- no follow-on SwiftTag action
- save existing referenced `.swifttag`
- prompt to create a new `.swifttag`

2. Add Window-Scoped Prompt State And Prompt UI
- Add `askToSaveNewSwiftTagDocumentOk` as a window-scoped Boolean defaulting to `true`.
- Add a user prompt path for the eligible “no referenced document yet” case.
- Ensure the prompt’s `Do Not Save` action flips the window-scoped Boolean to `false`.
- Ensure the prompt’s `Save` action continues into the existing SwiftTag save-panel flow.
- Ensure canceling the save panel leaves `askToSaveNewSwiftTagDocumentOk` unchanged.

3. Refactor SwiftTag Document Saving Into Reusable Internal Helpers
- Extract the current manual SwiftTag save behavior so the actual package-writing path can run both:
- from the menu command
- from the post-success branch of `save()`
- Keep manual `Save SwiftTag Document...` behavior unchanged from the user’s perspective.
- Reuse the existing remembered destination lookup and destination prompt logic.
- Keep error reporting specific to the SwiftTag document stage so FLAC success is not masked.

4. Integrate The Follow-On Save Into `⌘S`
- Update `save()` so, after successful FLAC save completion and before the operation fully exits, it
  evaluates the follow-on SwiftTag decision seam.
- If a referenced `.swifttag` exists and auto-save is enabled, save it automatically.
- If no referenced `.swifttag` exists and the prompt conditions are met, show the prompt and handle
  the chosen branch.
- If neither condition applies, preserve the current FLAC-only `⌘S` behavior.
- Keep session re-registration and monitoring refresh aligned with any newly remembered `.swifttag`
  destination created during the same save flow.

5. Add Targeted Automated Coverage
- Add pure unit tests for the follow-on decision seam, covering:
- auto-save off
- auto-save on with remembered destination
- auto-save on with no remembered destination and ask setting off
- auto-save on with no remembered destination, ask setting on, and suppression gate on
- auto-save on with no remembered destination, ask setting on, and suppression gate off
- Add focused view/state tests only if a lightweight seam exists for prompt state mutation; do not
  force ViewInspector where AppKit prompt handling is the real behavior under test.
- Add targeted XCUI tests for:
- `⌘S` with remembered `.swifttag` destination auto-updates the document when the setting is on
- `⌘S` with no remembered destination prompts to save a new `.swifttag` when both settings and gate
  conditions are satisfied
- choosing `Do Not Save` suppresses future prompts in that same window
- canceling the save panel after choosing `Save` prompts again on the next eligible `⌘S`
- follow-on SwiftTag save failure surfaces an error without undoing the FLAC save result

## Test Strategy
Order:
1. Pure unit tests:
- decision helper returns no follow-on action when `saveReferencedSwiftTagDocument` is off
- decision helper returns save-existing action when auto-save is on and a remembered destination
  exists
- decision helper returns no action when auto-save is on, no destination exists, and ask setting is
  off
- decision helper returns prompt-new action when auto-save is on, no destination exists, ask setting
  is on, and `askToSaveNewSwiftTagDocumentOk` is `true`
- decision helper returns no action when the same conditions hold but the suppression gate is `false`
2. Targeted UI/runtime tests:
- a window with a remembered `.swifttag` destination updates that document after a successful `⌘S`
  when auto-save is enabled
- a window with no remembered destination shows the prompt after a successful `⌘S` when both
  settings are enabled and the suppression gate is still `true`
- choosing not to save suppresses subsequent prompts in the same window
- canceling the save panel after opting to save leaves future prompting enabled
- a manual `Save SwiftTag Document...` still remembers the destination and enables later auto-save
3. Verification workflow:
- prefer Xcode diagnostics/build tooling when available
- prefer targeted tests over full-suite runs
- keep XCUI coverage narrow and focused on prompt/save-panel integration that lighter harnesses
  cannot verify confidently

## Acceptance Criteria
- `⌘S` continues to save FLAC changes as it does today when `saveReferencedSwiftTagDocument` is off.
- When `saveReferencedSwiftTagDocument` is on and the current window has a remembered `.swifttag`
  destination, a successful `⌘S` also saves that `.swifttag` document.
- When `saveReferencedSwiftTagDocument` is on and the current window has no remembered `.swifttag`
  destination, `⌘S` does nothing extra if `askToSaveNewSwiftTagDocument` is off.
- When both settings are on, no remembered destination exists, and
  `askToSaveNewSwiftTagDocumentOk` is `true`, a successful `⌘S` prompts the user to save a new
  `.swifttag` document.
- Choosing `Save` from that prompt shows the SwiftTag save panel.
- Canceling the save panel does not set `askToSaveNewSwiftTagDocumentOk` to `false` and the window
  prompts again on the next eligible `⌘S`.
- Choosing not to save sets `askToSaveNewSwiftTagDocumentOk` to `false` for that window only.
- Once `askToSaveNewSwiftTagDocumentOk` is `false`, later eligible `⌘S` operations in the same
  window no longer prompt to create a `.swifttag` document.
- A newly created window starts with `askToSaveNewSwiftTagDocumentOk == true`.
- If the follow-on SwiftTag document save fails after FLAC save success, the app reports the
  SwiftTag document save error without implying that the FLAC save was rolled back.
- Manual `Save SwiftTag Document...` continues to work and still establishes the remembered
  destination used by later auto-save.
- Automated coverage is sufficient to verify both the decision logic and the thin runtime prompt /
  save-panel integration path.

## Open Questions
- None currently.