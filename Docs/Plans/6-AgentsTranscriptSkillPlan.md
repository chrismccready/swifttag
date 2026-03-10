# Agents Transcript Skill Plan

## Goal
Create a plan for the user and assistant to work together to improve transcript-generation guidance so the assistant can create conversation transcript files with consistent formatting. The primary target is the `## Transcripts` section of [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md), with [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md) and [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md) used only if they materially help achieve that goal.

## Scope
In scope:
- Clarify and strengthen transcript-generation instructions in the `## Transcripts` section of [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md).
- Decide whether [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md) is necessary to reach the goal, and if so, refine it only as needed.
- Decide whether [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md) is necessary to reach the goal, and if so, align it to the finalized transcript rules.
- Define how the user and assistant collaborate to iteratively validate transcript instructions against one or more real transcript outputs.
- Capture the rule that `Project structure:` file lists appear only once near the beginning and once near the end when available.
- Enforce the file-boundary rule that only [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md), [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md), [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md), [6-AgentsTranscriptSkill.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/Plans/6-AgentsTranscriptSkill.md), or files created during plan execution may be modified.

Out of scope:
- Changes to app runtime code, FLAC import/write behavior, or SwiftUI features.
- Changes to numbered implementation plans unrelated to transcript creation guidance.
- Building an automated transcript exporter unless follow-up work explicitly expands scope.
- Modifying any section of [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md) outside `## Transcripts`.
- Modifying files outside the explicitly allowed documentation files unless a new file is created as part of this plan’s execution.

## Confirmed Decisions
- The implementation-driving output for this request is this numbered plan file: [6-AgentsTranscriptSkill.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/Plans/6-AgentsTranscriptSkill.md).
- The primary implementation target is only the `## Transcripts` section of [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md).
- Transcript creation guidance may refer to [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md), but the template should only remain part of the solution if it is actually needed to achieve consistent transcript formatting.
- `TranscriptTemplate.md` uses literal text when not surrounded by angle brackets, and variable text when surrounded by `< >`, with the instruction for that variable supplied by the following parenthetical note.
- [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md), [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md), and [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md) may all be iteratively updated as needed to reach a workable transcript-generation workflow.
- When available, the `Project structure:` file list should appear once near the beginning of a transcript and once near the end, not repeated on every turn.
- [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md) is now present in the workspace and should be treated as a verification artifact that must stay synchronized with the finalized template behavior.
- No files outside [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md), [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md), [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md), [6-AgentsTranscriptSkill.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/Plans/6-AgentsTranscriptSkill.md), or files created during plan execution may be modified.

## Dependencies And Constraints




\
- The latest numbered plan format is established by [5-AddSaveNotificationsPlan.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/Plans/5-AddSaveNotificationsPlan.md), so this plan should follow that structure and level of specificity.
- Existing transcript rules already live in [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md), but those rules currently describe transcript content more than template application mechanics.
- Only the `## Transcripts` section of [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md) is eligible for modification under this plan, so any needed guidance must fit within that section without relying on edits elsewhere in the file.
- [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md) currently contains placeholder semantics that need to be translated into concrete agent instructions, especially around literal text, variable substitution, optional sections, and repetition.
- [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md) now exists and provides an additional source of truth for expected output shape, but it must be checked against both the template and `AGENTS-copy.md` because examples can drift.
- Transcript files remain documentation artifacts and should continue to live under `Docs/Plans/Transcripts` unless the user explicitly requests another location.
- The assistant can only use visible chat content and must not reconstruct hidden or unavailable turns.

## High-Risk Concerns

### Product Or Behavioral Risks
- The current rules may not clearly separate template literals from substitution fields, which can cause malformed transcripts or inconsistent output between sessions.
- The current transcript guidance may leave optional sections underspecified, especially for missing timestamps, absent selections, repeated project structure blocks, or truncated prior turns.
- If the template and `AGENTS-copy.md` diverge, future transcript files can appear valid while still violating one of the two sources of truth.
- If the example file diverges from the template or `AGENTS-copy.md`, the assistant may infer formatting rules incorrectly from the example.

### Tooling, Environment, Or Filesystem Risks
- Some documentation files may exist on disk without appearing in the Xcode navigator, so verification needs to account for both project-structure visibility and filesystem reality.
- Transcript preparation depends on visible-thread availability; older turns may drop out of context, and the instructions must explicitly define how to represent that limitation.
- MCP and Xcode-oriented tools are less suitable for non-project documentation files that are not part of the navigator, so implementation may need a mixed verification approach.

## Implementation Phases

### 1. Audit the current transcript sources of truth
- Re-read the `## Transcripts` section of [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md) and [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md) together.
- Extract all transcript-specific rules into a checklist:
  - naming
  - storage location
  - visible-content limits
  - timestamp handling
  - section ordering
  - repeated boilerplate handling
  - placeholder substitution semantics
- Identify rule gaps, contradictions, and anything that currently depends on informal chat interpretation.
- Identify which of those rules can live entirely inside the `## Transcripts` section and which, if any, still justify keeping a separate template file.

### 2. Verify the example-file baseline
- Compare [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md) line by line against [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md) and note mismatches.
- Compare the example against the transcript rules in [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md) so the example is not only template-compliant but also policy-compliant.
- Confirm the example demonstrates the `Project structure:` rule by showing the file list only at the beginning and the end when available.
- Confirm the example also demonstrates the intended bulleting and metadata conventions for `Project structure:`, current file, and selection state.

### 3. Tighten `AGENTS-copy.md` transcript instructions
- Add explicit instructions to the `## Transcripts` section for how transcript creation should work.
- If the template remains necessary, add explicit instructions for how to read and apply [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md).
- State plainly that:
  - literals in the template are copied exactly
  - `<placeholder>` text is replaced with concrete content
  - the following parenthetical note defines how the placeholder should be resolved
  - optional sections must be omitted or replaced with prescribed fallback text rather than improvised prose
- Add guidance for how transcript creators should decide when to preserve, abbreviate, or omit repeated blocks.
- Add guidance for missing or partial visible history so the assistant records limitations instead of fabricating content.
- Keep all `AGENTS-copy.md` edits confined to the `## Transcripts` section.

### 4. Refine the transcript template itself
- Only if needed, update [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md) so placeholder rules are unambiguous.
- Only if needed, normalize any malformed or incomplete placeholder syntax.
- Only if needed, clarify repeated-turn structure and where one-time sections belong.
- Only if needed, ensure the template makes the `Project structure:` placement rule explicit rather than implied.

### 5. Build or repair the example transcript
- Only if the template remains part of the solution, update [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md) so it is a direct worked example of the final template contract.
- Use realistic but clearly example-only content that demonstrates:
  - transcript header metadata
  - user and assistant turn sections
  - no-timestamp fallback behavior
  - project structure placement
  - selected-code handling
  - transcript ending
- Keep the example stable and easy to diff against the template.

### 6. User-and-assistant iterative review loop
- Have the assistant draft the first pass of the document updates.
- Have the user review for missing rules, wording problems, or mismatches with expected transcript outputs.
- Update the docs based on that review and then generate a sample transcript from an actual visible conversation.
- Compare the generated transcript against the updated template and example.
- Repeat until the user confirms the instructions are specific enough that transcript generation no longer depends on ad hoc interpretation.

### 7. Verify with a transcript trial
- Produce at least one transcript using the updated guidance.
- Validate that the output satisfies:
  - naming convention
  - template literal preservation
  - correct variable substitution
  - proper handling of absent timestamps
  - correct `Project structure:` placement
  - no hidden-message leakage
- If the transcript generation process still requires unwritten assumptions, feed those assumptions back into [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md) or [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md).

## Suggested File Updates
- Update only the `## Transcripts` section in [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md)
- Update [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md) only if the template is needed
- Update [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md) only if the template remains part of the solution
- Add transcripts under [Docs/Plans/Transcripts](/Users/ccm/Dev/Swift/SwiftTag/Docs/Plans/Transcripts) only if needed for validation

## Test Strategy
- Use document review rather than code tests as the primary verification method.
- Validate the updated rules by generating at least one real transcript artifact from visible conversation history.
- Compare the generated artifact against both [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md) and [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md).
- Compare [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md) directly to the finalized template to ensure every template construct is exercised at least once.
- Prefer focused verification passes over broad document rewrites so each ambiguity is resolved with a concrete output example.

## Open Questions
- Should the finalized instructions require the `Project structure:` block at the end of every transcript whenever it was present at the beginning, or only when the visible conversation actually repeats it at the end?

## Acceptance Criteria
- The `## Transcripts` section of [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md) clearly tells the assistant how to create transcript files with consistent formatting without relying on informal interpretation.
- If [TranscriptTemplate.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplate.md) remains part of the solution, it clearly distinguishes literals, placeholders, optional content, and repeated sections.
- If [TranscriptTemplateExample.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/TranscriptTemplateExample.md) remains part of the solution, it matches the finalized template behavior and transcript rules.
- The transcript instructions explicitly cover visible-only sourcing, missing timestamps, selected-code handling, and the `Project structure:` placement rule.
- No modifications are required outside the allowed files, and no section of [AGENTS-copy.md](/Users/ccm/Dev/Swift/SwiftTag/Docs/AGENTS-copy.md) outside `## Transcripts` is changed.
- A sample transcript can be produced that matches the updated rules without inventing content or leaking hidden instructions.
