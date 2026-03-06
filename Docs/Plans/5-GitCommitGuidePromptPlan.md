# Git Commit Guide Prompt Plan

## Goal
Restore the ability to generate a commit message in Xcode Code Assistant and have it appear as a usable
snippet, without the assistant writing visible commit text first and then creating an empty snippet.

## Problem Statement
Current behavior is:
- The assistant writes the commit message into the chat output.
- Xcode then creates an empty snippet instead of a snippet containing the commit message.

This suggests the current prompt and Xcode snippet extraction behavior are not aligned.

## Scope
In scope:
- Prompt and guide changes in `Docs/Guides/git-commit-message-guide.md`.
- Controlled experiments using Xcode Code Assistant with the same diff-driven commit message task.
- Recording observed behavior for each prompt variant.

Out of scope:
- Changes to Xcode itself.
- Changes to the git diff content being summarized.
- Building a custom commit-message generator outside Xcode Code Assistant.

## Working Hypotheses
1. Xcode Code Assistant treats fenced code blocks as snippet candidates, but the commit message is being
   emitted both as visible text and as a snippet target, causing the snippet payload to be empty.
2. Xcode Code Assistant may require a specific output shape for snippet capture that differs from normal
   Markdown code fences.
3. The failure may be caused by prompt ambiguity around whether the commit message is for display,
   insertion, or snippet creation.
4. The failure may be an Xcode limitation or bug that cannot be fully fixed with prompt changes alone.

## Success Criteria
- Primary success:
  - Xcode creates a non-empty snippet containing the full commit message.
  - No duplicate visible commit text is emitted before snippet creation.
- Secondary success:
  - If snippet capture cannot be made reliable, document the best fallback format and the exact reason the
    snippet approach was abandoned.

## Test Matrix

### Variant A: Plain text only
- Guide instruction:
  - Return only the commit message as plain text.
- Expected result:
  - No snippet.
  - Commit message appears only as assistant text.
- Purpose:
  - Establish the baseline non-snippet behavior.

### Variant B: Standard fenced code block
- Guide instruction:
  - Return only the commit message inside one fenced code block.
- Expected result:
  - Confirms whether standard fences consistently trigger snippet creation.
- Purpose:
  - Reproduce the current failure under a controlled prompt.

### Variant C: Fenced code block with explicit insertion language
- Guide instruction:
  - Return only the commit message inside one fenced code block using a minimal language tag such as
    `text`.
- Expected result:
  - Either snippet capture improves, or behavior matches Variant B.
- Purpose:
  - Check whether Xcode treats tagged and untagged fences differently.

### Variant D: Snippet-first instruction with no display language
- Guide instruction:
  - Create exactly one snippet containing the commit message and do not print the commit message outside
    the snippet.
- Expected result:
  - If Xcode honors higher-level snippet semantics, visible duplicate text may disappear.
- Purpose:
  - Test whether the assistant must be told about snippet intent directly instead of only formatting.

### Variant E: Sentinel markers
- Guide instruction:
  - Return the commit message only between explicit sentinel markers such as
    `SNIPPET_START` and `SNIPPET_END`.
- Expected result:
  - Likely no snippet, but useful as a control to see whether Xcode reacts to non-Markdown boundaries.
- Purpose:
  - Separate “special block parsing” from general formatting effects.

### Variant F: Minimal single-line subject only
- Guide instruction:
  - Return a one-line commit subject only.
- Expected result:
  - Reveals whether multi-line content is part of the failure mode.
- Purpose:
  - Isolate whether snippet extraction breaks only when the commit message includes a body.

## Test Procedure
1. Save the current guide text so each experiment starts from a known state.
2. Apply one prompt variant to `Docs/Guides/git-commit-message-guide.md`.
3. Use the same small diff for every experiment.
4. Run the same request in Xcode Code Assistant:
   - “Use git-commit-message-guide.md and create commit message based on diff.”
5. Record:
   - Whether visible commit text was emitted.
   - Whether a snippet was created.
   - Whether the snippet was empty or populated.
   - Whether line breaks and body formatting were preserved.
6. Repeat for each variant without changing the diff content.

## Observation Log Template
For each experiment, record:
- Variant:
- Guide wording change:
- Visible assistant text before snippet: yes/no
- Snippet created: yes/no
- Snippet empty: yes/no
- Subject preserved exactly: yes/no
- Body preserved exactly: yes/no
- Notes:

## Execution Status
- Completed:
  - Variant A equivalent behavior has been observed.
  - Variant B equivalent behavior has been observed.
  - Variant C equivalent behavior has been observed.
  - Variant D equivalent behavior has been observed.
  - Variant E equivalent behavior has been observed.
  - Variant F equivalent behavior has been observed.

## Observation Log

### Variant A: Plain text only
- Guide wording change:
  - Required plain-text-only commit output with no Markdown containers.
- Visible assistant text before snippet: yes
- Snippet created: no
- Snippet empty: no
- Subject preserved exactly: yes
- Body preserved exactly: yes
- Notes:
  - This variant works as a fallback.
  - It does not restore snippet behavior.

### Variant B: Standard fenced code block
- Guide wording change:
  - Required exactly one fenced code block containing only the commit message.
- Visible assistant text before snippet: yes
- Snippet created: yes
- Snippet empty: yes
- Subject preserved exactly: yes
- Body preserved exactly: yes
- Notes:
  - This reproduced the undesired behavior:
    visible commit text followed by an empty snippet.

### Variant C: Fenced code block with explicit insertion language
- Guide wording change:
  - Required fenced output and then tightened the rules to bare fences or no leading text.
- Visible assistant text before snippet: yes
- Snippet created: yes
- Snippet empty: yes
- Subject preserved exactly: yes
- Body preserved exactly: yes
- Notes:
  - Adding a fence language or stricter fence positioning did not change the outcome.
  - This suggests the core issue is not simple fence syntax.

### Variant D: Snippet-first instruction with no display language
- Guide wording change:
  - Required exactly one populated snippet and forbade printing the commit message outside the snippet.
- Visible assistant text before snippet: yes
- Snippet created: no
- Snippet empty: no
- Subject preserved exactly: yes
- Body preserved exactly: yes
- Notes:
  - The assistant still emitted plain commit text directly.
  - Explicit snippet-intent wording alone did not trigger snippet creation.

### Variant F: Minimal single-line subject only
- Guide wording change:
  - Required a single-line commit subject with no body or footers.
- Visible assistant text before snippet: yes
- Snippet created: no
- Snippet empty: no
- Subject preserved exactly: yes
- Body preserved exactly: no
- Notes:
  - Restricting the output to one line did not trigger snippet creation.
  - Multiline commit bodies are unlikely to be the root cause of the snippet failure.

### Variant E: Sentinel markers
- Guide wording change:
  - Required the commit message to appear only between `SNIPPET_START` and `SNIPPET_END`.
- Visible assistant text before snippet: yes
- Snippet created: no
- Snippet empty: no
- Subject preserved exactly: yes
- Body preserved exactly: yes
- Notes:
  - Sentinel markers produced plain visible text with no snippet.
  - Non-Markdown boundary markers do not trigger snippet creation either.

## Decision Rules
- If Variant D works:
  - Prefer explicit snippet-intent wording in the guide.
- If Variant B or C works reliably:
  - Keep the simplest fenced-code-block rule that produces a populated snippet.
- If only Variant F works:
  - Investigate whether snippet capture fails on multi-line content and consider a two-step workflow.
- If none of the variants work:
  - Conclude that prompt-only control is insufficient and document a fallback workflow.

## Fallback Workflow Options

### Option 1: Plain text commit message
- Return the commit message directly with no snippet expectations.
- Lowest friction, but loses snippet convenience.

### Option 2: Two-step snippet workflow
- First generate commit text plainly.
- Then ask Xcode Code Assistant to convert the exact generated text into a snippet.
- More manual, but may avoid mixed generation/snippet capture behavior.

### Option 3: External helper
- Generate commit text in chat.
- Copy it via a dedicated script or editor command outside the assistant snippet mechanism.
- Most reliable if Xcode snippet capture proves fundamentally inconsistent.

## Recommended Next Steps
- Start with Variants A, B, D, and F first.
- If D succeeds, update the guide to describe snippet intent explicitly and remove lower-value formatting
  rules.
- If A succeeds and B, C, D, and F all fail, treat snippet creation as an Xcode integration issue rather
  than a prompt issue.
- After choosing a final approach, add a short note to the guide describing the known-good pattern and the
  observed failure mode it avoids.

## Conclusion
- Prompt-only changes did not produce a populated snippet in Xcode Code Assistant.
- Fenced output created an empty snippet after visible commit text.
- Plain text, snippet-intent wording, single-line output, and sentinel markers all produced visible text
  only with no snippet.
- The best currently supported behavior is plain-text commit message output.
- If snippet UX is still desired, the next viable path is a two-step workflow or an Xcode-side feature fix.

## Acceptance Criteria
- A documented experiment result exists for each tested variant.
- The team chooses one of:
  - A prompt format that reliably creates a populated snippet.
  - A documented fallback that avoids empty snippets.
- `Docs/Guides/git-commit-message-guide.md` is updated to reflect the chosen approach only after the
  experiments confirm it.
