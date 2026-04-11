### Conversation Transcript

Date: 2026-04-11  
Reference Type: Plan  
References: 23-AddSwiftTagDocumentQuickLook.md  
Agent: GPT-5.4 High/Extra High (VSCode/Codex app)  

Note:
- This file contains the visible user/assistant conversation content from this session.
- Hidden system and developer instructions are excluded.

## User 2026-04-11T01:46:02Z 

Create a plan to create a `.swifttag` document QuickLook App Extensions (.appex):
- The QuickLook App Extension (.appex) will be installed inside the app’s Plugins folder.
- The Quicklook preview will contain:
    - A background image of either:
        - If it exists, the first front cover picture (FLAC picture type 3) from the SwiftTag document.
        - Or the SwiftTag app icon.
    - The FLAC track tags:
        - Formatted with 1.5x system label font size for ALBUM and regular system label font size for other tags.
        - The layout will be like:
        ```
        ALBUM
        ALBUMARTIST (if not empty)
        ARTIST (if all tracks share the same ARTIST and it is not the same as ALBUMARTIST)
        TRACKNUMBER (not zero padded) <space><space> TITLE
        (repeat tracks in order of TRACKNUMBER up to what will fit in space, if there are more tracks than can fit into space, then the last track space should be used for "...")
        ```
Save plan to 23-AddSwiftTagDocumentQuickLook.md. Ask questions for clarification. Review Apple's documentation thoroughly and add any needed implementation information so that the latest API/technology is being used.

## Assistant 2026-04-11T01:46:02Z (0s since User start)

I’m gathering the project’s planning conventions, the current SwiftTag document implementation, and Apple’s Quick Look extension APIs before I draft the plan and ask for targeted clarifications.

I’ve confirmed the recent plan format and the existing SwiftTag document utilities; next I’m checking the document package shape and Apple Quick Look extension APIs so the new plan is concrete rather than speculative.

I have the local document/package context. I’m moving to Apple docs now so the plan can name the right extension point, API surface, Info.plist keys, and testing constraints for current macOS.

I’ve got enough local and API context to narrow the genuine ambiguities. I’m asking only the decisions that materially affect filesystem access, layout behavior, and deterministic rendering in the plan.

Q: Should the Quick Look preview render strictly from the saved .swifttag package contents, without trying to reopen referenced FLAC files or bookmarks?
A: Package contents only - Use only the saved manifest and bundled picture assets inside the .swifttag document
Q: If TRACKNUMBER is missing, non-numeric, or duplicated, what fallback ordering should the preview use?
A: Saved document order - Keep the .swifttag track order as the tie-breaker and fallback
Q: How should the background image be fit behind the text?
A: Fill, crop and blur image behind text for text legibility.
Q: When the track list overflows, should the last visible track row always be replaced by a single ... row?
A: Yes - Reserve the final available row for ... when not all tracks fit

The clarifications are enough to keep the plan concrete. I’m filling in the remaining implementation specifics: current package contents, track model details, app UTI setup, and the exact Quick Look extension metadata Apple expects.

I’ve got the API and package facts. I’m using a read-only codebase pass now to identify the exact SwiftTag seams a Quick Look target should reuse versus duplicate, and any Xcode target/build implications the plan should call out.

I’ve identified the reuse seam: the existing package reader is already the right entry point. I’m doing one last pass for method signatures and test patterns, then I’ll write the plan file with confirmed decisions, risks, and phased implementation details.

The remaining unknown is just project wiring. I’m checking whether the Xcode project already has any extension-style embedding patterns so the plan can say exactly what needs to be added.

I didn’t get project-file hits on the first pass because the Xcode project is ignored by search defaults. I’m rerunning against ignored files so the plan can mention the actual target/embed work instead of guessing.

The project uses the newer filesystem-synchronized Xcode layout and currently has no extension target. I’m checking the relevant build settings once so the plan can call out the minimum target, bridging header, and bundle wiring accurately.

I want the plan to reflect the modern rendering option, not just the minimum viable one. I’m checking SwiftUI’s current rendering APIs before I lock in whether the plan should recommend AppKit-only drawing or a SwiftUI view rendered inside the data-based provider.

The plan is ready to write. I’m checking the earlier .swifttag document plans once so the new plan doesn’t accidentally contradict an existing document-format or file-access decision.

I have everything needed. I’m writing the plan file now with the clarified decisions, the current Apple API guidance, and concrete implementation/test phases.

The plan file is in place. I’m grabbing the required UTC timestamp now, then I’ll give you the concise result and the key choices captured in the plan.

The plan includes the clarification answers you requested and folds in the current Apple approach for Quick Look preview extensions: a data-based Quick Look Preview appex embedded in the app’s PlugIns folder, using the async preview-provider API, QLPreviewReply, and SwiftUI ImageRenderer as the preferred rendering path for a static composed preview. It also calls out the key implementation constraints that matter here: the extension should read only the saved .swifttag package, should not depend on live FLAC access or libFLAC, and needs its own bundled fallback icon resource because the appex is a separate bundle/process.

The confirmed behavior in the plan is package-only preview data, saved-document-order fallback for ambiguous track numbers, a fill/crop/blur background treatment, and replacing the last visible track row with ... when the list overflows. It also includes phased target setup, shared snapshot/layout extraction, render strategy, risks, and a test/manual verification path.

1. Implement the extension target and shared preview snapshot layer next.
2. If you want, I can turn this plan directly into the initial appex target/file scaffold.

[ 2026-04-11T01:58:37Z (12m 35s since Assistant start) ]

## User 2026-04-11T15:52:18Z (14h 6m 17s since previous Assistant start) 

Review plan 23-AddSwiftTagDocumentQuickLook.md, ask questions for any additional clarification, and implement. Be sure to consult Apple’s documentation on QuickLook App Extensions (.appex).

## Assistant 2026-04-11T15:52:18Z (0s since User start)

Reviewing the numbered plan, the related guides, and the current Quick Look implementation points first so we can confirm the intended behavior before changing anything. I’ll also check Apple’s current Quick Look App Extension guidance and then move into implementation with targeted verification.

I’ve finished the plan read and there aren’t any unresolved product questions in the plan itself, so I’m validating it against the existing document/package code and test helpers now. Next I’m checking the shared reader, the latest save-options plan, and the testing guide so the extension stays aligned with the current document model and project conventions.

I have enough context to sketch the implementation seams now: shared snapshot logic, a thin Quick Look provider, extension resources/config, and focused tests. I’m consulting Apple’s Quick Look extension docs next to verify the exact extension point and reply API, then I’ll wire the project target and shared rendering path around those constraints.

The plan looks implementable as written, and I haven’t found a blocker that needs product clarification yet. I’m digging into the Xcode project layout and Apple’s Quick Look docs now because the main risk is wiring the .appex target and reply API correctly without fighting the filesystem-synced project structure.

Apple’s SDK headers helped a lot: the extension is still the standard Quick Look preview extension point, QLPreviewProvider is the principal class for data-based previews, and the reply APIs we need are present in the current macOS 26 SDK. I’m reading the exact header signatures now so the Swift implementation matches what Quick Look actually expects instead of relying on plan prose alone.

The project setup is clearer now: it’s a filesystem-synced Xcode project, so the safest route is a dedicated extension folder plus a very small shared preview-support slice, instead of trying to compile the full app into the .appex. I’m tracing the exact shared types the package reader needs so the extension can stay independent from libFLAC and the main app UI, as the plan requires.

One implementation detail changed slightly after checking the SDK: Apple’s current macOS 26 Quick Look headers still expose the provider entry point as providePreview(for:completionHandler:), so I’m going to compile against that concrete API and only rely on an async wrapper if the Swift importer proves it exists. I’m verifying the SwiftUI rendering API next so the preview reply is generated in a way Quick Look actually accepts.

The SwiftUI docs confirm the key bit I needed: ImageRenderer can render directly into an arbitrary CGContext, which gives us a clean bridge into Quick Look’s drawing/PDF reply APIs without pulling AppKit views into the extension. I’m turning that into concrete code structure now and checking which shared picture/document types need to be lifted out of the FLAC service so the extension remains bridge-free.

I’m at the Xcode target-wiring step now, which is the most mechanical part of the change. Before I edit the project file, I’m checking Apple/Xcode’s own template conventions for Quick Look extensions so the target product type, embedding phase, and Info.plist shape match what Xcode would generate.

Xcode’s own macOS Quick Look template confirms a couple of important project details: it uses the normal app-extension product type, the com.apple.quicklook.preview extension point, and the extension target gets its own sandbox/read-only file access. I’m checking the template’s data-based variant cues next so I can set QLIsDataBasedPreview and the principal class correctly for a provider-driven implementation.

Implementation is ready to move in three slices:

1. Refactor the document-package support into smaller shared files so the extension can reuse the reader without dragging in the FLAC bridge.
2. Add the shared Quick Look snapshot/render/PDF pipeline plus the .appex target, Info.plist, embedded fallback artwork, and app embed phase.
3. Add focused tests for snapshot rules and PDF generation, then build and verify the extension bundle is embedded correctly.

No extra product clarification is blocking me right now, so I’m proceeding on the plan’s current rules and I’ll call out any assumptions I had to make if one surfaces during coding.

I’m in the main refactor pass now: breaking the document package code into reader/writer/shared support so the extension can reuse only the safe slice. After that I’ll layer the Quick Look snapshot/render code on top and wire the target into the project.

The package split is in place, and I’m adding the actual Quick Look preview pipeline now: pure snapshot rules first, then the SwiftUI/PDF renderer, then the provider that hands that data back to Quick Look. After this pass I’ll wire the .appex target into Xcode and use the compiler to shake out any API mismatches.

The package split is in place, and I’m adding the actual Quick Look preview pipeline now: pure snapshot rules first, then the SwiftUI/PDF renderer, then the provider that hands that data back to Quick Look. After this pass I’ll wire the .appex target into Xcode and use the compiler to shake out any API mismatches.

I’ve reached the project-file wiring step. I’m editing the Xcode project now to add the extension target, its resource embedding phase, and the minimal shared source set the .appex needs; once that lands I can compile and fix any remaining API mismatches instead of guessing.

I’ve reached the project-file wiring step. I’m editing the Xcode project now to add the extension target, its resource embedding phase, and the minimal shared source set the .appex needs; once that lands I can compile and fix any remaining API mismatches instead of guessing.

The extension target is now wired into the project. I’m moving into compile-and-fix mode next so we can catch any SwiftUI/Quick Look API mismatches before I add the focused tests on top of the final shapes.

The extension target is now wired into the project. I’m moving into compile-and-fix mode next so we can catch any SwiftUI/Quick Look API mismatches before I add the focused tests on top of the final shapes.

The first compile surfaced a small pure-Swift issue in the snapshot model, which is a good sign: the build is already reaching the new Quick Look code. I’m fixing that now and then I’ll rebuild to get the next round of real integration errors, if any.

The first compile surfaced a small pure-Swift issue in the snapshot model, which is a good sign: the build is already reaching the new Quick Look code. I’m fixing that now and then I’ll rebuild to get the next round of real integration errors, if any.

The next build made it all the way to app-extension embedding, and the remaining issue is packaging-level rather than code-level. I’m tightening the extension bundle identifier to match Xcode’s embed rules exactly and then rebuilding.

The next build made it all the way to app-extension embedding, and the remaining issue is packaging-level rather than code-level. I’m tightening the extension bundle identifier to match Xcode’s embed rules exactly and then rebuilding.

The embedding error is coming from Xcode’s validation step rather than the Swift code, so I’m checking the effective build settings and built Info.plists now. That will tell us whether the extension target is inheriting something unexpected or whether the copy phase needs a different target relationship.

I’ve isolated the problem to Xcode’s embedded-binary validator, so I’m inspecting the built app and extension metadata directly next. That should tell us whether the extension bundle id is being generated differently than the project file says, or whether the embed phase is still attached in a way Xcode doesn’t like.

I found the packaging issue: the built .appex Info.plist is missing the standard CFBundle* keys, including CFBundleIdentifier, so the validator can’t see the prefix relationship even though the build setting is there. I’m fixing the extension plist to include the standard placeholders and then rebuilding.

I found the packaging issue: the built .appex Info.plist is missing the standard CFBundle* keys, including CFBundleIdentifier, so the validator can’t see the prefix relationship even though the build setting is there. I’m fixing the extension plist to include the standard placeholders and then rebuilding.

The build is green now, so I’m locking in targeted coverage before doing the final verification pass. I’m focusing the tests on exactly what the plan calls out: background selection, shared-line rules, ordering/ellipsis behavior, and a lightweight PDF render smoke path.

The build is green now, so I’m locking in targeted coverage before doing the final verification pass. I’m focusing the tests on exactly what the plan calls out: background selection, shared-line rules, ordering/ellipsis behavior, and a lightweight PDF render smoke path.

The targeted tests are in place and the project still builds cleanly. I’m grabbing the exact test identifiers from Xcode now so I can run only the Quick Look coverage instead of burning time on the whole suite.

The targeted tests are in place and the project still builds cleanly. I’m grabbing the exact test identifiers from Xcode now so I can run only the Quick Look coverage instead of burning time on the whole suite.

Xcode’s test-list tooling isn’t exposing the Swift Testing cases cleanly here, and a full MCP test run hit the environment timeout. I’m trying a narrow xcodebuild test invocation next; if the sandbox blocks the derived-data/package-cache writes it needs, I’ll ask for approval to rerun it outside the sandbox instead of guessing about the results.

The targeted xcodebuild test run is underway with the permissions it needs. I’m letting that finish and then I’ll do the final bundle/embed verification plus a quick pass over any remaining risks.

The targeted xcodebuild test run is underway with the permissions it needs. I’m letting that finish and then I’ll do the final bundle/embed verification plus a quick pass over any remaining risks.

[ Context automatically compacted ]

I’ve finished the main implementation and I’m checking the last verification pieces now: Apple Quick Look extension docs for the final sanity pass, then the targeted Quick Look tests/build state so I can give you a clean result.

[ 2026-04-11T17:58:03Z (2h 5m 45s since Assistant start) ]

## User 2026-04-11T17:58:03Z

[ interrupted agent, UI tests were interrupted/unable to complete ]

UI tests were interrupted by user. Disregard results from most recently run tests. Rerun tests and continue implementation.

## Assistant 2026-04-11T17:58:03Z (0s since User start)

I’m treating the last interrupted run as invalid and starting verification fresh. First I’m checking whether any old xcodebuild process is still hanging around, then I’ll rerun the focused Quick Look tests and rebuild if needed.

Apple’s Quick Look docs confirm the data-based .appex path we implemented: subclass QLPreviewProvider, conform to QLPreviewingController, set QLIsDataBasedPreview, list QLSupportedContentTypes, and return a QLPreviewReply. I’m pulling the concrete test identifiers next so I can rerun only the new Quick Look coverage cleanly.

I’ve got the exact Quick Look test identifiers now. I’m rerunning a focused batch that covers the new preview snapshot/PDF path plus the document reader and picture utilities that were refactored to support the extension target.

One focused test failed, and it’s a good catch: the overflow logic is collapsing the whole track list to just ... instead of preserving the visible rows before the ellipsis. I’m reading the snapshot code and the test expectation side by side, then I’ll patch and rerun that slice.

The failure is isolated to the row-budget math, not the extension wiring itself. I’m checking the test’s custom layout helper now, because the current height budget may simply be too short for the expected three visible rows under the new spacing rules.

The math is behaving consistently with the current layout constants, so this looks like a stale test fixture rather than a product bug. I’m checking the preview view against the snapshot calculation once more, then I’ll update the test to use a height that really leaves room for two rows plus the ellipsis row.

I traced this back to the test fixture height, not the preview logic. I’m making a small test-only patch so the overflow case actually budgets for two visible rows plus the ellipsis row, then I’ll rerun the same focused batch.

The first patch attempt missed the repo-relative path. I’m applying the same small test fix against the correct file now.

The test fixture is updated. I’m rerunning the same focused verification set now so we can confirm the Quick Look path and the shared document refactor both stay green together.

The focused tests are green now. I’m doing one last project build pass and a quick workspace diff check so I can close this out with the implementation summary and any assumptions clearly called out.

The build is clean. git diff --stat only showed part of the picture because the new files are still untracked in that view, so I’m checking git status before I summarize the final file set.

I’m checking one last project-metadata diff before wrapping up. The main implementation is done; this is just to separate intentional target wiring from any incidental Xcode user-data noise.

There’s one incidental Xcode user-data change in xcschememanagement.plist that isn’t needed for the feature itself. I’m trimming that noise so the remaining diff stays focused on the Quick Look extension and its shared support code.

The cleanup patch is in. I’m doing a last quick status check, then I’ll summarize what shipped and the one non-blocking assumption set I carried from the plan.

Plan 23 was specific enough to implement without a blocking clarification stop, so I went ahead and shipped it. I also checked Apple’s Quick Look app-extension guidance for the data-based path and aligned the implementation with `QLPreviewProvider`/`QLPreviewReply`, `QLIsDataBasedPreview`, and `QLSupportedContentTypes`.

The main work is in [SwiftTagDocumentQuickLookPreviewProvider.swift](Swift/SwiftTag/SwiftTagQuickLookPreview/SwiftTagDocumentQuickLookPreviewProvider.swift), with shared snapshot/rendering support in [SwiftTagDocumentQuickLookSnapshot.swift](Swift/SwiftTag/SwiftTag/Shared/QuickLook/SwiftTagDocumentQuickLookSnapshot.swift), [SwiftTagDocumentQuickLookView.swift](Swift/SwiftTag/SwiftTag/Shared/QuickLook/SwiftTagDocumentQuickLookView.swift), and [SwiftTagDocumentQuickLookPDFRenderer.swift](Swift/SwiftTag/SwiftTag/Shared/QuickLook/SwiftTagDocumentQuickLookPDFRenderer.swift). To make the `.appex` target reuse document/package logic cleanly, I split the old monolithic document helper into reader/writer/shared pieces and pulled FLAC picture models/utilities out of [FlacMetadataService.swift](Swift/SwiftTag/SwiftTag/FlacMetadataService.swift). I also added focused regression coverage in [SwiftTagQuickLookTests.swift](Swift/SwiftTag/SwiftTagTests/SwiftTagQuickLookTests.swift).

Verification is clean: `BuildProject` succeeded, and after disregarding the interrupted run I reran the focused non-UI test batch with 11/11 passing, including all new Quick Look tests plus relevant existing SwiftTag document/picture tests. The current preview behavior assumes the first saved type-3 front cover becomes the background, falls back to the bundled image otherwise, and falls back from shared album metadata to the first non-empty album or the document filename when needed.

[ 2026-04-11T18:01:43Z (3m 40s since Assistant start) ]

## User 2026-04-11T18:50:16Z (52m 13s since previous Assistant start) 

The final QuickLook presentation is large. I am seeing `canvasSize: CGSize(width: 900, height: 900)` on line 21 of `SwiftTagDocumentQuickLookSnapshot.swift`, but it looks like the final QuickLook presentation is larger (like around 1200x1200). Can the final presentation size be controlled? Limiting to 640x640 is preferable.

## Assistant 2026-04-11T18:50:16Z (0s since User start)

I’m checking how Quick Look treats the preview’s declared size versus the rendered PDF page size, then I’ll tighten the implementation to target a 640×640 preview if the API allows it.

I found the key detail in Apple’s API surface: QLPreviewReply has a dedicated PDF initializer with a page size, which is a better fit than the generic data/content-size initializer when we want to constrain the preview document itself. I’m checking the current provider and renderer now so I can switch that over cleanly.

I’m making two changes: set the default preview layout to a 640×640 design, and switch the extension to Quick Look’s PDF-specific reply initializer so the preview’s intrinsic page size is declared more directly.

The code is updated. I’m adding one tiny regression test for the default canvas size, then I’ll rebuild and rerun the focused Quick Look tests so we can confirm the new behavior compiles cleanly.

The change is verified. I’m writing up the exact limitation here, because this is one of those places where Finder/Quick Look keeps some control even after we set the preview size from the extension.

Yes, but only partially.

The extension can control the preview’s intrinsic document/canvas size, but Finder/Quick Look still controls the surrounding viewer and may scale the content to fit. In other words, we can set the preview to 640×640, but we can’t hard-cap the Finder Quick Look window itself from the extension.

I updated the default Quick Look layout to `640x640` in [SwiftTagDocumentQuickLookSnapshot.swift](Swift/SwiftTag/SwiftTag/Shared/QuickLook/SwiftTagDocumentQuickLookSnapshot.swift:20), and I changed the provider to use Quick Look’s PDF-specific initializer in [SwiftTagDocumentQuickLookPreviewProvider.swift](Swift/SwiftTag/SwiftTagQuickLookPreview/SwiftTagDocumentQuickLookPreviewProvider.swift:22), which is the more direct Apple-supported way to declare the preview page size for a PDF reply. I also added a regression test for the 640×640 default in [SwiftTagQuickLookTests.swift](Swift/SwiftTag/SwiftTagTests/SwiftTagQuickLookTests.swift:129).

Build passed, and the focused Quick Look test batch passed 7/7.

If Finder still presents the preview larger than you want after this, the likely reason is PDF auto-scaling by Quick Look. The next step would be switching from a PDF reply to a bitmap/context-based reply, which gives us a better shot at keeping the visible preview more compact.

[ 2026-04-11T18:53:37Z (3m 21s since Assistant start) ]

## User 2026-04-11T19:54:54Z (1h 4m 39s since previous Assistant start) 

Let’s use a bitmap/context-based reply instead of PDF. 

## Assistant 2026-04-11T19:54:54Z (0s since User start)

I’m switching the extension over to Quick Look’s context-based reply path now. I’ll confirm the exact API shape from Apple’s docs, then refactor the current PDF renderer into a CGContext renderer and rerun the focused Quick Look tests.

I’ve got the API shape from Apple’s docs: QLPreviewReply(contextSize:isBitmap:drawUsing:) is the right initializer here. I’m updating the renderer and tests together so we don’t leave the Quick Look path half-switched.

The sync drawUsing closure has one tricky bit: it isn’t async, so I don’t want to depend on SwiftUI rendering there directly. I’m switching to a safer shape where we render the SwiftUI preview to a CGImage on the main actor up front, then the Quick Look reply simply draws that bitmap into the supplied context.

I’m replacing the PDF renderer with a bitmap renderer in place so the target wiring stays simple. After that I’ll update the one renderer smoke test to validate bitmap output instead of PDF bytes.

The bitmap-path refactor is in. I’m rebuilding and running the focused Quick Look tests now; if there’s any concurrency or CGContext mismatch from the new reply initializer, this pass should flush it out immediately.

The behavior is working now. I’m doing one cleanup rename so the shared renderer file matches the new bitmap-based implementation instead of still carrying the old PDF name.

The rename is in. I’m doing a quick build and search pass to make sure the project references followed the move cleanly and there aren’t any stale PDF-renderer mentions left behind.

The filesystem rename didn’t update the project file, so Xcode is still looking for the old path. I’m patching those stale references directly, then I’ll rebuild once more.

The project references are fixed. I’m running the final build and focused Quick Look tests one more time so we end on a clean bitmap-based state after the rename.

The build is clean; the only hiccup is the test runner still using a stale identifier list after the latest file changes. I’m refreshing the test list and rerunning the Quick Look slice with the current identifiers.

The Xcode test-list endpoint is being flaky right now, so I’m falling back to a direct targeted xcodebuild test run for SwiftTagQuickLookTests only. That keeps verification narrow without depending on the stale identifier cache.

The in-app focused tests already passed before this fallback, and the current build is clean after the file rename. The direct xcodebuild check hit the usual sandbox wall on Xcode caches, so I’m requesting permission to rerun that one targeted Quick Look test command outside the sandbox.

The escalated targeted test run is underway now. I’m waiting on the final SwiftTagQuickLookTests result so I can close this out with a clean bitmap-based verification summary.

The escalated test run is still active and past the build/signing phase now. I’m polling once more for the actual TEST SUCCEEDED / failure summary before I wrap up.

The bitmap implementation is passing end to end now. I noticed one remaining compiler warning from the renderer’s default-argument isolation, so I’m clearing that too before I stop.

I’ve removed the warning-producing default arguments. I’m doing one last build and checking the build log for any remaining warnings tied to the bitmap renderer file.

The Quick Look extension now uses a bitmap/context-based reply instead of PDF.

I switched [SwiftTagDocumentQuickLookPreviewProvider.swift](Swift/SwiftTag/SwiftTagQuickLookPreview/SwiftTagDocumentQuickLookPreviewProvider.swift) to Apple’s `QLPreviewReply(contextSize:isBitmap:drawUsing:)` path, which is the context-based API documented in QuickLookUI. The SwiftUI preview is now rasterized up front to a `CGImage` in [SwiftTagDocumentQuickLookBitmapRenderer.swift](Swift/SwiftTag/SwiftTag/Shared/QuickLook/SwiftTagDocumentQuickLookBitmapRenderer.swift), and the reply draws that bitmap into the supplied `CGContext`. The 640×640 layout remains in [SwiftTagDocumentQuickLookSnapshot.swift](Swift/SwiftTag/SwiftTag/Shared/QuickLook/SwiftTagDocumentQuickLookSnapshot.swift).

I also replaced the old PDF smoke test with a bitmap-renderer test in [SwiftTagQuickLookTests.swift](Swift/SwiftTag/SwiftTagTests/SwiftTagQuickLookTests.swift). Verification is clean: `BuildProject` succeeded, the focused in-app Quick Look test batch passed earlier, and the direct targeted `xcodebuild` run for `SwiftTagQuickLookTests` completed with `** TEST SUCCEEDED **`.

This gives us a true bitmap preview instead of a PDF page, which should better match the compact 640×640 intent, though Finder can still choose how large to display that bitmap in the surrounding Quick Look window.

[ 2026-04-11T20:00:43Z (5m 49s since Assistant start) ]

End of Transcription.