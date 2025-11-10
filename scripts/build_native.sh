#!/bin/bash
set -ueo pipefail

# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

build_forhost() {
    if [[ ! $- =~ e ]]; then
        set -e
        write_log_msg --std --level="$INFO" "Reasserting 'set -e'" 1>&2
    fi
    local pkg_name="$1"

    build_prep --host "${pkg_name}"
    set_window_title "Building ${pkg_name}"

    local filename
    filename=$(basename "$(findpkg "${pkg_name}")")
 
    local flags=()
    flags+=("--prefix=${HOST_INST_DIR}")
    for flag in $(configure_flags "${pkg_name}"); do
        flags+=("${flag}")
    done

    # All packages have a common --prefix
    "${SOURCE_ROOT}"/"${filename}"/configure "${flags[@]}"
    # "${SOURCE_ROOT}/${filename}/configure" --prefix="${HOST_INST_DIR}" $(configure_flags "${pkg_name}")

    write_log_msg "${pkg_name}: make"
    parallel_make
    (write_log_msg "${pkg_name}: make check" && parallel_make check) || (parallel_make test && write_log_msg "${pkg_name}: make test")

    write_log_msg "${pkg_name}: make install"
    parallel_make install
    # verify_artifacts "gmp" \
    #     "${HOST_INST_DIR}/lib/libgmp.a" \
    #     "${HOST_INST_DIR}/lib/libgmpxx.a"
}

findpkg() {
    find "${SOURCE_ROOT}" -maxdepth 1 -type d -name "${1}*" | sort -V | tail -n1
}

configure_flags() {
    if [[ ! $- =~ e ]]; then
        set -e
        write_log_msg --std --level="$INFO" "Reasserting 'set -e'" 1>&2
    fi
    local flags=()
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
        flags=("PATH=${HOST_INST_DIR}/bin" "PKG_CONFIG_PATH=${HOST_INST_DIR}/lib/pkgconfig")
        ;;
    binutils)
        flags=("--with-sysroot=${HOST_SYSROOT}" "--target=${HOST}" "--disable-nls" "--disable-multilib")
        ;;
    *)
        flags=()
        ;;
    esac
    echo "${flags[@]}"
}

runner() {
    if [[ ! $- =~ e ]]; then
        set -e
        write_log_msg --std --level="$INFO" "Reasserting 'set -e'" 1>&2
    fi
    local pkg_name="$1"
    local system="$2"

    case $system in
    --host)
        builder="build_forhost"
        ;;
    --target)
        builder="build_fortarget"
        ;;
    *)
        exit 47
        ;;
    esac

    write_log_msg "Building and installing $pkg_name"
    if "${builder}" "${pkg_name}"; then
        write_log_msg "Completed $pkg_name"
    else
        write_log_msg --err --level=4 "$pkg_name build failed"
        exit 1
    fi
}

# ---------------- Where Things Are Actually Called --------------- #
write_log_msg "Setting native build environment variables"
native_build_env

runner zlib --host
runner gmp --host
runner mpfr --host
runner mpc --host
runner isl --host
runner gettext --host
runner texinfo --host
runner binutils --host
