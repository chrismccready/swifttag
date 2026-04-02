# SwiftTag Project Agent Guidelines

## Overview

- This is a macOS Swift/SwiftUI project compiled for macOS 26.2 or later.
- The root working directory is where this file, `AGENTS.md`, and this project's Xocde project file, `SwiftTag.xcodeproj`, reside. Relative paths given later in this document are from here.
- Use Swift and SwiftUI and follow best practices accordingly.
- Prefer Xcode MCP tools for project inspection, diagnostics, builds, previews, and targeted test runs when available.
- When searching for information outside of Xcode MCP tools, prioritize the [SwiftUI documentation](https://developer.apple.com/documentation/swiftui).
- Before concluding that SwiftUI cannot implement a macOS behavior, check current Apple SwiftUI documentation and Xcode documentation search for the targeted macOS version first.
- Unless otherwise instructed, if asked to create a plan/guide/information file and a name for the file is not given, then create an appropriate name prepended with an underscore and save to Docs folder.

## Guides

- For additional source of truth / authoritative guidance read files at Docs/Guides.
- Use git commit message formatting rules from Docs/Guides/git-commit-message-guide.md.
- When asked to create a git commit message use formatting rules from Docs/Guides/git-commit-message-guide.md.
- For SwiftUI test design and harness selection, use Docs/Guides/testing-guide.md as the primary guide.

## Plans

- For project feature, testing, and maintenance plans use Docs/Plans folder.
- Files located at Docs/Plans/Transcripts should, unless specifically told otherwise, be ignored as they are for historical conversation record and not main app code development.
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
- Prefer ViewInspector as the first-choice harness for SwiftUI behavior/state tests.
- Reserve XCUI tests for end-to-end flows and app integration behaviors that ViewInspector cannot validate.
- For `Table` / `TableColumn` views, prefer dynamic `find`/`findAll` queries and `actualView()` state checks.
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

## Transcripts

- Transcript files are historical records of visible conversation between the user and the assistant.
- Transcript files are documentation artifacts, not source-of-truth implementation files, and should be ignored during normal app-code reasoning unless the user explicitly asks to use them.
- Unless the user explicitly requests a different location, transcript files should be stored in `Docs/Plans/Transcripts`.
- Transcript files should not be written into numbered plan files or mixed into implementation-driving plan content.
- Transcript files should be named by convention `transcript-YYYY-MM-DD-increment-file_reference_name.md`, where:
  - `increment` is a positive integer used to distinguish multiple transcripts created on the same date
  - `file_reference_name` is optional and should be the actual associated file name with its file extension removed
- Unless the user explicitly requests a different transcript format, default transcript creation to `full visible user and assistant turns verbatim where available`.
- If the user requests `full visible user and assistant turns verbatim where available`, or if no different transcript format is specified, then transcript creation should follow these rules:
  - include full visible user turns
  - include full visible assistant replies as shown in the visible conversation history
  - do not omit visible user entries or visible assistant entries, even when multiple entries from the same speaker appear consecutively
  - exclude hidden system messages, hidden reasoning, and any content not visible in the chat
  - do not invent or reconstruct missing text that is not present in the visible conversation history
  - if some earlier visible content is no longer fully available in context, state that limitation in the transcript rather than fabricating missing text
- If exact timestamps for individual turns are available in the visible conversation data, place them in headers using the format `## User YYYY-MM-DDTHH:mm:ssZ` or `## Assistant YYYY-MM-DDTHH:mm:ssZ`.
- If exact timestamps are not available, do not invent them. Instead, note in the transcript that exact per-turn timestamps were unavailable.
- Keep transcript formatting explicit and stable.
- Use [transcript-template.md.md](Docs/Guides/transcript-template.md) as the default output shape when it is present, unless the user explicitly requests a different transcript format.
- When applying [transcript-template.md.md](Docs/Guides/transcript-template.md):
  - text not wrapped in `{{ }}` is literal and should be copied as written
  - text wrapped in `{{ }}` is variable content that should be replaced
  - the parenthetical note that immediately follows a placeholder explains how that placeholder should be resolved
  - if an optional placeholder resolves to no content, remove that placeholder line entirely unless the note explicitly requires fallback text
  - do not leave placeholder markers or template-instruction notes in the finished transcript
  - do not improvise a different transcript shape when the template already defines one
- The default transcript structure is:
  - `# Conversation Transcript`
  - `Date: YYYY-MM-DD`
  - `Reference Type: ...`
  - `References: ...`
  - blank line
  - `Note:` followed by transcript-scoping notes
  - blank line
  - `## User` / `## Assistant` sections in chronological order, while allowing consecutive assistant entries to remain under a single `## Assistant` header when no user entry interrupts them
  - `End of Transcript.`
- Use `## User` / `## Assistant` section headers in turn order. If exact visible timestamps exist for a turn, append the timestamp to that header. Otherwise use the bare header.
- Never omit a visible user or assistant entry.
- If multiple visible assistant entries occur consecutively without a user entry between them, they may be grouped under one `## Assistant` header instead of repeating the header for each assistant entry.
- Preserve quoted console output, file references, explicit code, explicit error text, and visible `<turn_aborted>` markers when they appeared in the conversation.
- For user turns, preserve visible environment metadata when present in the conversation, including:
  - `Project structure:`
  - `The user has selected the following code from that file ...`
- `Project structure:` handling is special:
  - when a visible `Project structure:` block is available, include it once near the beginning of the transcript before the first user message body
  - repeat the same `Project structure:` block once near the end of the transcript before `End of Transcript.`
  - do not repeat the full project-structure block inside every user turn even if it appeared multiple times in the visible conversation
- Omit the lines `The user is currently inside this file: ...` and `The user has no code selected.` from transcript output even when they are visible in the conversation metadata.
- If a user turn contains selected-code metadata, keep the metadata line together with the associated fenced code block in that same user section.
- If the visible selected-code block is identical to the visible user message body for that same turn, prefer the user message body and omit the duplicated fenced code block.
- If repeated boilerplate was intentionally abbreviated, explain that decision in the `Note:` section.
- Repeated boilerplate other than the special `Project structure:` rule may be abbreviated only if:
  - the user did not request a stricter fully repeated export
  - the transcript clearly notes that the repeated content was abbreviated
- If the user requests strict turn-by-turn output, prefer one turn section per visible message in chronological order.
- If the user requests verbatim output where available, do not summarize assistant responses that are fully visible in the thread.
- If both [transcript-template.md.md](Docs/Guides/transcript-template.md) and these transcript rules apply, these `## Transcripts` rules are the source of truth and the template should be followed in the way that best satisfies them.
- Transcript files may be referenced from project documentation such as `README.md`, but they should remain clearly separate from active development plans.

## General

- The great knowledge is presence.
- When running outside Xcode, at the end of every assistant response, use the shell to run `date -u +"%Y-%m-%dT%H:%M:%SZ"` immediately before replying to the user.
- Include that UTC timestamp as the final line of the response.
- When running inside Xcode, do not call terminal `date` if terminal execution is unavailable or unreliable. In that environment, omit the timestamp rather than blocking the response.
