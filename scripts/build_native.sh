#!/bin/bash
set -ueo pipefail

# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# Build zlib
build_zlib() {
    build_prep "zlib"
    set_window_title "Building zlib"
    "${SOURCE_ROOT}/zlib/configure" --prefix="${HOST_INST_DIR}"
    parallel_make test
    parallel_make
    parallel_make install
    verify_artifacts "zlib" \
        "${HOST_INST_DIR}/lib/libz.a" \
        "${HOST_INST_DIR}/lib/libz.so"
}

# Build binutils

(
    set_window_title "Building native binutils"
    debug_msg "Start building native binutils"
    build_prep "${HOST_BUILD_DIR}/binutils"

    SRC_TARBALL=$(find "${SOURCE_ROOT}" -maxdepth 1 -type d -name 'binutils-[0-9]*' | sort | head -n1)

    if [ -d "${SOURCE_ROOT}"/binutils-gdb ]; then
        SRC_DIR=${SOURCE_ROOT}/binutils-gdb
    elif [ -n "${SRC_TARBALL}" ] && [ -d "${SRC_TARBALL}" ]; then
        SRC_DIR="${SRC_TARBALL}"
    else
        echo "No binutils source found"
        exit 1
    fi

    "${SRC_DIR}/configure" \
        --program-prefix="${HOST}-" \
        --prefix="${HOST_INST_DIR}" \
        --with-sysroot="${HOST_SYSROOT}" \
        --target="${HOST}" \
        --disable-nls \
        --disable-werror \
        --disable-multilib

    make -j"$(nproc)"
    make install
    verify_artifacts "binutils" \
        "${HOST_INST_DIR}/bin/${HOST}-ld" \
        "${HOST_INST_DIR}/bin/${HOST}-as"

    debug_msg "Finished"
)
export PATH="${HOST_INST_DIR}/bin:${PATH}"

# Build native GCC Stage 1, Part A

(
    debug_msg "Build native GCC Stage 1"
    set_window_title "Building native GCC, Part 1A"
    build_prep "${HOST_BUILD_DIR}/gcc-stage-1"

    SRC_DIR=$(find "${SOURCE_ROOT}" -maxdepth 1 -type d -name 'gcc-[0-9]*' | sort | head -n1)

    debug_msg "${SRC_DIR}/configure starting"

    set -x
    clean_shell "${SRC_DIR}/configure" \
        --prefix="${HOST_INST_DIR}" \
        --target="${HOST}" \
        --with-sysroot="${HOST_SYSROOT}" \
        --with-target-system-zlib \
        --enable-languages=c \
        --disable-multilib \
        --disable-nls \
        --disable-libsanitizer \
        --disable-libquadmath \
        --disable-libatomic \
        --disable-libgomp \
        --disable-libssp \
        --disable-libvtv \
        --without-headers \
        --with-newlib

    parallel_make all-gcc
    parallel_make install-gcc
    verify_artifacts "gcc-stage1" \
        "${HOST_INST_DIR}/bin/${HOST}-gcc"
    set +x
    debug_msg "Finished"
)

# Build native glibc, Part 1

(
    debug_msg "Build native glibc"
    set_window_title "Building native glibc, Part 1"
    build_prep "${HOST_BUILD_DIR}/glibc"

    SRC_DIR=$(find "${SOURCE_ROOT}" -maxdepth 1 -type d -name 'glibc-[0-9]*' | sort | head -n1)
    test -d "${SRC_DIR}" || {
        debug_msg "❌ No glibc source found"
        exit 1
    }

    "${SRC_DIR}/configure" \
        --prefix="/usr" \
        --libdir="/usr/lib" \
        --host="${HOST}" \
        --build="${HOST}" \
        --with-headers="${HOST_SYSROOT}"/usr/include \
        --disable-multilib \
        libc_cv_forced_unwind=yes
    parallel_make install-bootstrap-headers=yes install-headers DESTDIR="${HOST_SYSROOT}"
    parallel_make csu/subdir_lib
    install csu/crt1.o csu/crti.o csu/crtn.o "${HOST_SYSROOT}"/usr/lib
    "${HOST_INST_DIR}"/bin/"${HOST}"-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o "${HOST_SYSROOT}"/usr/lib/libc.so
    mkdir -p "${HOST_SYSROOT}"/usr/include/gnu/
    touch "${HOST_SYSROOT}"/usr/include/gnu/stubs.h
    verify_artifacts "glibc-stage1" \
        "${HOST_SYSROOT}/usr/include/stdio.h" \
        "${HOST_SYSROOT}/usr/lib/crt1.o" \
        "${HOST_SYSROOT}/usr/lib/libc.so"

    debug_msg "finished"
)

# Build native GCC Stage 1, Part B

set_window_title "Building native GCC, Part 1B"
debug_msg "Native GCC, Part 1B"
cd "${HOST_BUILD_DIR}/gcc-stage-1"
parallel_make all-target-libgcc
parallel_make install-target-libgcc DESTDIR="${HOST_SYSROOT}"
verify_artifacts "libgcc" \
    "${HOST_SYSROOT}/usr/lib/libgcc_s.so" \
    "${HOST_SYSROOT}/usr/lib/libgcc.a"

# Build native glibc, Part 2

set_window_title "Building native glibc, Part 2"
debug_msg "Native glibc, Part 2"
cd "${HOST_BUILD_DIR}/glibc"
parallel_make
parallel_make install DESTDIR="${HOST_SYSROOT}"
verify_artifacts "glibc-stage2" \
    "${HOST_SYSROOT}/usr/lib/libc.so" \
    "${HOST_SYSROOT}/usr/include/stdlib.h"
# case $(uname -m) in
#     i?86)
#         ln -sfv ld-linux.so.2 "${HOST_SYSROOT}"/lib/ld-lsb.so.3
#         ;;
#     x86_64)
#         ln -sfv ../lib/ld-linux-x86-64.so.2 "${HOST_SYSROOT}"/lib64
#         ln -sfv ../lib/ld-linux-x86-64.so.2 "${HOST_SYSROOT}"/lib64/ld-lsb-x86-64.so.3
#         ;;
# esac

# Build native GCC Stage 2

(
    set_window_title "Building native GCC, Part 2"
    debug_msg "Build native GCC Stage 2"
    build_prep "${HOST_BUILD_DIR}/gcc-stage-2"
    SRC_DIR=$(find "${SOURCE_ROOT}" -maxdepth 1 -type d -name 'gcc-[0-9]*' | sort | head -n1)
    "${SRC_DIR}/configure" "${HOST_GCC_CONFIG[@]}"
    parallel_make
    parallel_make install
    verify_artifacts "gcc-stage2" \
        "${HOST_INST_DIR}/bin/${HOST}-gcc" \
        "${HOST_INST_DIR}/bin/${HOST}-g++"
)

# ---------------- Where Things Are Actually Called --------------- #
native_build_env
