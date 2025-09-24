#!/usr/bin/env bash

# Set up environment
SCRIPT_DIR="$(
    if command -v readlink >/dev/null && readlink -f . >/dev/null 2>&1; then
        cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd
    else
        cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
    fi
)"
export SCRIPT_DIR
source "${SCRIPT_DIR}/env.sh"

. "${SCRIPT_DIR}/sys_checks.sh"

# download and extract source files
. "${SCRIPT_DIR}/d-and-e.sh"

# download and install Raspberry Pi kernel headers if called for
if [[ "${RPI_KERNEL_HEADERS:-no}" == "yes" ]]; then
    . "${SCRIPT_DIR}/dl-n-install-rpi-headers.sh"
fi
wait

# Build native binutils
. "${SCRIPT_DIR}/build-n-binutils.sh"

# Build native GCC
. "${SCRIPT_DIR}/build-n-gcc.sh"

# Build cross-compiled binutils
. "${SCRIPT_DIR}/build-x-binutils.sh"

# # Build cross GCC (stage 1)
. "${SCRIPT_DIR}/build-x-gcc-stage1.sh"


# mkdir -p "${BUILD_ROOT}/build-boostrap-${ARCH}-gcc" && cd "${BUILD_ROOT}/build-boostrap-${ARCH}-gcc"
# "${SOURCE_ROOT}/gcc-15.2.0/configure" \
#     --target=${CCPREFIX} \
#     --prefix=${XBIN_FOLDER} \
#     --with-sysroot=${SYSROOT} \
#     --with-headers="${SYSROOT}/usr/include" \
#     --enable-languages=c,c++ \
#     --disable-multilib
# make all-gcc install-gcc
# make all-target-libgcc install-target-libgcc

# # Build cross glibc
# mkdir -p "${BUILD_ROOT}/build-glibc" && cd "${BUILD_ROOT}/build-glibc"
# "${SOURCE_ROOT}/glibc-2.42/configure" \
#     --build="$(uname -m)-linux-gnu" \
#     --host=${CCPREFIX} \
#     --with-sysroot=${SYSROOT} \
#     --with-headers="${SYSROOT}/usr/include" \
#     --prefix="${SYSROOT}/usr" \
#     --enable-kernel=3.2 \
#     --disable-multilib
# make install-bootstrap-headers=yes install-headers cross-compiling=yes
# make -j$(nproc) csu/subdir_lib
# install csu/crt1.o csu/crti.o csu/crtn.o "${SYSROOT}/usr/lib"
# "${CCPREFIX}gcc" -nostdlib -nostartfiles -shared -x c /dev/null -o "${SYSROOT}/usr/lib/libc.so"
# touch ${SYSROOT}/usr/include/gnu/stubs.h

# mkdir -p "${BUILD_ROOT}/build-gcc-stage2" && cd "${BUILD_ROOT}/build-gcc-stage2"
# "${SOURCE_ROOT}/gcc-15.2.0/configure" \
#     --target=${CCPREFIX} \
#     --prefix=${XBIN_FOLDER} \
#     --with-sysroot=${SYSROOT} \
#     --with-headers="${SYSROOT}/usr/include" \
#     --enable-languages=c,c++ \
#     --disable-multilib \
#     --disable-bootstrap \
#     --enable-shared \
#     --enable-threads=posix \
#     --enable-__cxa_atexit
# make -j$(nproc)
# make install-strip