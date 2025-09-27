#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# Build minimal cross GCC (stage 1)
mkdir -p "${BUILD_ROOT}/build-${CCPREFIX}-gcc-stage1" && cd "${BUILD_ROOT}/build-${CCPREFIX}-gcc-stage1" || return 1

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