#!/usr/bin/env bash
set -euo pipefail

# Best know what you're doing, 'cause this be somewhat destructive

set -euo pipefail
command -v git >/dev/null || {
    echo "❌ git not found"
    exit 1
}
command -v make >/dev/null || {
    echo "❌ make not found"
    exit 1
}

# 🔒 Ensure required environment variables are set
: "${PROJECT_ROOT:?PROJECT_ROOT is not set}"
: "${ARCH:?ARCH is not set}"
: "${CROSS_COMPILE:?CROSS_COMPILE is not set}"
: "${SYSROOT:?SYSROOT is not set}"

mkdir -p "${PROJECT_ROOT}/raspberrypi"
cd "${PROJECT_ROOT}/raspberrypi"

if git config --file "$(git rev-parse --show-toplevel)/.gitmodules" \
    --get-regexp "submodule.raspberrypi/linux.url" >/dev/null 2>&1; then
    echo "ℹ️  Submodule already declared in .gitmodules."

    if [ -d "${PROJECT_ROOT}/raspberrypi/linux" ]; then
        if [ -f "${PROJECT_ROOT}/raspberrypi/linux/.git" ]; then
            echo "✅ Submodule directory exists and is properly linked. No action needed."
        else
            echo "⚠️  Submodule directory exists but is not a valid Git repo. Attempting recovery..."
            git submodule update --init --recursive "linux"
        fi
    else
        echo "🔄 Submodule declared but not initialized. Running update..."
        git submodule update --init --recursive "linux" ||
            {
                echo "❌ Submodule recovery failed, wiping and recloning..."
                rm -rf linux
                git submodule update --init --recursive linux
            }
    fi

elif [ ! -d "${PROJECT_ROOT}/raspberrypi/linux" ]; then
    echo "➕ Adding Raspberry Pi Linux kernel as a git submodule..."
    git submodule add --force git@github.com:raspberrypi/linux "linux" 2>&1 | tee submodule.log
    echo "✅ Submodule added successfully."

else
    echo "⚠️  Submodule folder exists but not declared. Manual cleanup may be needed."
fi

# 🧵 Install kernel headers
cd "${PROJECT_ROOT}/raspberrypi/linux"
echo "🛠️  Installing Raspberry Pi kernel headers..."
mkdir -p "${SYSROOT}/usr" # ensure destination exists
export KERNEL=kernel      # Raspberry Pi Foundation says we need this for the Pi Zero
DEFCONFIG="${DEFCONFIG:-bcmrpi_defconfig}"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" "${DEFCONFIG}" V=2
make ARCH="${ARCH}" INSTALL_HDR_PATH="${SYSROOT}/usr" headers_install V=2
echo "✅ Kernel headers installed to ${SYSROOT}/usr/include"
