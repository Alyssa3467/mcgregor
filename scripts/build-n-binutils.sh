#!/usr/bin/env bash
set -euo pipefail
. "${SCRIPT_DIR}/parallel_make_rampdown.sh"

# Build native binutils
mkdir -p "${BUILD_ROOT}/build-$(arch)-binutils" && cd "${BUILD_ROOT}/build-$(arch)-binutils"
"${SOURCE_ROOT}/binutils-2.45/configure" \
    --prefix="${NBIN_FOLDER}" \
    --disable-multilib
parallel_make_rampdown
parallel_make_rampdown install-strip