#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# Build cross binutils
build_prep "${X_BUILD_DIR}/binutils"
set_window_title "Cross binutils"
"${SOURCE_ROOT}/binutils-2.45/configure" \
    --prefix="${X_INST_DIR}" \
    --target="${CCPREFIX}" \
    --disable-multilib \
    --disable-nls \
    --with-sysroot

parallel_make_rampdown
make install-strip