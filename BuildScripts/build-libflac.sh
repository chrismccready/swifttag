#!/bin/bash
set -euo pipefail

# Build libFLAC + metaflac from a local FLAC git checkout and stage outputs for app resources.
# Intended for use in an Xcode Run Script Build Phase.
#
# Expected FLAC checkout location (override with FLAC_SOURCE_DIR env var):
#   ${SRCROOT}/ThirdParty/flac
#
# Build output staging:
#   ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/bin

FLAC_SOURCE_DIR="${FLAC_SOURCE_DIR:-${SRCROOT}/ThirdParty/flac}"
if [[ ! -d "${FLAC_SOURCE_DIR}" ]]; then
  echo "warning: FLAC source not found at ${FLAC_SOURCE_DIR}; skipping libFLAC build"
  exit 0
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "warning: cmake is not available; skipping libFLAC build"
  exit 0
fi

BUILD_ROOT="${DERIVED_FILE_DIR}/flac-build"
INSTALL_ROOT="${BUILD_ROOT}/install"
RESOURCE_BIN_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/bin"

mkdir -p "${BUILD_ROOT}" "${INSTALL_ROOT}" "${RESOURCE_BIN_DIR}"

# Resolve primary arch for single-config local builds.
PRIMARY_ARCH="${CURRENT_ARCH:-arm64}"
if [[ -z "${PRIMARY_ARCH}" || "${PRIMARY_ARCH}" == "undefined_arch" ]]; then
  PRIMARY_ARCH="arm64"
fi

# Map Xcode config to CMake config.
CMAKE_CONFIG="Release"
if [[ "${CONFIGURATION:-Release}" == "Debug" ]]; then
  CMAKE_CONFIG="Debug"
fi

CMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"

cmake -S "${FLAC_SOURCE_DIR}" -B "${BUILD_ROOT}" \
  -DCMAKE_BUILD_TYPE="${CMAKE_CONFIG}" \
  -DCMAKE_OSX_ARCHITECTURES="${PRIMARY_ARCH}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${CMAKE_OSX_DEPLOYMENT_TARGET}" \
  -DBUILD_PROGRAMS=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF \
  -DINSTALL_MANPAGES=OFF \
  -DINSTALL_PKGCONFIG_MODULE=OFF \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_ROOT}"

cmake --build "${BUILD_ROOT}" --config "${CMAKE_CONFIG}" --target metaflac FLAC
cmake --install "${BUILD_ROOT}" --config "${CMAKE_CONFIG}"

# Stage binary + library artifacts into app resources.
if [[ -f "${INSTALL_ROOT}/bin/metaflac" ]]; then
  cp -f "${INSTALL_ROOT}/bin/metaflac" "${RESOURCE_BIN_DIR}/metaflac"
  chmod +x "${RESOURCE_BIN_DIR}/metaflac"
else
  echo "error: expected metaflac at ${INSTALL_ROOT}/bin/metaflac"
  exit 1
fi

if [[ -f "${INSTALL_ROOT}/lib/libFLAC.a" ]]; then
  cp -f "${INSTALL_ROOT}/lib/libFLAC.a" "${RESOURCE_BIN_DIR}/libFLAC.a"
fi

if [[ -f "${INSTALL_ROOT}/lib/libFLAC.dylib" ]]; then
  cp -f "${INSTALL_ROOT}/lib/libFLAC.dylib" "${RESOURCE_BIN_DIR}/libFLAC.dylib"
fi

echo "Built FLAC artifacts staged to ${RESOURCE_BIN_DIR}"
