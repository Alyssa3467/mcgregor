#!/usr/bin/bash

set -euo pipefail

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
        git submodule update --init --recursive "linux"
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
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" bcmrpi_defconfig V=2
make ARCH="${ARCH}" INSTALL_HDR_PATH="${SYSROOT}/usr" headers_install V=2
echo "✅ Kernel headers installed to ${SYSROOT}/usr/include"
