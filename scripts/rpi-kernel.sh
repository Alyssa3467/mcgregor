#!/usr/bin/env bash
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    vars="SOURCE_ROOT TARGET TARGET_SYSROOT TARGET_CPU DEFCONFIG"
    for var in ${!vars}; do
        if [[ -z ${var} ]]; then
            echo "${var} is not set. A future revision of this script will prompt for a value, but for now, you're SOL" >&2
            exit 78
        fi
    done
fi

if [ "$CREATE_RPI_KERNEL_HEADERS" = "yes" ]; then
    (
        # ----------------- Make Sure The Necessary Variables Are Set ---------------- #
        : "${SOURCE_ROOT:?SOURCE_ROOT must be set}"
        : "${TARGET:?TARGET must be set}"
        : "${TARGET_SYSROOT:?TARGET_SYSROOT must be set}"
        : "${TARGET_CPU:?TARGET_CPU must be set}"
        : "${DEFCONFIG:?DEFCONFIG must be set}"

        # -------------------------- Download git repository ------------------------- #
        mkdir -p "${SOURCE_ROOT}/raspberrypi" && cd "${SOURCE_ROOT}"

        REPO_URL="https://github.com/raspberrypi/linux.git"
        git-sync "${REPO_URL}"

        # -------------------------- Install kernel headers -------------------------- #
        cd "${SOURCE_ROOT}/raspberrypi/linux"
        echo "🛠️  Installing Raspberry Pi kernel headers..."
        mkdir -p "${TARGET_SYSROOT}/usr" # ensure destination exists
        make ARCH="${TARGET_CPU}" CROSS_COMPILE="${TARGET}-" "${DEFCONFIG}" V=2 |
            sed '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}'
        make ARCH="${TARGET_CPU}" INSTALL_HDR_PATH="${TARGET_SYSROOT}/usr" headers_install V=2 |
            sed -u \
                -e '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}' \
                -e 's/^  INSTALL \(.*\) - due to target is PHONY$/Installed headers to \1/'

        echo -e "Raspberry Pi kernel headers installed.\n"
    )
fi
