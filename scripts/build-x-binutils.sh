#!/usr/bin/env bash
set -euo pipefail
. "${SCRIPT_DIR}/parallel_make_rampdown.sh"

# Build cross binutils
mkdir -p "${BUILD_ROOT}/build-${ARCH}-binutils" && cd "${BUILD_ROOT}/build-${ARCH}-binutils"
"${SOURCE_ROOT}/binutils-2.45/configure" \
    --prefix="${XBIN_FOLDER}" \
    --target="${CCPREFIX}" \
    --disable-multilib \
    --disable-nls \
    --with-sysroot

parallel_make_rampdown
make install-strip