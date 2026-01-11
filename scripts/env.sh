#!/usr/bin/env bash

if ! grep -q "Ubuntu" /etc/os-release; then
    if grep -q "Windows" /etc/os-release; then
        echo "Wut?" >&2
        exit 71
    fi
    exit 69
elif [[ "$(date +%m%d)" == "0230" ]]; then
    echo "What in the name of Hyrule is going on here?" >&2
    exit 66
elif [[ "$(TZ="America/Los_Angeles" date -Iminutes)" == "1955-11-05T06:15-08:00" ]]; then
    echo "Great Scott!" >&2
    exit 66
elif [[ "$(TZ="US/Mountain" date -I)" == "2063-04-05" ]]; then
    echo "🖖"
fi

current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "If you'd like to make a call, please hang up and try again. If you need help, dial the operator." >&2
    kill -s SIGHUP $$
    exit 64
elif [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="${current_dir}"
elif [[ "${SCRIPT_DIR}" != "${current_dir}" ]]; then
    exit 78
fi
unset current_dir


fetch_config_scripts() {
    local url_guess="https://git.savannah.gnu.org/cgit/config.git/plain/config.guess"
    local url_sub="https://git.savannah.gnu.org/cgit/config.git/plain/config.sub"

    if [[ ! -x "${SCRIPT_DIR}/config.guess" ]]; then
        echo "Fetching GNU config.guess..."
        if ! curl -fsSLo "${SCRIPT_DIR}/config.guess" "${url_guess}"; then
            echo "Failed to download config.guess"
            exit 75
        fi
        chmod +x "${SCRIPT_DIR}/config.guess"
    fi

    if [[ ! -x "${SCRIPT_DIR}/config.sub" ]]; then
        echo "Fetching GNU config.sub..."
        if ! curl -fsSLo "${SCRIPT_DIR}/config.sub" "${url_sub}"; then
            echo "Failed to download config.sub"
            exit 75
        fi
        chmod +x "${SCRIPT_DIR}/config.sub"
    fi
    return 0
}

if ! fetch_config_scripts; then
    exit 75
fi

detect_host_triplet() {
    local gcc_path dumpmachine input host_guess

    if host_guess=$("${SCRIPT_DIR}/config.guess" 2>/dev/null); then
        echo "${host_guess}"
        return 0
    fi

    if command -v gcc >/dev/null 2>&1; then
        gcc_path=$(command -v gcc)
        if dumpmachine=$("${gcc_path}" -dumpmachine 2>/dev/null); then
            input="${dumpmachine}"
        fi
    fi

    if [[ -z "${input:-}" ]]; then
        input="$(uname -m)-unknown-$(uname -s | tr '[:upper:]' '[:lower:]')"
    fi

    if host_guess=$("${SCRIPT_DIR}/config.sub" "${input}" 2>/dev/null); then
        echo "${host_guess}"
        return 0
    fi

    echo "${input}"
    return 0
}

get_defconfig() {
    local arch="$1"
    local kernel="${KERNEL:-NOTPI}"

    # Normalize architecture aliases (ARM)
    case "$arch" in
    aarch64)
        arch="arm64"
        ;;
    armv7l | armv8l)
        arch="arm"
        ;;
    esac

    # Base defconfig per arch
    declare -A base_defconfig=(
        [x86_64]="x86_64_defconfig"
        [arm]="arm_defconfig"
        [arm64]="arm64_defconfig"
    )

    # Raspberry Pi specific overrides keyed by arch_kernel
    # Information from:
    #     https://www.raspberrypi.com/documentation/computers/linux_kernel.html#cross-compiled-build-configuration
    declare -A defconfig=(
        # 64-bit Pi kernels
        [arm64_kernel8]="bcm2711_defconfig"     # Pi 3/CM3/3+/CM3+/Zero 2 W/4/400/CM4/CM4S
        [arm64_kernel_2712]="bcm2712_defconfig" # Pi 5/500/500+/CM5

        # 32-bit Pi kernels
        [arm_kernel]="bcmrpi_defconfig"    # Pi 1/CM1/Zero/Zero W
        [arm_kernel7]="bcm2709_defconfig"  # Pi 2/3/CM3/3+/CM3+/Zero 2 W
        [arm_kernel7l]="bcm2710_defconfig" # Pi 4/400/CM4/CM4S
    )

    for key in "${!base_defconfig[@]}"; do
        defconfig["${key}"_NOTPI]="${base_defconfig[${key}]}"
    done

    if [[ -n "${defconfig[${arch}_${kernel}]:-}" ]]; then
        echo "${defconfig[${arch}_${kernel}]}"
        return 0
    elif [[ "${kernel}" != "NOTPI" ]]; then
        if [[ ${arch} =~ ^(arm(64)?)$ ]]; then
            echo "Possible unsupported Raspberry Pi variant?" >&2
            exit 78
        else
            echo "Possible unsupported non-ARM Raspberry Pi variant? 🤨" >&2
            exit 78
        fi
    else
        echo "Unknown or unsupported architecture: ${arch}" >&2
        exit 78
    fi
}

# ---------------------------------------------------------------------------- #
CC=$(command -v icx || command -v clang || command -v gcc)
CXX=$(command -v dpcpp || command -v clang++ || command -v g++)
echo "CC: ${CC}"
echo "CXX: ${CXX}"

: "${PROJECT_ROOT:=${PROJECT_ROOT:-$(dirname "${SCRIPT_DIR}")}}"
: "${SOURCE_ROOT:=${SOURCE_ROOT:-${PROJECT_ROOT}/source}}"
: "${TOOLCHAIN_ROOT:=${TOOLCHAIN_ROOT:-${PROJECT_ROOT}/toolchain}}"
: "${BUILD_ROOT:=${BUILD_ROOT:-${TOOLCHAIN_ROOT}/build}}"
: "${INSTALL_ROOT:=${INSTALL_ROOT:-${TOOLCHAIN_ROOT}/install}}"
: "${SYSROOT:=${TOOLCHAIN_ROOT}/sysroot}"

mkdir -p "${SOURCE_ROOT}"

# Environment variables that directly affect
# compiler behavior should NOT be read-only
export CC CXX
export SCRIPT_DIR PROJECT_ROOT SOURCE_ROOT TOOLCHAIN_ROOT BUILD_ROOT INSTALL_ROOT SYSROOT
readonly SCRIPT_DIR PROJECT_ROOT SOURCE_ROOT TOOLCHAIN_ROOT BUILD_ROOT INSTALL_ROOT SYSROOT
# ---------------------------------------------------------------------------- #

# ------------------------------ Host Variables ------------------------------ #
HOST_TRIPLET=${HOST_TRIPLET:-$(detect_host_triplet)}
HOST_ARCH=$(uname -m)
HOST_DEFCONFIG="$(get_defconfig "${HOST_ARCH}")"

HOST_TOOLCHAIN="${TOOLCHAIN_ROOT}/${HOST_TRIPLET}"
HOST_BUILD="${BUILD_ROOT}/${HOST_TRIPLET}"
HOST_INSTALL="${INSTALL_ROOT}/${HOST_TRIPLET}"
HOST_SYSROOT="${SYSROOT}/${HOST_TRIPLET}"

mkdir -p "${HOST_TOOLCHAIN}" "${HOST_BUILD}" "${HOST_INSTALL}" "${HOST_SYSROOT}"

export HOST_TRIPLET HOST_ARCH HOST_DEFCONFIG
export HOST_BUILD HOST_SYSROOT HOST_INSTALL

# ---------------------------------------------------------------------------- #
#                               Target Variables                               #
# ---------------------------------------------------------------------------- #
# --------------------------- Raspberry Pi Zero 2 W -------------------------- #
TARGET_TRIPLET="aarch64-linux-gnu"
KERNEL="kernel8"
TARGET_ARCH="arm64"
TARGET_DEFCONFIG="$(get_defconfig "${TARGET_ARCH}")"

TARGET_TOOLCHAIN="${TOOLCHAIN_ROOT}/${TARGET_TRIPLET}"
TARGET_SYSROOT="${SYSROOT}/${TARGET_TRIPLET}"

export TARGET_TRIPLET TARGET_ARCH TARGET_DEFCONFIG KERNEL TARGET_TOOLCHAIN TARGET_SYSROOT