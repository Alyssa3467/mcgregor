#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# moved to D&E
#
# cd "${SOURCE_ROOT}/gcc-15.2.0" || return 1
# ln -f -s ../mpfr-4.2.2 mpfr
# ln -f -s ../gmp-6.3.0 gmp
# ln -f -s ../mpc-1.3.1 mpc

# Burn it all down
rm -rf "${N_BUILD_DIR}/gcc"

# Build native gcc
build_prep "${N_BUILD_DIR}/gcc"

"${SOURCE_ROOT}/gcc-15.2.0/configure" \
    --prefix="${N_INST_DIR}" \
    --disable-multilib \
    --enable-languages=c

parallel_make_rampdown bootstrap startjobs=7

make install-strip 
