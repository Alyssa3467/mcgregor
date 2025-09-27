#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# Build cross glibc (again)
mkdir -p "${BUILD_ROOT}/build-glibc-final" && cd "${BUILD_ROOT}/build-glibc-final" || exit 1
"${SOURCE_ROOT}/glibc-2.42/configure" \
    --build="${NPREFIX}" \
    --host="${CCPREFIX}" \
    --with-sysroot="${SYSROOT}" \
    --prefix=/usr \
    --enable-kernel=3.2.0 \
    --disable-multilib \
    --disable-profile \
    --without-selinux

parallel_make_rampdown
make install DESTDIR="${SYSROOT}"