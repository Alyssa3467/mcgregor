#!/usr/bin/bash

set -e

# Build cross binutils
mkdir -p "${BUILD_ROOT}/build-${ARCH}-binutils" && cd "${BUILD_ROOT}/build-${ARCH}-binutils"
"${SOURCE_ROOT}/binutils-2.45/configure" \
    --prefix="${XBIN_FOLDER}" \
    --target="${CCPREFIX}" \
    --disable-multilib \
    --with-sysroot
make -j"$(nproc)"
make install-strip