#!/usr/bin/env bash
set -euo pipefail
. "${SCRIPT_DIR}/parallel_make_rampdown.sh"

# Build cross glibc
mkdir -p "${BUILD_ROOT}/build-glibc" && cd "${BUILD_ROOT}/build-glibc" || exit 1
"${SOURCE_ROOT}/glibc-2.42/configure" \
    --build="${NPREFIX}" \
    --host="${CCPREFIX}" \
    --with-sysroot="${SYSROOT}" \
    --prefix="${SYSROOT}/usr" \
    --enable-kernel=3.2.0 \
    --disable-multilib \
    --disable-profile \
    --without-selinux
make install-bootstrap-headers=yes install-headers cross-compiling=yes
parallel_make_rampdown csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o "${SYSROOT}/usr/lib"
"${CCPREFIX}gcc" -nostdlib -nostartfiles -shared -x c /dev/null -o "${SYSROOT}/usr/lib/libc.so"
touch "${SYSROOT}"/usr/include/gnu/stubs.h