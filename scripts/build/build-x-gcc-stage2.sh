#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

build_prep "${X_BUILD_DIR}/gcc-stage2"

"${SOURCE_ROOT}/gcc-15.2.0/configure" \
    --target="${CCPREFIX}" \
    --prefix="${X_INST_DIR}" \
    --with-sysroot="${SYSROOT}" \
    --with-headers="${SYSROOT}/usr/include" \
    --enable-languages=c,c++ \
    --disable-multilib \
    --disable-bootstrap \
    --enable-shared \
    --enable-threads=posix \
    --enable-__cxa_atexit \
    "${X_GCC_CONFIG}"

parallel_make_rampdown
make install-strip