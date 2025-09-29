#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# Build native binutils
build_prep "${N_BUILD_DIR}/binutils"

"${SOURCE_ROOT}/binutils-2.45/configure" \
    --prefix="${N_INST_DIR}" \
    --disable-multilib
parallel_make_rampdown
parallel_make_rampdown install-strip