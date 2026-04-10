### Conversation Transcript

Date: 2026-04-10  
Reference Type: Bug, Test  
References: when MixedStateCheckbox is disabled it does not display checkbox state  
Agent: GPT-5.4 Extra High (Codex app)  

Note:
- This file contains the visible user/assistant conversation content from this session.
- Hidden system and developer instructions are excluded.

## User 2026-04-10T20:47:59Z 

When MixedStateCheckbox is disabled it no longer visually displays checkbox state. Consult Apple’s documentation on using NSViewRepresentable and paper handling visual display of state and fix.

## Assistant 2026-04-10T20:47:59Z (0s since User start)

I’m looking into the disabled MixedStateCheckbox regression now. First I’m going to inspect the current implementation and pull the relevant Apple documentation on NSViewRepresentable and AppKit checkbox state so we can fix the behavior in the right layer.

I found the checkbox wrapper in TagEditorCoreTagsView, and the bug is likely in how the AppKit view is updated when isEnabled flips. I’m reading that implementation next and checking the exact NSButton state rules Apple documents for mixed-state checkboxes.

The wrapper is very small, which is good news: the bug surface is basically makeNSView/updateNSView. I’m checking how the checkbox is used in SwiftUI and whether we should be taking the enabled state from the SwiftUI environment instead of a custom flag, because Apple’s NSViewRepresentable docs call out using the context to keep AppKit configuration in sync.

I’ve confirmed the checkbox isn’t using SwiftUI’s disabled environment at all right now; it only copies a custom Boolean onto NSButton.isEnabled. I’m checking whether the disappearing glyph is caused by that configuration itself or by the specific AppKit setup on the button.

Apple’s AppKit docs surfaced an important clue: NSButtonCell.imageDimsWhenDisabled says switch buttons are supposed to keep their checkbox image visible when disabled, with only the text dimming. That makes me suspect our custom button configuration is pushing the control into the wrong display mode rather than the state itself being lost.

The runtime check hit a small AppKit API mismatch in my snippet, so I’m rerunning it with simpler inspection. I mainly want to verify whether our current config leaves the checkbox with no actual image content once we force .imageOnly.

I’m doing one more pass of verification before editing: I can already see the button is configured differently from a standard checkbox, but I want to confirm whether that custom setup is what makes the disabled glyph disappear rather than just dim.

The shell render path hit sandboxed Swift module-cache writes, so I’m staying inside the Xcode tooling instead. I have enough signal to move toward a fix, but I want one visual confirmation from AppKit first if I can get it through the project runtime.

The first visual comparison was interesting: a freshly rendered disabled mixed checkbox still shows the glyph. That points away from the base button type and more toward update ordering or invalidation in updateNSView when SwiftUI reconfigures an existing AppKit view.

I’m checking whether this is a regression from a recent tweak to the representable. If there’s a prior working version of the checkbox wrapper, that’ll tell us whether the visual break came from layout, update ordering, or the enabled-state plumbing.

I’ve ruled out “plain AppKit checkbox is broken when disabled.” The remaining likely culprit is the SwiftUI wrapper path itself, so I’m rendering the representable through NSHostingView to see how the wrapped control behaves once SwiftUI owns its updates.

I’ve got a documentation-backed direction now. AppKit’s imageDimsWhenDisabled docs explain why an image-only checkbox can stop communicating disabledness, and SwiftUI’s NSViewRepresentable docs point to using the environment during updates. I’m switching to implementation and adding a focused regression test around the hosted checkbox.

I’m making two targeted changes in the wrapper: use SwiftUI’s isEnabled environment when updating the AppKit view, and opt into dimming the checkbox image when disabled so an image-only checkbox still communicates state visually. After that I’m wiring a hosted regression test around the real SwiftUI/AppKit bridge.

The fix and regression tests are in. I’m running compiler checks and the two targeted tests now so we can make sure the wrapper still bridges correctly and the disabled behavior stays covered.

The targeted regression tests passed, which is a good sign that the bridge now honors both disabled sources and keeps the checkbox configured for a visible disabled image. I’m doing a full project build as a final sanity check.

The build is clean and the focused tests passed. I’m wrapping up with the exact production/test references and the Apple docs rationale we used so this fix is easy to verify later.

Fixed `MixedStateCheckbox` in [TagEditorCoreTagsView.swift:293](Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorCoreTagsView.swift#L293) by following the Apple guidance we checked: `updateNSView` now respects SwiftUI’s environment-enabled state via [`NSViewRepresentableContext.environment`](https://developer.apple.com/documentation/swiftui/nsviewrepresentablecontext/environment), and the AppKit checkbox cell now sets [`imageDimsWhenDisabled`](https://developer.apple.com/documentation/appkit/nsbuttoncell/imagedimswhendisabled) after `setButtonType(.switch)` so this image-only checkbox still communicates disabled state visually. The wrapper also forces a redraw after state/enabled updates.

Added regression coverage in [TrackStatusViewInspectorTests.swift:647](Swift/SwiftTag/SwiftTagTests/TrackStatusViewInspectorTests.swift#L647) for the disabled mixed-state checkbox and for SwiftUI `.disabled(true)` propagation. Verified with `BuildProject` plus 2 targeted tests, both passing.

[ 2026-04-10T20:59:12Z (11m 13s since Assistant start) ]

## User 2026-04-10T21:13:10Z 

The bug still exists, to reproduce:
- Add flac track to editor
- Select flac track
- Select Compilation, checkbox is displayed
- Lock flac track, checkbox state is hidden and only default disabled unchecked state is displayed.
Create a UI test to confirm issue and then fix. Consult Apple documentation as needed.

## Assistant 2026-04-10T21:13:10Z (0s since User start)

I’m reproducing the lock-path regression now and tracing the checkbox from the UI state down into the AppKit wrapper. I’ll inspect the compilation/lock logic, add a focused UI test that demonstrates the broken behavior, then patch the real source of the mismatch.

I found the likely decision point in TagEditorViewModel: the compilation control derives both its state and editability from the set of editable track indices. I’m reading that path in full now, because the lock transition probably changes the data source for state itself instead of just disabling interaction.

The current ContentView fallback is a big clue: if the view model returns nil, the UI forces .off. I’m opening compilationTrackIndices next, because locking may be emptying the editable set and collapsing a previously real state into that default unchecked rendering.

That confirms the root cause is probably upstream, not the AppKit drawing: the control’s display state currently excludes locked tracks entirely, so a selected locked track can drop the state to nil and then ContentView renders .off. I’m inspecting the UI test harness around track import/locking so we can capture that exact flow before patching the view model.

I’ve got a convenient UI-test path already: the harness can auto-import the fixture track, so we only need to select it, lock it, and inspect the compilation control. I’m opening those helpers now and I’ll likely add an accessibility identifier to the representable so the test can assert the real tri-state value instead of relying on generic control queries.

I’m putting the UI test on solid footing before changing behavior: the compilation checkbox is image-only, so I’m checking whether it already exposes a stable accessibility handle. If not, I’ll add one along with an explicit label/value so the test can verify the locked-state rendering instead of guessing at generic AppKit roles.

I’m narrowing the UI-test shape now. Apple’s AppKit accessibility docs are useful here: since this is an image-only NSButton, we should give it an explicit accessibility label/identifier anyway. That will let the UI test target the real checkbox cleanly and it also improves the control for users relying on accessibility.

I’m checking the fixture metadata before writing the UI assertion. If the shipped test.flac already has COMPILATION=1, the regression test can assert a locked checked state directly; if not, I’ll toggle it on first and then lock the track.

I’ve got the model tradeoff in view now. There are two reasonable sources of truth for the checkbox state: all tracks in scope, or only the editable unlocked tracks. I’m checking where compilationTrackIDs feeds the rest of the UI so we can keep the current editing semantics intact while still restoring the disabled display state.

I’m at the test-writing step now. The plan is: give the image-only checkbox a stable accessibility hook, drive the real UI by turning Compilation on, lock the selected track through the track-list context menu, and assert the checkbox stays disabled but still reports the selected track’s on-state.

I’m editing two spots now: the checkbox wrapper gets an explicit AppKit accessibility identifier/label, and the UI test suite gets a new lock-flow regression test plus a small helper for the track-list context menu. After that I’ll run just that test to capture the failure before changing the model logic.


The regression test is in place and I’m running it against the current behavior now. This should tell us whether the failure is exactly the lock-to-off transition we traced in the view model or if there’s a second accessibility/control issue hiding underneath it.

The new UI test failed exactly where we expected, so I’m patching the model now. The fix is to keep the checkbox’s display state derived from the selected scope when there are no editable tracks left, while leaving mutation logic restricted to unlocked tracks.

The model change is in, along with a focused unit test for the locked-selection case. I’m running the targeted unit test and the failing UI test together now to make sure we fixed the real regression rather than just improving accessibility.

The targeted tests are green now, including the UI repro. I’m doing a final full build and then I’ll summarize the behavior change with the exact files we touched and the Apple docs that informed the fix.

The regression is fixed in the model layer, not just the AppKit wrapper. In [TagEditorViewModel.swift:548](Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift#L548) and [TagEditorViewModel.swift:2483](Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift#L2483), the compilation checkbox now keeps its display state from the selected scope when there are no editable unlocked tracks left, while edits still apply only to unlocked tracks. That preserves the selected track’s compilation state after locking instead of collapsing to the `.off` fallback. I also added an explicit AppKit accessibility identifier/label in [TagEditorCoreTagsView.swift:293](Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorCoreTagsView.swift#L293) so the image-only checkbox is testable and better exposed to accessibility clients.

The repro is covered by a new UI test in [SwiftTagUITests.swift:1202](Swift/SwiftTag/SwiftTagUITests/SwiftTagUITests.swift#L1202), and there’s a matching view-model regression test in [SwiftTagTests.swift:3866](Swift/SwiftTag/SwiftTagTests/SwiftTagTests.swift#L3866). I used Apple’s docs for [`NSButton.state`](https://developer.apple.com/documentation/appkit/nsbutton/state), [`NSButton.ButtonType.switch`](https://developer.apple.com/documentation/appkit/nsbutton/buttontype/switch), [`NSButtonCell.imageDimsWhenDisabled`](https://developer.apple.com/documentation/appkit/nsbuttoncell/imagedimswhendisabled), and [`NSAccessibilityProtocol.setAccessibilityIdentifier(_:)`](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/setaccessibilityidentifier(_:)) to keep the checkbox behavior and test hook aligned with AppKit.

Verified with:
- `SwiftTagUITests/testCompilationCheckboxRetainsOnStateWhenSelectedTrackIsLocked()`
- `SwiftTagTests/tagEditorViewModelCompilationToggleRetainsSelectedLockedTrackStateWhenReadOnly()`
- full project build via `BuildProject`

[ 2026-04-10T21:22:31Z (9m 21s since Assistant start) ]

End of Transcription.