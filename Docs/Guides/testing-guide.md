# SwiftTag Testing Guide (ViewInspector First)

## Goal

Use fast, reliable tests for SwiftUI behavior without over-relying on long or flaky XCUI runs.

## Harness Priority

1. Unit tests for pure logic and mapping.
2. ViewInspector tests for SwiftUI structure/behavior and view-state assertions.
3. Targeted XCUI tests for end-to-end flows only.
4. Full UI suite only when explicitly needed or at release gates.

## ViewInspector First-Choice Rules

- Use ViewInspector by default when validating SwiftUI view conditions:
  - disabled/enabled state
  - conditional rendering
  - callback wiring
  - bound value propagation
  - context/menu command availability at view level
- Prefer XCUI only for behaviors that require full app/runtime integration:
  - menu command routing through app scene lifecycle
  - sandbox/bookmark/file-system interactions
  - multi-window focus and responder-chain behavior

## Core Terms

- `SUT`: system under test (the view instance being tested).
- `Inspectable`: protocol conformance that enables inspection.
- `inspect()`: entry point into an inspected hierarchy.
- `find` / `findAll`: dynamic query APIs for locating views by type/predicate.
- `actualView()`: unwrap inspected node back to concrete view for property/closure assertions.
- `callOnAppear()`: trigger lifecycle callback when needed.
- `implicitAnyView()`: helper for call chains affected by implicit `AnyView` wrapping on newer Swift/Xcode.

## Project Setup Notes

- SwiftTag tests use Swift Testing (`import Testing`) and ViewInspector (`import ViewInspector`).
- In tests, add local conformance where needed:
  - `extension TagEditorTrackFileView: Inspectable {}`
  - `extension TagEditorAlbumView: Inspectable {}`
  - `extension AlbumArtWellView: Inspectable {}`
- Keep test fixtures small and deterministic. Prefer in-memory model creation over file I/O unless integration is required.

## Patterns For SwiftTag

### `TagEditorTrackFileView`

- Verify status presentation via injected closures and `actualView()`:
  - `statusPresentationForTrack`
  - `isTrackLocked`
  - `hasDeletedFile`
  - `hasExternalTitleDifference`
- Validate context-menu behavior through configured labels and enable/disable inputs.
- `Table` / `TableColumn` caveat:
  - ViewInspector does not provide rich dedicated `Table` inspection APIs.
  - Use dynamic `find`/`findAll` when possible.
  - When structural traversal is brittle, assert stable inputs and outcomes via `actualView()` and targeted source-order checks.

### `TagEditorAlbumView`

- Assert text-field enabled/disabled states under `isMetadataEditable`.
- Assert `AlbumArtWellView` inputs (enabled state, difference overlay) via `actualView()`.
- Validate gesture guards indirectly through boolean gating that determines whether callbacks can fire.

## Recommended Assertion Style

- Prefer behavior-focused checks over brittle full-tree path assertions.
- Assert one behavior per test where practical.
- Name tests as scenario + expected result.
- Keep tests `@MainActor` for SwiftUI view interaction consistency.

## Suggested Test Matrix For Track Status Work

- Status icon presentation is supplied for track rows.
- No icon path when status presentation is missing.
- Album metadata fields disabled when metadata editing is off.
- Album metadata fields enabled when metadata editing is on.
- Album art overlay toggle wiring is forwarded.
- Album art interactivity disabled while save operation runs.
- Lock-state lookup wiring returns expected locked/unlocked value.

## Command Examples

```sh
# Build
xcodebuild -scheme SwiftTag build

# Run a single test target
xcodebuild -scheme SwiftTag -destination 'platform=macOS' test -only-testing:SwiftTagTests

# Run one test file (example)
xcodebuild -scheme SwiftTag -destination 'platform=macOS' test \
  -only-testing:SwiftTagTests/TrackStatusViewInspectorTests
```

When available in this environment, prefer Xcode MCP tools for fast iteration:
- `XcodeRefreshCodeIssuesInFile`
- `BuildProject`
- `RunSomeTests`

## Troubleshooting

- If `find` chains fail after toolchain updates, try:
  - adding `.implicitAnyView()` where needed
  - using broader `find` queries and narrowing by count/content
  - pivoting to `actualView()` assertions for stable logic checks
- If tests require heavy stateful interaction (`@State`, environment objects), introduce small test seams instead of complex inspector chains.
- If a behavior is expensive or unstable through XCUI, first attempt ViewInspector coverage at the composed-view level.

## References

- ViewInspector guide: https://github.com/nalexn/ViewInspector/blob/0.10.4/guide.md
- ViewInspector dynamic query with `find`: https://github.com/nalexn/ViewInspector/blob/0.10.4/guide.md#dynamic-query-with-find
- ViewInspector repository: https://github.com/nalexn/ViewInspector
- Swift Testing framework docs: https://developer.apple.com/documentation/testing
- XCTest docs: https://developer.apple.com/documentation/xctest
- SwiftUI docs: https://developer.apple.com/documentation/swiftui

