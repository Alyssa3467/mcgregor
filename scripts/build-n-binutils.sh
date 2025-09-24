#!/usr/bin/bash

set -e

# Build native binutils
mkdir -p "${BUILD_ROOT}/build-$(arch)-binutils" && cd "${BUILD_ROOT}/build-$(arch)-binutils"
"${SOURCE_ROOT}/binutils-2.45/configure" \
    --prefix="${NBIN_FOLDER}" \
    --disable-multilib
make -j"$(nproc)"
make install-strip