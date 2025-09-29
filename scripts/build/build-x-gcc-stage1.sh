#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# shellcheck disable=SC2034
(
    # Build minimal cross GCC (stage 1)
    build_prep "${X_BUILD_DIR}/gcc-stage1"

    # CC="${CCPREFIX}"-gcc
    # CXX="${CCPREFIX}"-g++
    # AR="${CCPREFIX}"-ar
    # RANLIB="${CCPREFIX}"-ranlib

    "${SOURCE_ROOT}/gcc-15.2.0/configure" \
        --prefix="${X_INST_DIR}" \
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
        --disable-nls \
        --without-headers \
        "${X_GCC_CONFIG}"

    unset X_GCC_CONFIG

    # Start make at -j15 instead of -j20
    parallel_make_rampdown all-gcc startjobs=15
    parallel_make_rampdown install-gcc startjobs=1
)
