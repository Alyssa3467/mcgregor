#!/usr/bin/env bash
set -euo pipefail

# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# shellcheck disable=SC2034
{
    set -a

    SCRIPT_DIR="$(
        if command -v readlink >/dev/null && readlink -f . >/dev/null 2>&1; then
            cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd
        else
            cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
        fi
    )"

    cd "${SCRIPT_DIR}"

    # Download script to guess the system triplet
    if [[ ! -x ./config.guess ]]; then
        echo "ℹ️  Fetching GNU config.guess..."
        curl -fsSLo ./config.guess \
            https://git.savannah.gnu.org/cgit/config.git/plain/config.guess || {
            echo "❌ Failed to download config.guess"
            exit 1
        }
        chmod +x ./config.guess
    fi

    TARGET=arm-linux-gnueabihf
    HOST=$(./config.guess)

    # Set up other project paths
    PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
    SOURCE_ROOT="${PROJECT_ROOT}/source"
    TOOLCHAIN_ROOT="${PROJECT_ROOT}/toolchain"

    HOST_INST_DIR="${TOOLCHAIN_ROOT}/install/${HOST}"
    TGT_INST_DIR="${TOOLCHAIN_ROOT}/install/${TARGET}"
    BUILD_ROOT="${TOOLCHAIN_ROOT}/build"
    HOST_SYSROOT="${TOOLCHAIN_ROOT}/sysroot/${HOST}"
    TGT_SYSROOT="${TOOLCHAIN_ROOT}/sysroot/${TARGET}"

    HOST_BUILD_DIR="${BUILD_ROOT}/${HOST}"
    TGT_BUILD_DIR="${BUILD_ROOT}/${TARGET}"

    LOG_DIR="${PROJECT_ROOT}/logs/$(date +%F[%z\]/%s)" # Main logging directory
    mkdir -p "${LOG_DIR}"
    ERROR_LOG="${LOG_DIR}/errors.log"

    mkdir -p "${PROJECT_ROOT}/tmp/"
    TMPDIR=$(mktemp -d -p "${PROJECT_ROOT}/tmp")
    TEMP="${TMPDIR}"
    TMP="${TEMP}"

    TGT_CPU=arm
    TGT_GCC_CONFIG=(
        --prefix="${TGT_INST_DIR}"
        --target="${TARGET}"
        --with-arch=armv6
        --with-fpu=vfp
        --with-float=hard
        --with-tune=arm1176jzf-s
        --disable-multilib
        --enable-threads=posix
        --enable-languages="c,c++"
        --disable-nls
        --enable-lto
        --enable-plugin
    )
    HOST_GCC_CONFIG=(
        --prefix="${HOST_INST_DIR}"
        --target="${HOST}"
        --with-zlib="${SOURCE_ROOT}/zlib"
        --enable-languages="c,c++,lto,cobol,fortran,go,m2,objc,obj-c++"
        --enable-shared
        --enable-threads=posix
        --enable-__cxa_atexit
        --enable-clocale=gnu
        --enable-lto
        --enable-linker-plugin
        --enable-default-pie
        --enable-default-ssp
        --with-pic
        --enable-plugin
        --enable-checking=release
        --disable-nls
        --enable-libstdcxx-backtrace
        --enable-libstdcxx-time=yes
        --enable-multilib
    )

    # Raspberry Pi
    CREATE_RPI_KERNEL_HEADERS=yes
    KERNEL=kernel
    DEFCONFIG="bcmrpi_defconfig"

    set +a
}