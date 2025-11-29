#!/usr/bin/env bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "What are you doing‽ Don't run this RAW, you Muppet®! Source it!" >&2
    exit 1
fi

# sourceable: parses args, sets USE_GCC_SYMLINKS and exports GCC_SYMLINKS (space-separated)
set -euo pipefail

# ---- internal bit masks ----
_GMP_BIT=1
_ISL_BIT=2
_MPC_BIT=4
_MPFR_BIT=8
_ZLIBC_BIT=16
_BINUTILS_BIT=32
_NEWLIB_BIT=64

: "${_gcc_symlink_flags:=0}"
_remaining_args=() # collect leftover args

_gcc_parse_args() {
    local _arg
    for _arg in "$@"; do
        case "$_arg" in
        --with-gmp-symlink) _gcc_symlink_flags=$((_gcc_symlink_flags | _GMP_BIT)) ;;
        --with-isl-symlink) _gcc_symlink_flags=$((_gcc_symlink_flags | _ISL_BIT)) ;;
        --with-mpc-symlink) _gcc_symlink_flags=$((_gcc_symlink_flags | _MPC_BIT)) ;;
        --with-mpfr-symlink) _gcc_symlink_flags=$((_gcc_symlink_flags | _MPFR_BIT)) ;;
        --use-gcc-symlinks) _gcc_symlink_flags=$((_gcc_symlink_flags | _GMP_BIT | _ISL_BIT | _MPC_BIT | _MPFR_BIT)) ;;
        --YOLO-gcc-symlinks) _gcc_symlink_flags=$((_gcc_symlink_flags | _GMP_BIT | _ISL_BIT | _MPC_BIT | _MPFR_BIT | _ZLIBC_BIT | _BINUTILS_BIT | _NEWLIB_BIT)) ;;
        --with-zlibc-symlink) _gcc_symlink_flags=$((_gcc_symlink_flags | _ZLIBC_BIT)) ;;
        --with-binutils-symlink) _gcc_symlink_flags=$((_gcc_symlink_flags | _BINUTILS_BIT)) ;;
        --with-newlib-symlink) _gcc_symlink_flags=$((_gcc_symlink_flags | _NEWLIB_BIT)) ;;
        *) _remaining_args+=("$_arg") ;; # collect unknown args
        esac
    done
}

# parse provided args if any
_gcc_parse_args "$@"

# build space-separated string
_gcc_list=""
((_gcc_symlink_flags & _GMP_BIT)) && _gcc_list="${_gcc_list:+${_gcc_list} }gmp"
((_gcc_symlink_flags & _ISL_BIT)) && _gcc_list="${_gcc_list:+${_gcc_list} }isl"
((_gcc_symlink_flags & _MPC_BIT)) && _gcc_list="${_gcc_list:+${_gcc_list} }mpc"
((_gcc_symlink_flags & _MPFR_BIT)) && _gcc_list="${_gcc_list:+${_gcc_list} }mpfr"
((_gcc_symlink_flags & _ZLIBC_BIT)) && _gcc_list="${_gcc_list:+${_gcc_list} }zlibc"

if [[ -n "${_gcc_list}" ]]; then
    USE_GCC_SYMLINKS=true
else
    USE_GCC_SYMLINKS=false
fi
export USE_GCC_SYMLINKS

# Export a single space-separated string for child processes
# Child shells can iterate with: for pkg in $GCC_SYMLINKS; do ...; done
export GCC_SYMLINKS="${_gcc_list:-}"

# Export remaining args as a single space-separated string
export REMAINING_ARGS="${_remaining_args[*]:-}"

# cleanup internals (leave only exported names in environment)
unset _GMP_BIT _ISL_BIT _MPC_BIT _MPFR_BIT _ZLIBC_BIT _gcc_list _remaining_args
unset -f _gcc_parse_args
unset _gcc_symlink_flags 2>/dev/null || true

# Muppet® is a trademark of The Muppets Studio, LLC, a division of The Walt Disney Company
