# SwiftTag Project Agent Guidelines

## Overview

- This is a macOS Swift/SwiftUI project.
- Use Swift and SwiftUI and follow best practices accordingly.

## Guides

- For additional source of truth / authoritative guidance read files at Docs/Guides.
- Use git commit message formatting rules from Docs/Guides/git-commit-message-guide.md.
- When asked to create a git commit message use formatting rules from Docs/Guides/git-commit-message-guide.md.

## Plans

- For project feature, testing, and maintenance plans use Docs/Plans folder.
- Plan files are prepended with a positive integer that indicates order of use/implementation.
- When asked to create a plan to file use the Docs/Plans folder.
- If asked to create a plan file and a name for the file is not given, then create an appropriate name prepended with an underscore not an integer.
- When writing plan files use the latest (largest integer prepended plan file) as a formatting guide.
- Numbered plans are implementation-driving and sequenced. Underscore-prefixed plans are exploratory or draft plans.
- If a draft plan becomes the plan that implementation will follow, promote it into a numbered plan or recreate it as a numbered plan before implementation begins.

### Plan Input Checklist

Before writing a new plan, inspect and account for:
- The latest numbered plan in `Docs/Plans`
- The current implementation files likely to be changed
- Relevant guides in `Docs/Guides`
- Relevant fixtures or helper scripts in `SwiftTagTestFiles` when the work involves FLAC import/write behavior
- Any file-access, sandbox, security-scoped bookmark, temp-file, menu-command, or test-environment constraints that could affect implementation or verification

### Plan Content Requirements

A plan should include, where applicable:
- Goal
- Scope
- In-scope and out-of-scope items
- Dependencies and constraints
- High-risk implementation concerns
- Implementation phases or steps
- Test strategy
- Acceptance criteria
- Open questions, if any
- Confirmed decisions, once clarifications have been provided

### Confirmed Decisions

- If the user answers clarifying questions during planning, update the plan with a dedicated `Confirmed Decisions` section before implementation continues.
- Do not leave key behavior decisions only in chat history if they materially affect implementation.

### High-Risk Concerns

Plans should explicitly separate:
- Product or behavioral risks
- Tooling, environment, sandbox, or filesystem risks

Examples include:
- Security-scoped bookmarks
- Temp-file rewrite behavior
- FLAC padding or in-place write behavior
- Xcode/MCP timeout constraints
- Macro or plugin-runner failures
- UI test environment instability

### Destructive / Write-Back Features

If a feature writes back to files or otherwise changes persisted data, the plan must explicitly state:
- What existing data is preserved
- What existing data is replaced
- What existing data is removed
- What behavior changes for tag-only, picture-only, or similar partial-save operations
- What “selected items” means, if selection-based behavior exists, and which UI selection is the source of truth

### Fixture-First Rule

- If the task involves FLAC import, FLAC writeback, metadata mapping, or album-art fixture behavior, inspect `SwiftTagTestFiles` first.
- Reference specific fixtures in the plan whenever practical.

### Testing Strategy

- When implementing a plan try to break things down into smaller steps so that tests are written and not failing before continuing.
- Prefer this test order unless there is a strong reason not to:
  1. Pure unit tests
  2. Service or bridge tests using copied fixtures
  3. Targeted single UI tests
  4. Full test suite near the end or only if explicitly requested
- SwiftUI tests can take a long time and quite often a MCP timeout will occur, so try to call tests individually and only as needed for a given step.
- If there is a way to create a non-UI test instead of a UI test, prefer that.
- Before indicating a plan is complete, do a thorough review and confirm there is sufficient test coverage.
- Plans should include a verification strategy that fits known tool constraints. For example:
  - prefer `BuildProject`
  - prefer targeted tests over full-suite runs
  - use fixture-based service tests where possible
  - use lightweight runtime verification when full UI automation is unstable

### Clarification Triggers

- All throughout the design, creation, and implementation process, if there are ambiguities or questions, stop and ask for clarification.
- Stop and ask for clarification if any of the following are ambiguous:
  - Destructive write behavior
  - Source of truth between UI state, model state, and service state
  - Selection semantics
  - File-access or sandbox expectations
  - Compatibility expectations for external file formats
  - Whether placeholder or sample data should remain in the app flow
- If Swift/SwiftUI cannot be used for a given implementation, stop, explain and ask for clarification.

### Completion Gate

Before stating that a plan is ready for implementation, confirm that it includes:
- Enough specificity to implement without inventing core behavior
- A clear test approach
- Acceptance criteria
- Any unresolved questions clearly called out
- Any resolved questions moved into the plan as confirmed decisions

## General

- The great knowledge is presence.
