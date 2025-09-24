#!/bin/bash
set -euo pipefail

# ${SCRIPT_DIR} should be set correctly by the calling script. Jump ship if it isn't.
# (besides, the download we're about to do, a script, should live there anyway)
cd "${SCRIPT_DIR:?SCRIPT_DIR must be set}" || {
    echo "Failed to change directory to SCRIPT_DIR: '$SCRIPT_DIR'" >&2
    exit 1
}

EXPECTED="${SCRIPT_DIR}"
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
    curl -sSLO https://git.savannah.gnu.org/cgit/config.git/plain/config.guess
    chmod +x config.guess
fi

# shellcheck disable=SC2034
{
    set -ao auto-export
    # Project/toolchain settings
    PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

    ARCH=arm
    CCPREFIX=arm-linux-gnueabihf
    CROSS_COMPILE=${CCPREFIX}-

    # Derived paths
    NBIN_FOLDER="${PROJECT_ROOT}/toolchain-$(./config.guess)"
    XBIN_FOLDER="${PROJECT_ROOT}/toolchain-${CCPREFIX}"
    SYSROOT="${PROJECT_ROOT}/toolchain-${CROSS_COMPILE}sysroot"
    SOURCE_ROOT="${PROJECT_ROOT}/toolchain-src"
    BUILD_ROOT="${PROJECT_ROOT}/toolchain-build"

    # Tell the download script that we want to install Raspberry Pi kernel headers
    RPI_KERNEL_HEADERS=yes
    KERNEL=kernel # Raspberry Pi Foundation says we need this for the Pi Zero
}
