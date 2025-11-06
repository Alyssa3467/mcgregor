#!/usr/bin/env bash
set -euo pipefail
rpi_env
env
if [ "$CREATE_RPI_KERNEL_HEADERS" = "yes" ]; then
    (
        cross_build_env
        write_log_msg "Begin Raspberry Pi Kernel Sequence"

        set_window_title Raspberry Pi Kernel Source

        # -------------------------- Download git repository ------------------------- #
        mkdir -p "${PROJECT_ROOT}/raspberrypi" && cd "${PROJECT_ROOT}"
        (
            SUBMODULE_PATH="raspberrypi/linux"
            SUBMODULE_URL="git@github.com:raspberrypi/linux"
            # If .gitmodules references the path, update/init; otherwise add it.
            if git config --file .gitmodules --get-regexp "submodule\..*\.path" | awk '{print $2}' 2>/dev/null | grep -xq -- "${SUBMODULE_PATH}"; then
                write_log_msg --level=1 --std "✔️  Submodule already configured at ${SUBMODULE_PATH}; updating..."
                git submodule update --init --recursive "${SUBMODULE_PATH}" || {
                    write_log_msg --err --level=3 "git submodule update failed" >&2
                    exit 128
                }
            else
                echo "Adding submodule ${SUBMODULE_URL} at ${SUBMODULE_PATH}..."
                git submodule add "${SUBMODULE_URL}" "${SUBMODULE_PATH}" ||
                    {
                        write_log_msg --err --level=3 "git submodule add failed, trying update --init..." >&2
                        git submodule update --init --recursive "${SUBMODULE_PATH}" ||
                            {
                                write_log_msg --err --level=4 "submodule setup failed"
                                exit 128 >&2
                            }
                    }
            fi
        )

        # -------------------------- Install kernel headers -------------------------- #
        set_window_title Raspberry Pi Kernel Headers
        cd "${PROJECT_ROOT}/raspberrypi/linux"
        echo "🛠️  Installing Raspberry Pi kernel headers..."
        mkdir -p "${TGT_SYSROOT}/usr" # ensure destination exists
        make ARCH="${TGT_CPU}" CROSS_COMPILE="${TARGET}-" "${DEFCONFIG}" V=2 |
            sed '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}'
        make ARCH="${TGT_CPU}" INSTALL_HDR_PATH="${TGT_SYSROOT}/usr" headers_install V=2 |
            sed -u \
                -e '/^#$/ {N;N;/^#\n# No change to \.config\n#$/d}' \
                -e 's/^  INSTALL \(.*\) - due to target is PHONY$/✔️  Installed headers to \1/'

        echo -e "✔️  Raspberry Pi kernel headers installed.\n"
        write_log_msg "Raspberry Pi kernel headers installed"
    )
fi
