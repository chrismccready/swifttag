### Conversation Transcript

Date: 2026-04-07  
Reference Type: Bug, Test  
References: Pictures seen as different between doc loads  
Agent: GPT-5.4 Extra High (Codex app)  

Note:
- This file contains the visible user/assistant conversation content from this session.
- Hidden system and developer instructions are excluded.

## User 2026-04-07T08:29:42Z 

Opened .swifttag document shows external differences in pictures when there are no differences:
- Add two flac files to editor with one file having at least one more picture for a given type (e.g. one front cover in the first file and two front covers in the second).
- Save as .swifttag document.
- In a new window add the file that has less pictures for a type and edit tag, then save the flac file
- Open saved .swifttag file, editor will show that all tracks have external differences in pictures with only one of the tracks showing in the window text that it has (by selection) an external difference. Neither actually have any picture difference.
I suspect it has to do with seeing a difference based on picture ordering, but this is a guess.
Create a UI test that confirms the issue and fix.

## Assistant 2026-04-07T08:29:42Z (0s since User start)

I’m tracing the picture-diff flow first so we can reproduce the bug in the right layer, then I’ll add a UI test that locks the behavior down before fixing it.

I’ve got the project layout and the likely planning docs; next I’m reading the testing guide plus the document/status code that computes picture differences so we can pin the regression to a specific comparison path.

I found the exact comparison seam: picture diffs are currently canonicalized by type and original index, which means same-content multi-picture sets can still look different after a reopen if the order changes. I’m reading the existing document-load tests now so we can extend the same workflow instead of inventing a new harness.

The document load path itself looks straightforward, so I’m checking the album-art synchronization around handleOpenedSwiftTagDocument next. If that layer reorders per-track picture arrays on load, it would explain why a false picture diff can spread beyond the one externally edited file.

I’ve narrowed the likely fault line: .swifttag export canonicalizes multi-picture arrays by content, but the reopen/live comparison still treats same-type pictures as order-sensitive. That mismatch is exactly the kind of thing that would surface as a false picture diff after reopening a saved document.

Plan:

1. Add a narrow document-load regression test with multiple front covers so we can prove the comparison should be order-insensitive for equivalent picture sets.
2. Add an XCUI regression that saves a two-track .swifttag, edits only the lower-picture FLAC through the app, then reopens the document and checks that picture diff counts stay at 0.
3. Fix the picture canonicalization/comparison path so reopened document pictures are compared with the same deterministic ordering used by .swifttag export.
4. Run targeted build and test passes, then tighten anything flaky in the UI harness if needed.

I’ve got the edit set lined up: one shared picture canonicalization change, one narrow document regression test, and one XCUI scenario that exercises the reopened .swifttag path with a multi-front-cover track.

I’m applying the comparison fix first, then I’m wiring the unit and UI regressions around it so both the narrow and end-to-end paths stay covered.

The fix and both regressions are in place. I’m doing a fast diagnostics pass now so we can catch any compile or test-harness issues before running the targeted tests.

The project compiles cleanly. I have the unit-test identifier from Xcode already; I’m pulling the UI-test identifier from the generated test list so I can run both targets as narrowly as possible.

I hit a useful snag: the UI test target can see the app module headers, but it can’t link those app-internal helpers directly. I’m pivoting to the existing app-driven UI-test harness so the app itself prepares the picture variants and file mutations, which keeps the XCUI coverage intact without fragile target-linking changes.

I’m swapping the XCUI setup over to the app’s built-in launch/materialization hooks now, which keeps the test self-contained and avoids the linker dead-end from calling app internals directly out of the UI test bundle.

The narrow document regression is green now. I’m running the XCUI scenario next, which exercises the saved-document reopen path through the app’s own UI-test fixture hooks.

[ 2026-04-07T08:55:09Z (25m 27s since Assistant start) ]

## User 2026-04-07T08:55:09Z 

[ interrupted agent ]

When you typed to change a tag you lost focus and now text changes happened.

## Assistant 2026-04-07T08:55:09Z (0s since User start)

I did steal focus with the XCUI run, and I’m stopping that path right now. I’m checking for any leftover test/app processes so nothing keeps typing or clicking.

[ Context automatically compacted ]

I’m stopping the focus-stealing UI automation path here. I’m going to finish the fix safely by cleaning up the UI test code so it builds, and I won’t run that XCUI test again unless you want me to.

I’ve checked the UI test file, and the stale direct app-import helpers are no longer there. I’m reading the regression test and launch plumbing now so I can verify the safe state without re-running the focus-stealing test.

The regression UI test is wired through launch-environment fixture overrides now, which means we can at least validate the code path by building without taking focus again. I’m running a project build next.

I’ve got the safe verification now: the project builds cleanly, and I’m pulling the exact code locations so I can hand you a precise close-out without touching the UI again.

[ 2026-04-07T08:57:41Z (2m 32s since Assistant start) ]

## User 2026-04-07T08:57:41Z 

[ interrupted agent ]

No, continue with tests, I was just trying help point a potential false negative.

## Assistant 2026-04-07T08:57:41Z (0s since User start)

I’m resuming with the targeted regression UI test only, so we can confirm the fix end-to-end without broad automation. If it exposes a real failure instead of the false negative you suspected, I’ll tighten the test or the fix from there.

The test did fail, so this looks like a real remaining issue rather than just the earlier false negative. I’m pulling the failing assertion and the test log now so I can see whether the bug is still in comparison logic or in the test flow itself.

The failure is at the first subtitle assertion after reopening. I’m checking the probe helpers and the underlying status logic next so I can tell whether the app is still reporting the wrong counts or the test is asserting the wrong post-save title/selection state.

I’ve confirmed the UI probe is reading the same hidden subtitle text the window shows, so the failing assertion is about the actual computed counts. I’m looking at the subtitle derivation now to line the UI expectation up with the model behavior and see whether the first selected track should really show a selected tag difference count of 1 or 0.

I’m going to add a tiny bit of debug output to the failing UI assertion so we can see the actual subtitle value the app is publishing. That lets us distinguish “bug still present” from “test expected the wrong settled state” in one more targeted run.

I’ve added temporary assertion messages so the next run will tell us the exact subtitle the app is exposing. Running the same single UI test again now.

[ 2026-04-07T09:07:43Z (10m 2s since Assistant start) ]

## User 2026-04-07T09:07:43Z 

[ interrupted agent ]

Ok, if you are trying to change the track title in this test, you are failing, because as soon as you enter the track title field to change the title you lose focus and no changes happen. If this is your tag field to change, then either you will need to find out how to actually change this field or perhaps pick another field like Description to edit/change.

## Assistant 2026-04-07T09:07:43Z (0s since User start)

You’re right, and that lines up with what the test is doing. I’m switching the external edit in the regression flow away from the title field and onto a stable tag field so the test validates the picture-diff bug instead of the title-focus bug.

I’ve swapped the live-file edit to the album field, which should avoid the title-focus trap and keep the scenario true to “tag-only external change.” I’m rerunning that one UI test now.

The targeted regression now passes with the album-field edit, so the focus problem was indeed producing a false negative in the first version of the UI test. I’m grabbing the final file locations and then I’ll give you a tight summary with the verification results.

You were right: the first UI regression was getting a false negative because editing the title field drops focus before the save. I changed that regression to perform the external tag-only edit through the album field instead, so it now validates the picture-diff reopen bug rather than the title-focus bug.

The actual fix is shared picture canonicalization, so live external-difference checks and `.swifttag` packaging now treat equivalent multi-picture sets the same even when their order differs. Key spots are [FlacMetadataService.swift](Swift/SwiftTag/SwiftTag/FlacMetadataService.swift#L101), [TagEditorViewModel.swift](Swift/SwiftTag/SwiftTag/Features/TagEditor/TagEditorViewModel.swift#L1789), [SwiftTagDocumentPackage.swift](Swift/SwiftTag/SwiftTag/Shared/Utilities/SwiftTagDocumentPackage.swift#L520), [SwiftTagDocumentTests.swift](Swift/SwiftTag/SwiftTagTests/SwiftTagDocumentTests.swift#L648), and [SwiftTagUITests.swift](Swift/SwiftTag/SwiftTagUITests/SwiftTagUITests.swift#L630).

Verification: project build passed, `SwiftTagDocumentTests/swiftTagDocumentLoadRefreshDoesNotFlagEquivalentMultiPictureOrderingAsPictureDifference()` passed, and `SwiftTagUITests/testReopeningSavedSwiftTagDocumentIgnoresEquivalentMultiPictureOrderingAfterExternalTagSave()` passed.

[ 2026-04-07T09:10:15Z (2m 32s since Assistant start) ]

End of Transcription.