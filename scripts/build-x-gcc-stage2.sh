#!/usr/bin/env bash
set -euo pipefail
. "${SCRIPT_DIR}/parallel_make_rampdown.sh"

mkdir -p "${BUILD_ROOT}/build-${CCPREFIX}-gcc-stage2" && cd "${BUILD_ROOT}/build-${CCPREFIX}-gcc-stage2"
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