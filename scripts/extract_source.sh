#!/bin/bash
set -ueo pipefail

if ! (return 0 2>/dev/null); then
    echo "This script must be sourced, not executed." >&2
    exit 1
fi

cd "${SOURCE_ROOT}"
for f in *.tar.*; do
    case "$f" in
        *.tar.gz) tar -xf "$f" ;;
        *.tar.bz2) tar -xf "$f" ;;
    esac
done

(
    # Find the latest GCC directory automatically
    GCC_DIR=$(find "${SOURCE_ROOT}" -maxdepth 1 -type d -name "gcc-*" | sort -V | tail -n1)
    cd "$GCC_DIR"

    # For each dependency, symlink the latest available version
    for dep in gmp mpfr mpc; do
        pkgdir=$(find "${SOURCE_ROOT}" -maxdepth 1 -type d -name "${dep}-*" | sort -V | tail -n1)
        ln -sfn "$pkgdir" "$dep"
    done
)
