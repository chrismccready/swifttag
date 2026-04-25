# SwiftTag Testing Guide (Assistant-Oriented, ViewInspector-First)

## Goal

Provide a deterministic testing workflow that lets assistant/AI contributors maximize ViewInspector coverage while preserving the harness order and constraints defined in `AGENTS.md`.

## Audience

This guide is written for assistant/AI contributors and should be treated as the default testing playbook for SwiftTag changes.

## Required Reading Before Writing Tests

Read these in order for every non-trivial test task:

1. `AGENTS.md` (project-level constraints and clarification triggers)
2. This file (`Docs/Guides/testing-guide.md`)
3. The current implementation files under test
4. Relevant fixtures in `SwiftTagTestFiles` for FLAC import/write behavior
5. ViewInspector upstream docs relevant to the target feature under test

If a needed API or behavior is unclear after reading, stop and ask for clarification before writing brittle tests.

## Harness Priority (Must Match `AGENTS.md`)

1. Unit tests for pure logic and mapping.
2. Service or bridge tests using copied fixtures.
3. SwiftUI behavior/state tests with ViewInspector (first choice for UI-level assertions).
4. Targeted XCUI tests only for end-to-end integration behavior ViewInspector cannot validate.
5. Full UI suite only when explicitly requested or at release gates.

## ViewInspector-First Rules

- Use ViewInspector by default for SwiftUI behavior assertions:
  - enabled/disabled state
  - conditional rendering and modifiers
  - callback wiring and closure forwarding
  - binding value propagation
  - view-local command/context-menu enablement decisions
- Prefer XCUI only when behavior depends on full runtime integration:
  - app/menu command routing through scene lifecycle
  - sandbox or bookmark access
  - multi-window focus and responder-chain behavior
  - drag/drop or OS-level event plumbing that is not inspectable with confidence

## ViewInspector Capability Checklist (Use What Applies)

- Hierarchy access: `inspect()`, `find`, `findAll`, typed traversal.
- Concrete-view assertions: `actualView()` for stored closures, flags, and injected dependencies.
- State and bindings: read/write bindings where practical to verify propagation.
- Lifecycle hooks: `callOnAppear()` and related callbacks when logic depends on lifecycle.
- Interaction simulation: tap/gesture/value-entry helpers when available for the target control.
- Conditional and optional content checks: assert both present and absent paths.
- Modifier assertions: disabled state, help text, style-impacting modifiers where stable.
- Dynamic query fallback: prefer type/predicate search over brittle positional paths.
- Toolchain compatibility escape hatch: use `implicitAnyView()` when implicit wrapping breaks traversal.

For `Table` / `TableColumn` specifically:
- Assume dedicated inspection APIs are limited.
- Prefer dynamic `find`/`findAll` queries.
- When structural traversal is brittle, assert stable outcomes through `actualView()` and focused source-order assertions.

## Project Setup Notes

- SwiftTag tests use Swift Testing (`import Testing`) and ViewInspector (`import ViewInspector`).
- Add local `Inspectable` conformances only where needed by test scope, for example:
  - `extension TagEditorTrackFileView: Inspectable {}`
  - `extension TagEditorAlbumView: Inspectable {}`
  - `extension AlbumArtWellView: Inspectable {}`
- Keep fixtures deterministic; prefer in-memory setup unless integration with FLAC/filesystem behavior is the test target.
- Prefer `@MainActor` for SwiftUI interaction tests.

## FLAC Fixture Strategy

- Treat `SwiftTagTestFiles` as the source-of-truth fixture store for checked-in FLAC samples.
- For unit and service tests, copy fixture FLAC files into a temporary per-test directory before mutating them.
- For XCUI tests, do not rely on the sandboxed app being able to read repo fixture paths or arbitrary host-side UUID files directly.
- Prefer sending FLAC bytes to the app through launch environment values such as `UITEST_FLAC_DATA_BASE64`, `UITEST_MENU_FLAC_DATA_BASE64`, or `UITEST_OPEN_DOCUMENT_FLAC_DATA_BASE64`.
- On the app side, materialize those bytes into the app container before import/open. The current preferred directory is the app-owned caches folder:
  - `~/Library/Containers/com.toowalks.swifttag/Data/Library/Caches/SwiftTagUITestFixtures`
- Use app-owned materialization for:
  - launch-time load/import fixture flows
  - menu-driven add/load flows
  - document-open fixture flows that need a real `.flac` path
- Prefer the caches-based materialized path over raw external file paths when the test:
  - runs through menu commands
  - spans relaunches
  - depends on sandbox-safe file access
- If a UI test must pre-create a file outside the app process, prefer the app container caches directory so both the UI test target and the app can resolve the same stable path.
- Existing helper examples:
  - `prepareReadableFlacFixture(fileName:)` in `SwiftTagUITests.swift` copies a repo fixture into the app container caches directory for test-managed paths.
  - `uiTestImportFileURL(for:)` in `ContentView.swift` materializes launch-import bytes into the app-owned test-fixture directory.
  - `uiTestMenuFlacURLIfPresent()` in `ContentView.swift` and `SwiftTagApp.swift` materializes menu-import bytes into the same app-owned directory.
  - `uiTestDocumentOpenURLIfPresent()` in `SwiftTagApp.swift` materializes open-document bytes into the same app-owned directory.

## Creating And Reading Test Files

- Unit/service tests:
  - Start from `SwiftTagTestFiles`.
  - Copy into `FileManager.default.temporaryDirectory`.
  - Mutate only the copied file.
- XCUI tests that need the app to read a FLAC:
  - Read the repo fixture on the test side.
  - Base64-encode the bytes.
  - Pass the bytes through launch environment.
  - Let the app write the `.flac` into `SwiftTagUITestFixtures` inside its sandbox container.
- XCUI tests that need a durable path across relaunches:
  - Use the app container caches directory, not an arbitrary host temp path.
- When debugging sandbox failures:
  - first confirm the materialized file actually exists inside `~/Library/Containers/com.toowalks.swifttag/Data/Library/Caches/SwiftTagUITestFixtures`
  - then confirm the app path being imported/opened points to that container-owned file rather than a repo or host-only path

## SwiftTag Patterns

### `TagEditorTrackFileView`

- Verify status behavior through injected closures and `actualView()`:
  - `statusPresentationForTrack`
  - `isTrackLocked`
  - `hasDeletedFile`
  - `hasExternalTitleDifference`
- Validate lock context-menu title and enablement via explicit inputs.

### `TagEditorAlbumView`

- Assert metadata field enabled/disabled behavior under `isMetadataEditable`.
- Assert `AlbumArtWellView` inputs (enabled state and external-difference overlay) via `actualView()`.
- Prefer boolean gating assertions over brittle gesture-path traversal when gesture internals are unstable.

## Assertion Style

- Prefer behavior assertions over full-tree snapshots.
- Keep one behavior focus per test when practical.
- Use scenario-style names: condition + expected outcome.
- Cover positive and negative paths for each gate/flag.

## Suggested Matrix For Track Status

- Status icon presentation exists for file-backed rows.
- Status icon is absent when presentation is missing.
- Album fields disable when metadata editing is off.
- Album fields enable when metadata editing is on.
- Album art overlay flag is forwarded.
- Album art interactivity disables during save operations.
- Lock lookup wiring reports expected locked/unlocked values.

## Verification Workflow

When available in this environment, prefer Xcode MCP tools:

1. `XcodeRefreshCodeIssuesInFile` for fast diagnostics.
2. `BuildProject` for compile validation.
3. `RunSomeTests` for targeted tests.
4. `RunAllTests` only when needed.

### AppleScript And `osascript` Integration Harness

- Use unit tests for command argument mapping before adding XCUI AppleScript coverage.
- AppleScript compiles class, property, command-parameter, and enumeration names from `SwiftTag/SwiftTag.sdef`.
- Do not test scripting terms by passing arbitrary strings for classes, enumerations, or command parameters.
- For unit tests, pass FourChar values that match `SwiftTag/SwiftTag.sdef` codes when testing enum parsing.
- In app code, expect command enum arguments to arrive as Apple event descriptors or FourChar values, not display strings.
- Use `NSScriptCommand.evaluatedArguments` for command handlers and parse by Cocoa keys from `SwiftTag/SwiftTag.sdef`.
- Keep parameter-key fallbacks for renamed terminology only when they map to same Apple event code and Cocoa key.
- In UI AppleScript tests, write scripts with published terminology:
  - use command parameter labels exactly as compiled, for example `save with scope selected with payload tags only`
  - use enum terms exactly as compiled, for example `selected`, `tags only`, `pictures only`, `tags and pictures`
  - wrap scripts that use SwiftTag-specific terms in `using terms from application id "com.toowalks.swifttag"`
- Launch SwiftTag with `XCUIApplication` first so the Xcode-built app is the running target.
- Reuse existing UI-test fixture helpers and alert checks before invoking AppleScript.
- Dismiss or fail fast on `FLAC Import Error` alerts before treating AppleScript results as command failures.
- Prefer the current in-process `NSAppleScript` UI harness for targeted end-to-end tests.
- `NSAppleScript` keeps compilation and execution inside `SwiftTagUITests-Runner`, so it avoids a child helper identity mismatch.
- `NSAppleScript` does not support argv-style `osascript` arguments; interpolate only test-controlled paths/values.
- Keep in-process AppleScript tests small and deterministic because Apple event timing and automation prompts remain brittle.

#### Sandbox And Entitlements

- Do not assume `Process`-launched `/usr/bin/osascript` from `SwiftTagUITests-Runner` is outside sandbox.
- Helper tools launched with `Process` inherit the UI test runner sandbox and code-signing identity constraints.
- External `/usr/bin/osascript` can fail even when app scripting works manually because sender identity differs.
- Error `-600` can mean target app is unavailable, but it can also hide AppleEvent sandbox/TCC denial.
- Check unified logs before blaming app scripting code:

```sh
/usr/bin/log show --last 5m --style compact \
  --predicate '(process == "osascript" OR process == "SwiftTagUITests-Runner" OR eventMessage CONTAINS[c] "-600") AND (eventMessage CONTAINS[c] "appleevent" OR eventMessage CONTAINS[c] "deny" OR eventMessage CONTAINS[c] "-600")'
```

- A sandbox denial commonly appears as `Sandbox: osascript(...) deny(1) appleevent-send ...`.
- A TCC denial can mention missing `com.apple.security.automation.apple-events`.
- If UI-test-runner Apple events are required, sign the UI test target or helper with test-only entitlements:
  - `com.apple.security.automation.apple-events`
  - `com.apple.security.scripting-targets` for `com.toowalks.swifttag`
  - temporary Apple-event exceptions only for local/test harnesses when needed
- Keep Apple-event entitlements on test/helper targets, not production app targets unless product behavior requires them.
- Prefer one of these approaches for real AppleScript end-to-end checks:
  - current `NSAppleScript` harness inside `SwiftTagUITests-Runner` with explicit entitlements
  - external host-side `/usr/bin/osascript` run outside the UI test runner sandbox
  - dedicated helper target signed with explicit Apple-event entitlements
- Use external `osascript` only when testing command-line script behavior itself.
- For external `osascript`, prefer a temporary script file over chained `-e` fragments to avoid shell escaping bugs.
- For external `osascript`, use `osascript -l AppleScript -sso`:
  - `-l AppleScript` forces AppleScript parsing.
  - `-s s` returns results in recompilable source form for deterministic assertions.
  - `-s o` routes script errors to stdout so captured output includes failure text.
- If an AppleScript bug is under investigation, first prove the harness can count or name the running app/window.
- Only then assert higher-risk behavior such as FLAC import, save payload/scope, or close semantics.

Fallback command examples:

```sh
# Build
xcodebuild -scheme SwiftTag build

# Run a single test target
xcodebuild -scheme SwiftTag -destination 'platform=macOS' test -only-testing:SwiftTagTests

# Run one test file (example)
xcodebuild -scheme SwiftTag -destination 'platform=macOS' test \
  -only-testing:SwiftTagTests/TrackStatusViewInspectorTests
```

## Troubleshooting

- If traversal breaks after Swift/Xcode updates:
  - add `.implicitAnyView()` where appropriate
  - widen to `find`/`findAll` then narrow by content/count
  - pivot to `actualView()` assertions for stable logic seams
- If a test requires deep stateful orchestration, add a small test seam instead of overfitting inspector chains.
- If XCUI appears necessary, document why ViewInspector coverage is insufficient.

## References

- ViewInspector guide: https://github.com/nalexn/ViewInspector/blob/0.10.4/guide.md
- ViewInspector dynamic query with `find`: https://github.com/nalexn/ViewInspector/blob/0.10.4/guide.md#dynamic-query-with-find
- ViewInspector repository: https://github.com/nalexn/ViewInspector
- Swift Testing framework docs: https://developer.apple.com/documentation/testing
- XCTest docs: https://developer.apple.com/documentation/xctest
- SwiftUI docs: https://developer.apple.com/documentation/swiftui
- NSScriptCommand docs: https://developer.apple.com/documentation/foundation/nsscriptcommand
- NSScriptCommandDescription docs: https://developer.apple.com/documentation/foundation/nsscriptcommanddescription
- NSAppleScript docs: https://developer.apple.com/documentation/foundation/nsapplescript
- NSAppleScript `executeAndReturnError(_:)`: https://developer.apple.com/documentation/foundation/nsapplescript/executeandreturnerror(_:)
- Apple Events entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events
- Cocoa Scripting Guide archive: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ScriptableCocoaApplications/
