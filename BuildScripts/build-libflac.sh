#!/bin/bash
set -euo pipefail

# Build static libFLAC from a local FLAC git checkout.
# Intended for use in an Xcode Run Script Build Phase.
#
# Expected FLAC checkout location (override with FLAC_SOURCE_DIR env var):
#   ${SRCROOT}/ThirdParty/flac
#
# Build output staging:
#   ${DERIVED_FILE_DIR}/flac-build/install

FLAC_SOURCE_DIR="${FLAC_SOURCE_DIR:-${SRCROOT}/ThirdParty/flac}"
if [[ ! -d "${FLAC_SOURCE_DIR}" ]]; then
  echo "warning: FLAC source not found at ${FLAC_SOURCE_DIR}; skipping libFLAC build"
  exit 0
fi

CMAKE_BIN=""
if command -v cmake >/dev/null 2>&1; then
  CMAKE_BIN="$(command -v cmake)"
elif [[ -x "/opt/homebrew/bin/cmake" ]]; then
  CMAKE_BIN="/opt/homebrew/bin/cmake"
elif [[ -x "/usr/local/bin/cmake" ]]; then
  CMAKE_BIN="/usr/local/bin/cmake"
elif xcrun --find cmake >/dev/null 2>&1; then
  CMAKE_BIN="$(xcrun --find cmake)"
fi

if [[ -z "${CMAKE_BIN}" ]]; then
  echo "warning: cmake is not available; skipping libFLAC build"
  exit 0
fi

BUILD_ROOT="${DERIVED_FILE_DIR}/flac-build"
INSTALL_ROOT="${BUILD_ROOT}/install"

mkdir -p "${BUILD_ROOT}" "${INSTALL_ROOT}"

filter_ranlib_warnings() {
  while IFS= read -r line; do
    if [[ "${line}" == *"libFLAC.a("* && "${line}" == *"has no symbols"* ]]; then
      continue
    fi
    printf '%s\n' "${line}" >&2
  done
}

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

"${CMAKE_BIN}" -S "${FLAC_SOURCE_DIR}" -B "${BUILD_ROOT}" \
  -DCMAKE_BUILD_TYPE="${CMAKE_CONFIG}" \
  -DCMAKE_OSX_ARCHITECTURES="${PRIMARY_ARCH}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${CMAKE_OSX_DEPLOYMENT_TARGET}" \
  -DBUILD_PROGRAMS=OFF \
  -DBUILD_CXXLIBS=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DWITH_OGG=OFF \
  -DBUILD_TESTING=OFF \
  -DINSTALL_MANPAGES=OFF \
  -DINSTALL_PKGCONFIG_MODULE=OFF \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_ROOT}"

"${CMAKE_BIN}" --build "${BUILD_ROOT}" --config "${CMAKE_CONFIG}" --target FLAC \
  2> >(filter_ranlib_warnings)
"${CMAKE_BIN}" --install "${BUILD_ROOT}" --config "${CMAKE_CONFIG}" \
  2> >(filter_ranlib_warnings)

if [[ ! -f "${INSTALL_ROOT}/lib/libFLAC.a" ]]; then
  echo "error: expected static library at ${INSTALL_ROOT}/lib/libFLAC.a"
  exit 1
fi

# Stage headers into build outputs for bridge compilation/introspection.
HEADER_STAGE_DIR="${DERIVED_FILE_DIR}/flac-include/FLAC"
mkdir -p "${HEADER_STAGE_DIR}"
if [[ -d "${INSTALL_ROOT}/include/FLAC" ]]; then
  cp -f "${INSTALL_ROOT}/include/FLAC/"*.h "${HEADER_STAGE_DIR}/" || true
fi

echo "Built static libFLAC at ${INSTALL_ROOT}/lib/libFLAC.a"
echo "FLAC headers staged to ${HEADER_STAGE_DIR}"
