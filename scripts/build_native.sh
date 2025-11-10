#!/bin/bash
set -Eueo pipefail

# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi
build_gcc-1() {
    if [[ ! $- =~ e ]]; then
        set -e
        write_log_msg --std --level="$INFO" "Reasserting 'set -e'" 1>&2
    fi

    build_prep --host "gcc-stage-1"
    set_window_title "Building GCC - Stage 1"

    write_log_msg "PATH: ${PATH}"
    write_log_msg --level="$DEBUG" "Configure flags for ${pkg_name}: ${flags[*]}"

    local flags=()
    configure_build-params "gcc-stage-1" >/dev/null

    write_log_msg "gcc-stage-1: make all-gcc"
    parallel_make all-gcc
    write_log_msg "gcc-stage-1: make install-gcc"
}

build_hosttools() {

    local pkg_name="$1"

    build_prep --host "${pkg_name}"
    set_window_title "Building ${pkg_name}"

    local pkg_dir
    pkg_dir="$(findpkg "${pkg_name}")"
    local filename
    filename="$(basename "${pkg_dir}")"

    # # Gather configure flags from dispatcher
    local flags=()
    # mapfile -t flags < <(configure_flags "${pkg_name}")

    # might as well directly manipulate ${flags[@]} at this point...

    # kludge for Tck/tk
    configure_build-params "${pkg_name}" >/dev/null

    write_log_msg "PATH: ${PATH}"
    write_log_msg --level="$DEBUG" "Configure flags for ${pkg_name}: ${flags[*]}"

    # Run configure
    "${SOURCE_ROOT}/${filename}/configure" "${flags[@]}"

    # Build
    write_log_msg "${pkg_name}: make"
    parallel_make

    # Test: prefer 'check', fallback to 'test', but fail if both fail
    write_log_msg "${pkg_name}: make check"
    if ! parallel_make check startjobs=1; then
        if [ "${pkg_name}" = "binutils" ]; then
            true
        fi
        write_log_msg --level="$INFO" "${pkg_name}: 'make check' failed, trying 'make test'"
        if ! parallel_make test startjobs=1; then
            write_log_msg --err --level=4 "${pkg_name}: tests failed"
            return 1
        fi
    fi

    # Install
    write_log_msg "${pkg_name}: make install"
    parallel_make install

    write_log_msg "${pkg_name}: make installcheck"
    parallel_make installcheck
}

findpkg() {
    find "${SOURCE_ROOT}" -maxdepth 1 -type d -name "${1}*" | sort -V | tail -n1
}

configure_build-params() {
    if [[ ! $- =~ e ]]; then
        set -e
        write_log_msg --std --level="$INFO" "Reasserting 'set -e'" 1>&2
    fi
    case "$1" in
    # zlib has only --prefix
    gmp)
        flags=("--enable-cxx")
        ;;
    mpfr)
        flags=("--with-gmp=${HOST_INST_DIR}")
        ;;
    mpc)
        flags=("--with-gmp=${HOST_INST_DIR}" "--with-mpfr=${HOST_INST_DIR}")
        ;;
    isl)
        flags=("--with-gmp-prefix=${HOST_INST_DIR}")
        ;;
    # gettext has only --prefix
    texinfo)
        export PATH="${HOST_INST_DIR}/bin:${PATH}"
        export PKG_CONFIG_PATH="${HOST_INST_DIR}/lib/pkgconfig"
        ;;
    binutils)
        flags=("--with-sysroot=${HOST_SYSROOT}" "--target=${HOST}"
            "--disable-nls" "--enable-multilib")
        ;;
    tcl)
        export with_tcl=${PWD}
        filename="${filename}/unix"
        ;;
    gcc-1)
        flags=("--prefix=${HOST_INST_DIR}" "--target=${HOST}" "--with-sysroot=${HOST_SYSROOT}"
            "--enable-languages=c" "--disable-bootstrap" "--disable-nls"
            "--disable-shared" "--without-headers" "--enable-multilib")
        ;;
    *)
        flags=()
        ;;
    esac
    flags=("--prefix=${HOST_INST_DIR}" "${flags[@]}")
    for f in "${flags[@]}"; do
        echo "$f"
    done
}

runner() {
    if [[ ! $- =~ e ]]; then
        set -e
        write_log_msg --std --level="$INFO" "Reasserting 'set -e'" 1>&2
    fi
    local pkg_name="$1"
    local phase="$2"

    local builder=""
    case "$phase" in
    --host) builder="build_hosttools" ;;
    --gcc-1) builder="build_gcc-1" ;;
    --target) builder="build_fortarget" ;;
    *)
        exit 47
        ;;
    esac

    if "${builder}" "${pkg_name}"; then
        write_log_msg "Completed ${pkg_name}"
        refresh_path
    else
        write_log_msg --err --level=4 "${pkg_name} build failed"
        return 1
    fi
}

unexpected_patch() {
    local header="${SOURCE_ROOT}/expect5.45.4/exp_int.h"

    # Check if the macro is already defined
    if ! grep -q "_ANSI_ARGS_" "$header"; then
        echo "_ANSI_ARGS_ not found, patching $header..."
        # Insert at the very top of the file
        sed -i '1i\
#ifndef _ANSI_ARGS_\
#define _ANSI_ARGS_(x) x\
#endif\
' "$header"
        echo "Patch applied."
    else
        echo "_ANSI_ARGS_ already present, no changes made."
    fi
}

# ---------------- Where Things Are Actually Called --------------- #
write_log_msg "Setting native build environment variables"
native_build_env

runner tcl --host
unexpected_patch
runner expect --host
runner dejagnu --host
runner zlib --host
runner gmp --host
runner mpfr --host
runner mpc --host
runner isl --host
runner gettext --host
runner texinfo --host
runner binutils --host

export LD_LIBRARY_PATH=/home/alyssa3467/projects/mcgregor/toolchain/install/x86_64-pc-linux-gnu/lib:/home/alyssa3467/projects/mcgregor/toolchain/install/x86_64-pc-linux-gnu/lib/gprofng
export LD_RUN_PATH=/home/alyssa3467/projects/mcgregor/toolchain/install/x86_64-pc-linux-gnu/lib:/home/alyssa3467/projects/mcgregor/toolchain/install/x86_64-pc-linux-gnu/lib/gprofng

runner gcc-stage-1 --gcc-1
