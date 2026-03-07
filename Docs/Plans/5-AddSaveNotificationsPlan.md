# Add Save Notifications Plan

## Goal
Add a local notification after a successful save of tags, pictures, or both. The notification must carry enough context to:
- Bring the existing editor window for the saved track set to the front without reloading tracks when that window is still open.
- Open a new editor window and load the saved tracks when no matching window is currently open.

## Scope
In scope:
- Local notification authorization, scheduling, and response handling for successful save operations.
- A stable notification payload that identifies the save operation, saved track set, save kind, and originating editor session.
- Window/session identity plumbing so the app can find an already-open editor window that owns the saved track set.
- New-window opening and track loading when a notification is activated for a track set that is not currently open.
- Tests for notification payload encoding/decoding, window match logic, and notification-triggered open/foreground behavior.

Out of scope:
- Notifications for failed saves or partial-save failures unless needed for internal error cleanup.
- Remote notifications, notification actions beyond the default click action, or rich custom notification UI.
- Replacing the current save command behavior or changing FLAC write semantics.
- Merging multiple open windows that happen to contain overlapping but non-identical track sets.

## Confirmed Decisions
- A notification is posted only after a save completes successfully for the requested target set.
- Clicking the notification should prefer the already-open window that contains the saved track files and should not reload tracks into that window.
- If that window is not open, clicking the notification should open a new editor window and load the tracks described by the notification payload.
- The source of truth for “the given set of tracks” is the set of saved FLAC file URLs/bookmarks produced by the completed save operation.

## Dependencies And Constraints
- The app currently uses a single generic `WindowGroup` in [SwiftTagApp.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/SwiftTagApp.swift), so notification routing requires explicit scene/value identity rather than relying on the current one-window setup.
- Save execution currently happens in [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift) and is invoked from [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift); the notification trigger should be driven from the final successful save result rather than from per-file writes.
- Imported FLAC tracks already carry `sourceFileURL` and `securityScopedBookmarkData` in [Track.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Shared/Models/Track.swift), which should be reused for reopening tracks from a notification.
- Apple’s current SwiftUI window APIs support data-presenting `WindowGroup` scenes and `openWindow(value:)`, which can bring an existing matching window to the front when the presented value matches.
- `UNUserNotificationCenterDelegate` must be assigned before launch finishes, so notification response handling belongs in app-level startup, not lazily inside a view.
- Notification authorization may be denied, and badge delivery may be disabled independently of alert delivery. The save flow must not fail if notification scheduling is unavailable.
- Security-scoped access may not survive indefinitely if only raw file paths are stored. Notification payloads should therefore reference bookmark-backed reopening data or a persisted app-owned session store keyed by a stable identifier.

## High-Risk Concerns

### Product Or Behavioral Risks
- Matching “the same window” by a saved track set is ambiguous if multiple windows can contain the same files in different edit states. The plan should define a window session identifier and a canonical saved-track-set fingerprint so matching behavior is deterministic.
- Reloading tracks into an already-open window would discard unsaved edits. Existing-window activation must be strictly separated from new-window loading.
- Save notifications for selected-track saves need clear semantics. The track set in the notification should reflect only the tracks actually written during that save, not all tracks loaded in the window.
- Notifications may become stale if files are moved or bookmark resolution later fails. The response path needs graceful failure reporting instead of silently doing nothing.

### Tooling, Environment, Or Filesystem Risks
- A local notification response may arrive when the app is cold-launched. App startup must restore enough routing infrastructure before handling the response.
- UI tests for Notification Center interactions can be flaky or unavailable in Xcode automation. The implementation should isolate routing and payload parsing so most coverage stays in unit tests.
- Opening a new window from a notification requires scene-safe routing and may expose SwiftUI state-restoration behavior. Explicit restoration behavior may be needed if automatic restoration conflicts with notification-targeted opens.
- Bookmark resolution for notification-triggered reopen must respect sandbox rules and may require stale-bookmark refresh logic similar to the current save path.

## Implementation Phases

### 1. Define notification and window identity models
- Add a dedicated save-notification payload model, for example `SaveNotificationPayload`, with fields such as:
  - Notification/session identifier
  - Originating window/editor session identifier
  - Save payload kind (`tags`, `pictures`, `tagsAndPictures`)
  - Saved track descriptors containing file path plus security-scoped bookmark data or a persisted reference key
  - Canonical saved-track-set fingerprint derived from the saved file set
  - Optional user-facing summary data for the notification title/body
- Add a dedicated editor-window value model, for example `EditorSessionValue`, that is `Codable`, `Hashable`, and suitable for a value-presenting `WindowGroup`.
- Define a deterministic fingerprint rule for a track set, such as sorted standardized file URLs or bookmark-derived file identifiers, so window matching is stable.

### 2. Introduce an editor session / window registry
- Add an app-level registry object that tracks open editor windows by:
  - Window/editor session identifier
  - Current saved-track-set fingerprint
  - Current imported track descriptors
  - Weak or indirect activation handle as needed for AppKit foregrounding
- Update the editor root so each window registers on appear and unregisters on close.
- Keep this registry independent from transient in-window edits; it should identify which files a window owns, not serialize all editor state.

### 3. Restructure scenes for value-based window opening
- Update [SwiftTagApp.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/SwiftTagApp.swift) to use a data-presenting `WindowGroup` with an explicit scene id and a typed value.
- Define behavior for:
  - Default empty/new editor windows
  - Editor windows opened with a saved track-set/session value
- Ensure `openWindow(value:)` can reopen or foreground a window when the presented value matches an existing session value.
- Keep the settings scene unchanged except for any app-level notification wiring needed at startup.

### 4. Separate editor bootstrap from in-window edits
- Extract content bootstrapping logic from [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift) and [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift) so a new window can load tracks from an external session value or notification payload.
- Add an explicit “load imported tracks into a fresh editor session” path that is only used for newly opened windows.
- Preserve the existing “no reload when already open” rule by avoiding this bootstrap path for windows found in the registry.

### 5. Add local notification service
- Add a small notification service responsible for:
  - Requesting notification authorization in context
  - Checking current notification settings
  - Scheduling a success notification after a completed save
  - Incrementing or setting the app badge count when permitted
  - Encoding save payload data into `UNNotificationContent.userInfo`
- Keep save operations non-blocking with respect to notification delivery; notification failures should be logged or surfaced only if needed for debugging.
- Use the default notification action for click handling unless a stronger product need emerges.

### 6. Trigger notifications from the completed save result
- Extend the save flow to return a structured success result rather than only throwing on failure. That result should include:
  - The actual saved track set
  - Payload type written
  - Originating editor session id
- Trigger notification scheduling only after the save operation completes with no failures.
- Do not emit a success notification for partial failures unless product behavior is explicitly changed to support a mixed-result notification.

### 7. Handle notification activation at app level
- Add an app-level notification delegate object and assign it before launch completes.
- On notification click:
  - Decode the save payload from `userInfo`
  - Ask the window registry whether a matching editor session or matching track-set fingerprint is open
  - If a match exists, bring that window forward and make it key/main without re-importing files
  - If no match exists, open a new editor window with the payload’s session/open value and bootstrap its track import from the saved descriptors
- Define fallback behavior when decoding fails or files cannot be reopened:
  - Surface an alert or logged error
  - Avoid opening an empty misleading window

### 8. Add foregrounding support for existing windows
- If SwiftUI’s value-based window reopening is insufficient for the “already open but do not reload” case, add a small AppKit bridge that can:
  - Find the existing `NSWindow` for a registered editor session
  - Call `NSApp.activate(ignoringOtherApps:)`
  - Order the matched window front and make it key
- Keep this bridge narrowly scoped to activation, not to content mutation.

### 9. Persist the minimum reopening data needed for notification clicks
- Decide whether notification `userInfo` should contain:
  - The full saved-track descriptors directly, or
  - A stable save/session identifier that resolves through a lightweight persisted store
- Recommended approach:
  - Keep the notification payload small and store the detailed reopen descriptors in an app-owned persisted store keyed by save/session identifier.
  - Store bookmark data and canonical track ordering there, not in the live window registry alone, so cold-launch notification responses work.
- Add cleanup rules for old persisted save-notification records to avoid unbounded growth.

## Suggested File Updates
- Update [SwiftTagApp.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/SwiftTagApp.swift)
- Update [ContentView.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/ContentView.swift)
- Update [TagEditorViewModel.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift)
- Update [Track.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTag/Shared/Models/Track.swift) if additional persisted reopen metadata is needed
- Add a notification service/coordinator under `SwiftTag/SwiftTag/Shared` or a dedicated feature folder
- Add editor session/window registry types under `SwiftTag/SwiftTag/Shared` or a dedicated scene-management area
- Add tests under [SwiftTagTests.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTagTests/SwiftTagTests.swift) or split them into focused test files
- Add targeted UI coverage in [SwiftTagUITests.swift](/Users/ccm/Dev/Swift/SwiftTag/SwiftTagUITests/SwiftTagUITests.swift) where Notification Center interaction is practical

## Test Strategy
- Prefer unit tests first:
  - Save notification payload encoding/decoding
  - Track-set fingerprint generation and matching rules
  - Registry behavior for registering, updating, finding, and removing editor sessions
  - Save result to notification scheduling decisions
  - Reopen descriptor persistence and lookup
- Add service-level tests with copied FLAC fixtures from `SwiftTagTestFiles`:
  - Successful tag save schedules a notification payload for only the written track set
  - Successful picture-only save schedules the correct payload kind
  - Partial failures do not schedule a success notification
- Add targeted UI tests only for app-controlled flows:
  - A save operation produces observable in-app state that confirms a notification request was enqueued or recorded in a test seam
  - Opening a new window from a simulated notification response loads the expected fixture tracks
  - Handling a simulated notification response for an already-open session brings that window forward without replacing edited text fields
- Avoid end-to-end Notification Center automation as the primary verification path unless it proves reliable in Xcode.
- Build validation should use `BuildProject`, with targeted tests preferred over full-suite runs when notification-related UI automation is unstable.

## Open Questions
- No open questions at this time. Implementation should proceed with the confirmed decisions above.

## Acceptance Criteria
- After a successful save, the app schedules a local notification that identifies the saved operation and the saved track set.
- The notification includes enough persisted context for a click response to work after a cold launch.
- Clicking the notification while the matching editor window is already open brings that window to the front without reloading tracks or overwriting in-progress edits.
- Clicking the notification when no matching window is open creates a new editor window and loads the saved tracks into that new session.
- Selected-track saves reopen or foreground using only the tracks actually written by that save.
- Notification scheduling failure or denied authorization does not cause the save operation itself to fail.
- Notification response failures caused by missing files or invalid bookmark data are surfaced cleanly and do not crash the app.
- The implementation is covered by unit tests for payloads, matching, and routing, plus targeted integration/UI verification for notification-triggered window behavior.
