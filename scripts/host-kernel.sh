#!/usr/bin/env bash
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    vars="SOURCE_ROOT HOST HOST_SYSROOT HOST_CPU DEFCONFIG"
    for var in ${!vars}; do
        if [[ -z ${var} ]]; then
            echo "${var} is not set. A future revision of this script will prompt for a value, but for now, you're SOL" >&2
            exit 78
        fi
    done
fi

(
    # -------------------------- Download git repository ------------------------- #

    REPO_URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
    REPO_HOME="${SOURCE_ROOT}/kernel-org"
    REPO_REF="linux-rolling-stable"
    mkdir -p "${REPO_HOME}/linux" && cd "${REPO_HOME}/linux"
    git-sync "${REPO_URL}" --ref "${REPO_REF}" --dir "${REPO_HOME}/linux"

    # -------------------------- Install kernel headers -------------------------- #
    make ARCH="${HOST_ARCH}" mrproper
    echo "🛠️  Installing Linux kernel headers..."
    mkdir -p "${HOST_SYSROOT}/usr" # ensure destination exists
    make ARCH="${HOST_ARCH}" CROSS_COMPILE="${HOST_TRIPLET}-" "${HOST_DEFCONFIG}" V=2 |
        sed '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}'
    make ARCH="${HOST_ARCH}" INSTALL_HDR_PATH="${HOST_SYSROOT}/usr" headers_install V=2 |
        sed -u \
            -e '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}' \
            -e 's/^  INSTALL \(.*\) - due to target is PHONY$/Installed headers to \1/'

    echo -e "Linux kernel headers installed.\n"
)
