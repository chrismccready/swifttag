# FLAC Bridge Build Notes

## Current Architecture
- `ThirdParty/flac` is the source of truth for FLAC.
- `BuildScripts/build-libflac.sh` builds static `libFLAC.a` during Xcode builds.
- `SwiftTag/FLACBridge/src/FlacMetadataBridge.c` is the C bridge used by Swift.
- `SwiftTag/FlacMetadataService.swift` consumes the bridge API.

## Build Configuration
- FLAC is built as static-only (`BUILD_SHARED_LIBS=OFF`).
- Programs are disabled (`BUILD_PROGRAMS=OFF`).
- C++ FLAC library is disabled (`BUILD_CXXLIBS=OFF`).
- Ogg support is disabled (`WITH_OGG=OFF`).

## Output Locations
- Static library: `${DERIVED_FILE_DIR}/flac-build/install/lib/libFLAC.a`
- Staged headers: `${DERIVED_FILE_DIR}/flac-include/FLAC`

## Cleanup Status
- Legacy `metaflac` CLI runtime flow is removed.
- Legacy `.template` bridge files are removed.
- Vendored `SwiftTag/FLACBridge/vendor/FLAC` headers are removed.
- Prebuilt `Resources/bin` FLAC artifacts are removed.
