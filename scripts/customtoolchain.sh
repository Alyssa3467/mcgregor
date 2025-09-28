#!/usr/bin/env -iS PATH=/usr/bin:/bin HOME="${HOME}" USER="${USER}" TERM=xterm-256color LANG=C bash

set -ueo pipefail
SKIP_NATIVE=no

for arg in "$@"; do
    case "$arg" in
        --skip-native)
            SKIP_NATIVE=yes
            shift
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

# Set up environment
SCRIPT_DIR="$(
    if command -v readlink >/dev/null && readlink -f . >/dev/null 2>&1; then
        cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd
    else
        cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
    fi
)"
export SCRIPT_DIR

. "${SCRIPT_DIR}/env.sh"
. "${SCRIPT_DIR}/auxiliary_functions.sh"
. "${SCRIPT_DIR}/sys_checks.sh"

# download and extract source files
. "${SCRIPT_DIR}/d-and-e.sh"

# download and install Raspberry Pi kernel headers if called for
if [[ "${RPI_KERNEL_HEADERS:-no}" == "yes" ]]; then
    . "${SCRIPT_DIR}/dl-n-install-rpi-headers.sh"
fi
wait

if [[ "$SKIP_NATIVE" != "yes" ]]; then
    # Build native binutils
    . "${SCRIPT_DIR}/build-n-binutils.sh"

    refresh_toolchains

    # Build native GCC
    . "${SCRIPT_DIR}/build-n-gcc.sh"
else
    echo "Skipping native toolchain build (--skip-native)"
fi

unset PATH
refresh_toolchains

# Build cross-compiled binutils
. "${SCRIPT_DIR}/build-x-binutils.sh"

refresh_toolchains

# Build cross GCC (stage 1)
. "${SCRIPT_DIR}/build-x-gcc-stage1.sh"

refresh_toolchains

# Build glibc
. "${SCRIPT_DIR}/build-x-glibc.sh"

refresh_toolchains

# Build cross GCC (stage 2)
. "${SCRIPT_DIR}/build-x-gcc-stage2.sh"

refresh_toolchains

# Build final cross glibc
. "${SCRIPT_DIR}/build-x-glibc-final.sh"

refresh_toolchains

# Build cross GCC (stage 3)
. "${SCRIPT_DIR}/build-x-gcc-stage3.sh"

echo "Yatta!"