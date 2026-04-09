# Add Window-Close SwiftTag Document Save Options Plan

## Goal
Extend the unsaved-FLAC window-close and app-quit flows so they offer additional save choices
beyond the current destructive confirm/cancel alerts.

The intended result is:
- when a window has unsaved FLAC changes, the close flow always offers `Save FLAC files`, using the
  current default FLAC save write options regardless of the
  `saveReferencedSwiftTagDocument` and `askToSaveNewSwiftTagDocument` settings
- when the app is quitting and there are unsaved FLAC changes in one or more windows, the quit flow
  uses the same expanded choice set rather than the current simple quit confirmation
- when the current session already references a `.swifttag` document, the close/quit flow also
  offers:
  - `Save <referenced .swifttag document name>`
  - `Save FLAC files & <referenced .swifttag document name>`
- when the current session does not reference a `.swifttag` document, the close/quit flow instead
  offers:
  - `Save New SwiftTag Document...`
  - `Save FLAC files & New SwiftTag Document...`
- when a close-triggered or quit-triggered new-document save option opens the SwiftTag save panel
  and the user cancels that panel, the originating window stays open and the quit attempt is
  canceled

## Scope
In scope:
- Replace or extend the current unsaved window-close alert for sessions with unsaved FLAC changes.
- Replace or extend the current app-quit unsaved-changes alert so it can drive the same expanded
  choice set across affected sessions.
- Add close-triggered save choices for FLAC-only, SwiftTag-document-only, and combined save flows.
- Add quit-triggered save choices for FLAC-only, SwiftTag-document-only, and combined save flows.
- Reuse the existing default FLAC save settings and existing SwiftTag document save writer/destination
  flow where practical.
- Use the remembered referenced `.swifttag` document as the source of truth when one already exists.
- Keep the originating window open when a close-triggered SwiftTag save panel is canceled.
- Cancel the app-quit attempt when a quit-triggered SwiftTag save panel is canceled.
- Add targeted automated coverage for option resolution, close-flow orchestration, and cancel/failure
  behavior.

Out of scope:
- Changing `⌘S` follow-on save behavior already covered by `Docs/Plans/19-AddSwiftTagDocumentSaveOptions.md`.
- Changing manual `Save SwiftTag Document...` command semantics beyond reusing its save helpers.
- Changing SwiftTag document package contents, format, or reopen logic.
- Changing FLAC write semantics outside the close-window flow.
- Changing save flows outside window close and app quit confirmation.

## Plan Input Checklist Coverage
- Latest numbered plan reviewed:
  - `Docs/Plans/19-AddSwiftTagDocumentSaveOptions.md`
- Current implementation files reviewed:
  - `SwiftTag/ContentView.swift`
  - `SwiftTag/Shared/Utilities/UnsavedChangesCoordinator.swift`
  - `SwiftTag/Shared/Models/SaveSettings.swift`
  - `SwiftTag/Features/TagEditor/TagEditorViewModel.swift`
  - `SwiftTag/Shared/Utilities/SwiftTagDocumentPackage.swift`
  - `SwiftTag/SwiftTagApp.swift`
- Relevant guides reviewed:
  - `AGENTS.md`
  - `Docs/Guides/testing-guide.md`
- Relevant fixtures inspected:
  - `SwiftTagTestFiles/test.flac`
  - `SwiftTagTestFiles/test-with_padding.flac`
- Constraints accounted for:
  - `windowShouldClose(_:)` is synchronous, while FLAC save work currently runs asynchronously in
    `ContentView.save()`.
  - `applicationShouldTerminate(_:)` currently uses `UnsavedChangesCoordinator.confirmQuitIfNeeded()`
    and returns either `.terminateNow` or `.terminateCancel`, so quit-triggered save work will also
    need a deferred async orchestration path.
  - `UnsavedChangesCoordinator` currently knows only unsaved edit counts; it does not yet know the
    referenced SwiftTag document name, available close actions, or save callbacks.
  - `ContentView` already has reusable SwiftTag document save helpers:
    `performSwiftTagDocumentSave(using:)`, destination resolution, and error presentation.
  - The remembered referenced document source of truth already lives in
    `TagEditorViewModel.swiftTagDocumentSaveState()`.
  - Close-triggered new-document creation must coordinate with `NSSavePanel` cancellation without
    tearing down the window prematurely.
  - Window teardown currently happens from `onWindowWillClose`; the implementation must avoid
    invoking teardown until the chosen close action has either succeeded or been canceled.

## Current Implementation Snapshot
- `WindowCloseGuardRepresentable` routes `windowShouldClose(_:)` through
  `UnsavedChangesCoordinator.shared.confirmCloseWindowIfNeeded(for:)`.
- `SwiftTagApp.applicationShouldTerminate(_:)` routes app quit through
  `UnsavedChangesCoordinator.shared.confirmQuitIfNeeded()`.
- `UnsavedChangesCoordinator` currently registers a per-session provider that returns only
  `(tagEdits, pictureEdits)` and shows a synchronous AppKit `NSAlert` with `Close Window` and
  `Cancel` for window close plus `Quit` and `Cancel` for app quit.
- `ContentView` already tracks unsaved edit counts, owns the editor session ID, and owns the save
  helpers that can write FLAC changes and SwiftTag documents.
- `ContentView.save(using:)` already applies the default save payload/scope and performs FLAC writes
  through `TagEditorViewModel.save(...)`.
- `ContentView.performSwiftTagDocumentSave(using:)` already supports three destination modes:
  remembered-or-prompt, remembered-only, and prompt-for-new-document.
- `ContentView` already presents SwiftTag save failures distinctly when FLAC save already succeeded,
  which is useful for combined close-save actions.

## Confirmed Decisions
- The expanded choice set applies to the unsaved-FLAC window-close dialog regardless of the current
  `saveReferencedSwiftTagDocument` and `askToSaveNewSwiftTagDocument` settings values.
- The same expanded choice set also applies to app quit confirmation.
- `Save FLAC files` saves using the current default save write options.
- When a referenced `.swifttag` document exists, the close flow should offer both document-only and
  combined FLAC-plus-document save actions.
- When no referenced `.swifttag` document exists, the close flow should offer both new-document-only
  and combined FLAC-plus-new-document save actions.
- If a close-triggered `Save New SwiftTag Document...` path opens a save panel and the user cancels
  that panel, the originating window must remain open.
- If the user chooses a document-only action, the window closes afterward even though the unsaved
  FLAC edits were not written back to the FLAC files.
- The destructive no-save option remains present in the close dialog and keeps the label
  `Close Window`.
- For app quit, the destructive no-save option should remain present and preserve the existing quit
  semantics.
- If a combined action saves FLAC files successfully but the SwiftTag document save then fails, the
  window remains open with the same partial-success error behavior already used by the `⌘S`
  follow-on save flow.

## Dependencies And Constraints
- The close flow should reuse the remembered SwiftTag document URL/name in
  `TagEditorViewModel.swiftTagDocumentSaveState()` instead of inventing a second reference store.
- The implementation needs a close-specific orchestration seam that can:
  - block immediate window closure
  - present close options
  - run asynchronous save work
  - re-attempt or force the actual window close only after the chosen action completes successfully
- The quit flow needs the same orchestration pattern, but it must coordinate across every affected
  unsaved session and only allow termination after the chosen quit actions complete successfully.
- The current `UnsavedChangesCoordinator` API is too narrow for the requested behavior, so it will
  likely need to register richer per-session close context or delegate the full close workflow back
  into `ContentView`.
- Combined save actions should preserve the established save ordering unless a clarified requirement
  says otherwise; the likely order is FLAC first, then SwiftTag document.
- The close workflow must guard against re-entrant close attempts and repeated saves while a
  close-triggered save action is already in progress.
- The user-visible button label for the referenced-document actions depends on deriving a stable file
  name from the remembered destination URL.
- Because the requested choice set exceeds the current two-button alert, the implementation may need
  a custom sheet/dialog flow instead of keeping the existing minimal `NSAlert` unchanged.
- For app quit, the implementation must decide whether to present one aggregated dialog that works
  across all unsaved sessions or a session-at-a-time workflow; whichever path is chosen must still
  preserve the confirmed action semantics above.

## Write-Back Behavior
- Preserved data:
  - Existing FLAC save behavior and write options remain the source of truth for any close-triggered
    or quit-triggered FLAC write.
  - Existing remembered `.swifttag` destination/document ID behavior remains the source of truth for
    referenced-document saves.
  - Canceling the new-document save panel keeps the current window and in-memory edits intact.
- Replaced data:
  - When a referenced-document save action is chosen, the existing `.swifttag` package is rewritten
    using the current editor session state.
  - When a combined save action is chosen, FLAC files are rewritten according to the current default
    save options before any follow-on SwiftTag document save step.
- Removed data:
  - A document-only close or quit action discards the current unsaved FLAC-on-disk changes after the
    window closes or the app terminates, while preserving the current session state only in the
    saved `.swifttag` document.
- Selection semantics:
  - Close-triggered save actions should continue to operate on the same payload/scope source of truth
    used by the existing save commands, rather than introducing a close-only track-selection model.

## High-Risk Concerns
### Product / Behavioral Risks
- The confirmed document-only close/quit options are intentionally destructive to FLAC-on-disk state
  because they preserve the current session only in the `.swifttag` document, so dialog copy and
  action separation must make that distinction clear.
- If a combined close-save action partially succeeds, users need unambiguous messaging about which
  data was saved and whether the window remains open.
- If the new close dialog replaces standard close-sheet behavior poorly, button ordering, default
  action, keyboard shortcuts, and user expectation may regress.
- If the referenced document name is missing or derived inconsistently, the close dialog labels can
  become unstable or misleading.
- If quit confirmation spans multiple unsaved windows, the product behavior must remain predictable
  about whether actions apply to one session or all pending sessions.

### Tooling / Environment / Sandbox Risks
- `windowShouldClose(_:)` is synchronous, but FLAC save uses async work, so the implementation must
  defer closure rather than trying to block synchronously on an async save.
- `applicationShouldTerminate(_:)` has the same synchronous-to-async mismatch for quit-triggered
  save flows.
- `NSSavePanel` is AppKit-driven and must coordinate correctly with any custom close sheet/dialog to
  avoid nested-modal or focus issues.
- Targeted UI tests for close behavior can be timing-sensitive because they involve window delegate
  routing, dialog presentation, and save-panel interaction.

## Implementation Phases
1. Model Close-Flow Options And Session Context
- Add a close-flow model that can derive available actions from:
  - unsaved edit counts
  - referenced SwiftTag document presence
  - referenced SwiftTag document display name
  - current default save settings snapshot
- Extend the session registration path so the close/quit-flow owner can access more than just edit
  counts.
- Keep the action resolver pure and unit-testable.

2. Replace The Current Return-Only Close Confirmation With Deferred Close Orchestration
- Change the close guard flow so `windowShouldClose(_:)` returns `false` when unsaved changes require
  user confirmation.
- Present the expanded close options through either:
  - a richer AppKit alert/sheet managed by the coordinator, or
  - a `ContentView`-owned sheet/dialog triggered by the close guard
- Add a one-shot bypass or re-entry flag so a successful close action can trigger the real window
  close without re-presenting the dialog.
- Apply the same deferred pattern to app quit so `applicationShouldTerminate(_:)` can cancel the
  immediate quit request, run the selected save actions, and then resume termination only after
  success.

3. Reuse Existing Save Helpers For Close-Triggered Actions
- Extract or wrap the existing FLAC save path so the close flow can request a default-save execution
  and receive a success/failure result.
- Reuse `performSwiftTagDocumentSave(using:)` for:
  - referenced-document-only saves
  - new-document-only saves
  - combined close-save actions after the FLAC save step succeeds
- Keep save failures routed through the existing save error presentation patterns where practical.

4. Define Post-Action Close Semantics And Failure Handling
- For each close action, explicitly define whether the window:
  - closes after success
  - remains open after cancellation
  - remains open after any save failure
- Mirror the same semantics for quit, with the added rule that any canceled panel or failed save
  aborts the pending app termination.
- Ensure combined actions stop after the first failed step and surface a partial-success message when
  one save completed before another failed.
- Ensure new-document save-panel cancellation leaves the original unsaved state intact and the window
  open.
- Ensure document-only actions intentionally close the window or continue app termination even though
  the FLAC files themselves were not updated.

5. Add Targeted Automated Coverage
- Add pure unit tests for the close-option resolver.
- Add lightweight state/orchestration tests only where a test seam exists without overfitting UI
  internals.
- Add targeted XCUI tests for the actual close-flow behaviors that depend on AppKit window delegate
  routing and modal UI.
- Add targeted quit-flow tests for the same option resolution and cancellation/failure behavior.

## Test Strategy
Order:
1. Pure unit tests:
  - referenced document present produces the referenced-document option set
  - no referenced document produces the new-document option set
  - labels include the referenced `.swifttag` file name when available
  - no-unsaved-edits path bypasses the close dialog
2. Service / orchestration tests where practical:
  - combined action runs FLAC save before SwiftTag document save
  - close bypass/re-entry flag prevents the dialog from reappearing on the final close attempt
  - panel cancellation leaves the session in an unsaved/open state
  - quit orchestration aborts termination when any panel is canceled or any save step fails
3. Targeted XCUI tests:
  - closing a window with unsaved FLAC changes shows the expanded option set
  - `Save FLAC files` saves with current default save options and then closes the window
  - referenced-document-only action saves only the `.swifttag` document and then closes the window
  - referenced-document combined action saves both outputs and then closes the window
  - `Save New SwiftTag Document...` opens the save panel and canceling it keeps the window open
  - `Save FLAC files & New SwiftTag Document...` writes FLAC changes first, then prompts for the new
    document, and canceling that panel keeps the window open
  - app quit with unsaved changes shows the expanded option set and honors the same success,
    cancellation, and partial-failure rules
4. Verification workflow:
  - prefer targeted build/test validation over full-suite runs
  - prefer fixture-backed FLAC tests using `SwiftTagTestFiles/test.flac` and
    `SwiftTagTestFiles/test-with_padding.flac`
  - keep XCUI coverage narrow and focused on close-flow integration behavior

## Acceptance Criteria
- Closing a window with no unsaved FLAC changes continues to close immediately.
- Closing a window with unsaved FLAC changes shows the expanded close-save option set.
- `Save FLAC files` uses the current default save write options and, on success, closes the window.
- When a referenced `.swifttag` document exists, the close flow shows both referenced-document-only
  and combined FLAC-plus-document actions using the referenced document file name in the labels.
- When no referenced `.swifttag` document exists, the close flow shows both new-document-only and
  combined FLAC-plus-new-document actions.
- Choosing a document-only action saves the SwiftTag document and then closes the window or proceeds
  with app termination without writing the pending FLAC changes back to the FLAC files.
- Choosing a new-document action opens the SwiftTag save panel.
- Canceling the save panel for a new-document close action does not close the originating window.
- Canceling the save panel for a new-document quit action aborts app termination.
- Any failed close-triggered save action leaves the window open and presents an error describing what
  did and did not save.
- Any failed quit-triggered save action aborts termination and presents an error describing what did
  and did not save.
- The final close path does not re-present the unsaved-changes dialog after a successful save action.
- The final quit path does not re-present the unsaved-changes dialog after a successful save action.