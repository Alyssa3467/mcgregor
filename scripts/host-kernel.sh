#!/usr/bin/env bash
set -euo pipefail

# ----------------- Make Sure The Necessary Variables Are Set ---------------- #
# -------------------- And Necessary Functions Are Defined ------------------- #
req_vars=(SOURCE_ROOT HOST_TRIPLET HOST_SYSROOT HOST_ARCH)
req_func=(get_defconfig require_var git-sync)

if ! declare -F get_defconfig >/dev/null; then
    source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
fi

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
        require_var --direct-run-- "${req_vars[@]}"
} || require_var "${req_vars[@]}"

HOST_DEFCONFIG="$(get_defconfig "${HOST_ARCH}")"

(
    # -------------------------- Download git repository ------------------------- #
    REPO_URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
    REPO_HOME="${SOURCE_ROOT}/kernel-org"
    REPO_REF="linux-rolling-stable"
    mkdir -p "${REPO_HOME}/linux" && cd "${REPO_HOME}/linux"
    git-sync "${REPO_URL}" --ref "${REPO_REF}" --dir "${REPO_HOME}/linux"

    # -------------------------- Install kernel headers -------------------------- #
    make ARCH="${HOST_ARCH}" mrproper
    echo "Installing Linux kernel headers..."
    mkdir -p "${HOST_SYSROOT}/usr" # ensure destination exists
    make ARCH="${HOST_ARCH}" CROSS_COMPILE="${HOST_TRIPLET}-" "${HOST_DEFCONFIG}" V=2 |
        sed '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}'
    make ARCH="${HOST_ARCH}" INSTALL_HDR_PATH="${HOST_SYSROOT}/usr" headers_install V=2 |
        sed -u \
            -e '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}' \
            -e 's/^  INSTALL \(.*\) - due to target is PHONY$/Installed headers to \1/'

    echo -e "Linux kernel headers installed.\n"
)
