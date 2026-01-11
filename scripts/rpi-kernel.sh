#!/usr/bin/env bash
set -euo pipefail

# ----------------- Make Sure The Necessary Variables Are Set ---------------- #
# -------------------- And Necessary Functions Are Defined ------------------- #
req_vars=(SOURCE_ROOT TARGET_TRIPLET TARGET_SYSROOT KERNEL TARGET_ARCH)
req_func=(require_var git-sync)

# if ! declare -F get_defconfig >/dev/null; then
#     source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
# fi

if ! declare -F require_func >/dev/null; then
    require_func() {
        for func in "$@"; do
            if ! declare -F "$func" >/dev/null; then
                for f in env.sh ancillary.sh; do
                    file="$(dirname "${SOURCE_ROOT:-${BASH_SOURCE[0]}}")/$f"
                    if [[ -r "$file" ]]; then
                        safe_func=$(echo "$func" | sed 's/[][^$.*/+?(){}|]/\\&/g')
                        if grep -Eq \
                            "^[^\r\n\S]*(function[^\r\n\S]+|)$safe_func([^\r\n\S]*\(\))?[^\r\n\S]*\{[^\r\n\S]*.*(\r\n|\n)" \
                            "$file"; then
                            # shellcheck disable=SC1090
                            source "$file"
                            if declare -F "$func" >/dev/null; then
                                break
                            fi
                        fi
                    fi
                done
            fi
            if ! declare -F "$func" >/dev/null; then
                return 1
            fi
        done
    }
fi

require_func "${req_func[@]}"
{
    [[ "${BASH_SOURCE[0]}" == "${0}" ]] &&
        require_var --direct-run-- "${req_vars[@]}" &&
        CREATE_RPI_KERNEL_HEADERS="yes"
} || require_var "${req_vars[@]}"



if [ "$CREATE_RPI_KERNEL_HEADERS" = "yes" ]; then
    (
        # -------------------------- Download git repository ------------------------- #
        mkdir -p "${SOURCE_ROOT}/raspberrypi" && cd "${SOURCE_ROOT}"
        REPO_HOME="${SOURCE_ROOT}/raspberrypi"

        REPO_URL="https://github.com/raspberrypi/linux.git"
        git-sync "${REPO_URL}" --dir "${REPO_HOME}/linux"

        # -------------------------- Install kernel headers -------------------------- #
        cd "${SOURCE_ROOT}/raspberrypi/linux"
        echo "🛠️  Installing Raspberry Pi kernel headers..."
        mkdir -p "${TARGET_SYSROOT}/usr" # ensure destination exists
        make ARCH="${TARGET_ARCH}" CROSS_COMPILE="${TARGET_TRIPLET}-" "${TARGET_DEFCONFIG}" V=2 |
            sed '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}'
        make ARCH="${TARGET_ARCH}" INSTALL_HDR_PATH="${TARGET_SYSROOT}/usr" headers_install V=2 |
            sed -u \
                -e '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}' \
                -e 's/^  INSTALL \(.*\) - due to target is PHONY$/Installed headers to \1/'

        echo -e "Raspberry Pi kernel headers installed.\n"
    )
fi
