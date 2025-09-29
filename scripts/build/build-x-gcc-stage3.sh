#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# Build cross GCC (stage 3)
build_prep "${X_BUILD_DIR}/gcc-stage3"

"${SOURCE_ROOT}/gcc-15.2.0/configure" \
    --target="${CCPREFIX}" \
    --prefix="${X_INST_DIR}" \
    --with-sysroot="${SYSROOT}" \
    --enable-languages=c,c++ \
    --disable-multilib \
    --enable-shared \
    --enable-threads=posix \
    --enable-__cxa_atexit

parallel_make_rampdown
make install-strip
