#!/usr/bin/env bash

# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# ${SCRIPT_DIR} should be set correctly by the calling script. Jump ship if it isn't.
# (besides, the download we're about to do, a script, should live there anyway)
cd "${SCRIPT_DIR:?SCRIPT_DIR must be set}" || {
    echo "Failed to change directory to SCRIPT_DIR: '$SCRIPT_DIR'" >&2
    exit 1
}

EXPECTED="${SCRIPT_DIR}/common"
ACTUAL="$(
    if command -v readlink >/dev/null && readlink -f . >/dev/null 2>&1; then
        cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd
    else
        cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
    fi
)"

if [[ $ACTUAL != "$EXPECTED" ]]; then
    echo -e "Script not in expected location. Terminating.\n"
    exit 1
fi

if [[ ! -x config.guess ]]; then
    echo "ℹ️  Fetching GNU config.guess..."
    curl -fsSLo config.guess \
        https://git.savannah.gnu.org/cgit/config.git/plain/config.guess || {
        echo "❌ Failed to download config.guess"
        exit 1
    }
    chmod +x config.guess
fi

if [[ ! -x config.sub ]]; then
    echo "ℹ️  Fetching GNU config.sub..."
    curl -fsSLo config.sub \
        https://git.savannah.gnu.org/cgit/config.git/plain/config.sub || {
        echo "❌ Failed to download config.sub"
        exit 1
    }
    chmod +x config.sub
    # Why do we even need this?
fi

# shellcheck disable=SC2034
{
    set -a
    # Project/toolchain settings
    PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

    # future expansion
    # CLIB=[musl|gnu]
    # TRIPLE=arm-linux-${CLIB}eabihf

    ARCH=arm
    CCPREFIX=arm-linux-gnueabihf
    NPREFIX=$(./config.guess)
    CROSS_COMPILE=${CCPREFIX}-
    X_GCC_CONFIG="--with-arch=armv6 \
  --with-fpu=vfp \
  --with-float=hard \
  --with-tune=arm1176jzf-s"

    # Derived paths
    N_INST_DIR="${PROJECT_ROOT}/toolchain/install/${NPREFIX}"
    N_BUILD_DIR="${PROJECT_ROOT}/toolchain/build/${NPREFIX}"
    X_INST_DIR="${PROJECT_ROOT}/toolchain/install/${CCPREFIX}"
    X_BUILD_DIR="${PROJECT_ROOT}/toolchain/build/${CCPREFIX}"
    SYSROOT="${PROJECT_ROOT}/toolchain/sysroot/${CROSS_COMPILE}"
    SOURCE_ROOT="${PROJECT_ROOT}/toolchain/src"
    BUILD_ROOT="${PROJECT_ROOT}/toolchain/build"
    LOG_DIR="${PROJECT_ROOT}/toolchain/build/logs"
    mkdir -p "${LOG_DIR}"

    # Tell the download script that we want to install Raspberry Pi kernel headers
    RPI_KERNEL_HEADERS=yes
    set +a
}
