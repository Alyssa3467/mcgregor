#!/usr/bin/env bash
set -euo pipefail

cd "${SOURCE_ROOT}"
(
    debug_msg "Linux kernel headers"
    TARBALL=$(find . -maxdepth 1 -name 'linux-*.tar.gz' | sort -V | tail -n1)
    [[ -n $TARBALL ]] || {
        debug_msg "❌ No linux-*.tar.gz tarball found in ${SOURCE_ROOT}"
        exit 1
    }

    [[ -d $(tar -tf "$TARBALL" | head -1 | cut -d/ -f1) ]] || tar -xf "$TARBALL"
    cd "${TARBALL%.tar.gz}"

    set_window_title "Host Kernel Headers"

    echo "🛠️  Installing host kernel headers into ${HOST_SYSROOT}..."

    mkdir -p "${HOST_SYSROOT}/usr"
    (
        ARCH=$(uname -m)
        make ARCH="${ARCH}" defconfig |
            sed '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}'
        make ARCH="${ARCH}" INSTALL_HDR_PATH="${HOST_SYSROOT}/usr" headers_install V=2 |
            sed -u \
                -e '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}' \
                -e 's/^  INSTALL \(.*\) - due to target is PHONY$/✔️  Installed headers to \1/'

    )
    mkdir -p "${HOST_SYSROOT}/usr/lib"
    echo -e "✔️  Host kernel headers installed.\n"
    debug_msg "Linux kernel headers installed"
)
