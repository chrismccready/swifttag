### Conversation Transcript

Date: 2026-02-27  
Reference Type: Plan  
References: 1-FLACBridgeExecution.md  
Agent: GPT-5.3-Codex

Note: This file contains brief user/assistant conversation content related to building/linking libFLAC.

## User

I would like to add and build metallic from git repo located at https://github.com/xiph/flac.git. Ideally I would like to have the metaflac build be a C library that is wrapped for consumption by this project, replacing the existing use of the bundled metaflac cli binary. Also I would like to have the metaflac lib be built with the build of this project. Please provide an execution plan.

## Assistant

1. Clarify target architecture
- metaflac is a CLI tool; the reusable C API is in lib​FLAC (metadata APIs).
- Plan to replace CLI calls with direct lib​FLAC metadata reads/writes in a C wrapper your Swift code calls.

2. Add FLAC source as a pinned dependency
- Add https://github​.com​/xiph​/flac​.git as a git submodule (or vendored source folder) at a fixed tag/commit.
- Record license files in app bundle/docs.

3. Build libFLAC during app build
- Add an Xcode Run Script Build Phase (before Compile Sources) that:
- Configures/builds lib​FLAC from submodule source for current SDK/arch (Debug/Release aware).
- Outputs:
   - static lib: lib​FLAC​.a
   - public headers copied to a deterministic build output dir.
- Cache by config+arch to avoid rebuilding every time.

4. Create a thin C wrapper library
- New local target (e.g. Flac​Metadata​Bridge) exposing stable C functions like:
- flac​_read​_tags(const char* path, ​Flac​Tag​Result* out, char** error)
- flac​_free​_result(...)
- Internally use lib​FLAC​/metadata​.h APIs, not metaflac subprocesses.
- Normalize fields to your app model (TITLE, ARTIST, COMPOSER, etc.).

5. Expose wrapper to Swift
- Add module map / bridging header so Swift can call wrapper functions.
- Keep Swift-facing API in one file (e.g. Flac​Metadata​Service​.swift) that converts C structs to Track.

6. Replace current subprocess path
- Remove Process() + bundled metaflac resolution logic.
- Use wrapper calls inside your import flow (collect -> parse -> map -> append) with same alphanumeric ordering.

7. Error handling + UX parity
- Map wrapper errors to user-friendly messages (same alert sheet behavior you already have).
- Include low-level debug info in logs only.

8. Validation and CI
- Add tests for:
   - single file parse
   - folder import ordering
   - missing tags defaults
   - malformed file/error propagation
- Ensure CI/build machine can build the FLAC submodule.

9. Optional fallback strategy (recommended)
- Keep CLI fallback behind a build flag for initial rollout (USE​_​LIBFLAC​_​BRIDGE), remove after confidence.

If you want, next step I can draft the exact Xcode build-phase script + wrapper header/API shape so you can implement incrementally.

## Assistant (after being asked to go forward)

After initial attempts to link against pre-built libFLAC using headers (sandbox errors), changed to building from FLAC repo source:
Completed. The project now builds FLAC from source checkout and uses a Swift->C wrapper with direct lib​FLAC calls (no CLI in the runtime read path).

What I changed:

- Added local FLAC source checkout:
   - Third​Party​/flac (cloned from https://github​.com​/xiph​/flac​.git)
- Switched C bridge to direct lib​FLAC API usage:
   - FlacMetadataBridge.c
   - uses FLAC__metadata​_get​_tags and FLAC__metadata​_object​_delete
   - no dlopen, no popen, no metaflac subprocess
- Kept bridge headers self-contained via vendored FLAC headers:
   - Swift​Tag​/​FLACBridge​/vendor​/​FLAC/*.h
- Linked app target against lib​FLAC:
   - Added OTHER​_​LDFLAGS with -l​FLAC (Debug/Release) in project.pbxproj
- Existing build phase already builds/stages FLAC artifacts from source when available (uses Third​Party​/flac).

Validation:

- Full project build succeeded.

Note:
- This environment blocked git submodule add (.git​/index​.lock denied), so I used a vendored checkout at Third​Party​/flac. Functionally equivalent for now.
- If you want, I can next convert this vendored checkout to an actual submodule on your machine outside the sandbox restriction.

End of Transcript
