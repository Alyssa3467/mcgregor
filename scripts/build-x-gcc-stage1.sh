#!/usr/bin/env bash
set -euo pipefail
. "${SCRIPT_DIR}/parallel_make_rampdown.sh"

# Build minimal cross GCC (stage 1)
mkdir -p "${BUILD_ROOT}/build-${CCPREFIX}-gcc-stage1" && cd "${BUILD_ROOT}/build-${CCPREFIX}-gcc-stage1"

"${SOURCE_ROOT}/gcc-15.2.0/configure" \
    --prefix="${XBIN_FOLDER}" \
    --target="${CCPREFIX}" \
    --with-sysroot="${SYSROOT}" \
    --enable-languages=c \
    --disable-multilib \
    --disable-shared \
    --disable-threads \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libvtv \
    --disable-nls

parallel_make_rampdown all-gcc
parallel_make_rampdown install-gcc