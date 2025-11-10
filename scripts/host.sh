#!/usr/bin/env bash
set -euo pipefail

cd "${SOURCE_ROOT}"
(
    native_build_env
    write_log_msg "Linux kernel headers"
    TARBALL=$(find . -maxdepth 1 -name 'linux-*.tar.gz' | sort -V | tail -n1)
    [[ -n $TARBALL ]] || {
        write_log_msg --err --level=4 "No linux-*.tar.gz tarball found in ${SOURCE_ROOT}"
        exit 1
    }

    [[ -d $(tar -tf "$TARBALL" | head -1 | cut -d/ -f1) ]] || tar -xf "$TARBALL"
    cd "${TARBALL%.tar.gz}"

    set_window_title "Host Kernel Headers"

    write_log_msg "Installing host kernel headers into ${HOST_SYSROOT}..."

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
    write_log_msg "Linux kernel headers installed"
)
