#!/usr/bin/env bash
set -euo pipefail

cd "${SOURCE_ROOT}/gcc-15.2.0"
ln -f -s ../mpfr-4.2.2 mpfr
ln -f -s ../gmp-6.3.0 gmp
ln -f -s ../mpc-1.3.1 mpc

NTT=$("${SCRIPT_DIR}/config.guess")
. "${SCRIPT_DIR}/parallel_make_rampdown.sh"

# Build native gcc
mkdir -p "${BUILD_ROOT}/build-$NTT-gcc" && cd "${BUILD_ROOT}/build-$NTT-gcc"
"${SOURCE_ROOT}/gcc-15.2.0/configure" \
    --prefix="${NBIN_FOLDER}" \
    --disable-multilib \
    --enable-languages=c

parallel_make_rampdown bootstrap

make install-strip
