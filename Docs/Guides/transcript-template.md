# Conversation Transcript

Date: {{EXPORT_DATE}} (use `YYYY-MM-DD` for the transcript export date)
Reference Type: {{REFERENCE_TYPE}} (use a user-provided reference type when explicitly given; otherwise use `Plan` if the referenced file lives under `Docs/Plans`, else `Misc`)
References: {{REFERENCES}} (use the user-provided reference file names or identifiers; if none were explicitly provided, use a short best-fit reference or `None`)

Note:
- This file contains the visible user/assistant conversation content from this session.
- Hidden system and developer instructions are excluded.
- Exact chat turn timestamps were not available in the visible thread metadata, so section headers include timestamps only when a timestamp was explicitly present in the visible conversation text itself.
{{OPTIONAL_NOTES}} (optional additional note bullets; omit this line when there are no extra notes)

{{PROJECT_STRUCTURE_AT_START}} (optional block; when present, use the exact `Project structure:` heading followed by the associated file list; include it once here near the beginning)

## User{{OPTIONAL_USER_TIMESTAMP}} (append a leading space plus timestamp only when an exact visible timestamp exists; otherwise leave the header as `## User`)

{{USER_CURRENT_FILE_LINE}} (optional single line such as `- The user is currently inside this file: ...`)
{{USER_SELECTION_LINE}} (optional single line such as `- The user has no code selected.` or `- The user has selected the following code from that file ...`)
{{USER_SELECTED_CODE_BLOCK}} (optional fenced code block associated with the selection line; omit entirely when there is no visible selected code block, and also omit it when the selected code is identical to `{{USER_BODY}}`)
{{USER_BODY}} (the visible user message text for this turn)

## Assistant{{OPTIONAL_ASSISTANT_TIMESTAMP}} (append a leading space plus timestamp only when an exact visible timestamp exists; otherwise leave the header as `## Assistant`)

{{ASSISTANT_BODY}} (the visible assistant message text for this turn)

{{REPEATED_TURN_SECTIONS}} (repeat `## User` / `## Assistant` sections in chronological order until the visible conversation is exhausted)

{{PROJECT_STRUCTURE_AT_END}} (optional block; if `PROJECT_STRUCTURE_AT_START` was used, repeat the same `Project structure:` block once near the end. It may appear here immediately before `End of Transcript.`, or inside the final visible turn body when that better matches the source conversation shape.)

End of Transcript.
