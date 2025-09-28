#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# Build cross glibc
build_prep "${BUILD_ROOT}/build-glibc"

"${SOURCE_ROOT}/glibc-2.42/configure" \
    --build="${NPREFIX}" \
    --host="${CCPREFIX}" \
    --with-sysroot="${SYSROOT}" \
    --prefix="${SYSROOT}/usr" \
    --enable-kernel=3.2.0 \
    --disable-multilib \
    --disable-profile \
    --without-selinux \
    --with-headers="${SYSROOT}/usr/include"

parallel_make_rampdown install-bootstrap-headers=yes \
    install-headers cross-compiling=yes install_root="$SYSROOT"
parallel_make_rampdown csu/subdir_lib

install -D csu/crt1.o "${SYSROOT}/usr/lib"
install -D csu/crti.o "${SYSROOT}/usr/lib"
install -D csu/crtn.o "${SYSROOT}/usr/lib"

# Provide stubs.h until full build
install -D /dev/null "${SYSROOT}/usr/include/gnu/stubs.h"

"${CROSS_COMPILE}"gcc -nostdlib -nostartfiles -shared -x c /dev/null -o "${SYSROOT}"/usr/lib/libc.so