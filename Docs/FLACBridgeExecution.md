# FLAC C-Bridge Incremental Execution

## Step 1 (this change)
- Added `BuildScripts/build-libflac.sh` to build and stage `metaflac` + `libFLAC` during app builds.
- Added C API shape templates in `SwiftTag/SwiftTag/FLACBridge/`.
- Added Swift stub `FlacMetadataService.swift`.

## Step 2 (next)
- Add Run Script Build Phase:
  - Script: `${SRCROOT}/SwiftTag/BuildScripts/build-libflac.sh`
- Ensure `ThirdParty/flac` exists (git submodule checkout).
- Confirm staged outputs in app resources:
  - `Contents/Resources/bin/metaflac`
  - `Contents/Resources/bin/libFLAC.a`

## Step 3
- Activate C bridge implementation:
  - Rename `FlacMetadataBridge.c.template` -> `FlacMetadataBridge.c`
  - Rename `module.modulemap.template` -> `module.modulemap`
  - Vendored FLAC public headers now live in `SwiftTag/FLACBridge/vendor/FLAC`.
  - Build phase stages generated headers to `${DERIVED_FILE_DIR}/flac-include/FLAC`.

## Step 4
- Replace `Process`-based `metaflac` calls in `ContentView` with `FlacMetadataService.readTags`.
- Preserve existing user-facing error dialog behavior.
