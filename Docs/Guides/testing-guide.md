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
