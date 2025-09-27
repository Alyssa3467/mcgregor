#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

mkdir -p "${BUILD_ROOT}/build-${CCPREFIX}-gcc-stage2" && cd "${BUILD_ROOT}/build-${CCPREFIX}-gcc-stage2" || return 1
"${SOURCE_ROOT}/gcc-15.2.0/configure" \
    --target="${CCPREFIX}" \
    --prefix="${XBIN_FOLDER}" \
    --with-sysroot="${SYSROOT}" \
    --with-headers="${SYSROOT}/usr/include" \
    --enable-languages=c,c++ \
    --disable-multilib \
    --disable-bootstrap \
    --enable-shared \
    --enable-threads=posix \
    --enable-__cxa_atexit

parallel_make_rampdown
make install-strip