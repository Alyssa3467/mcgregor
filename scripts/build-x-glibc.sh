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

filename="${LOG_FOLDER}/$(date -u '+%Y%m%dT%H%M%SZ')-glibc-install.log"

install --debug -Dt "${SYSROOT}/usr/lib" csu/crt1.o  csu/crtn.o  csu/crti.o  2>&1 | tee -a "${filename}"

# Provide stubs.h until full build
install --debug -D /dev/null "${SYSROOT}/usr/include/gnu/stubs.h"  | tee -a "${filename}"

"${CROSS_COMPILE}"gcc -nostdlib -nostartfiles -shared -x c /dev/null -o "${SYSROOT}"/usr/lib/libc.so
