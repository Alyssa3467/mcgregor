#!/bin/bash
set -ueo pipefail

if ! (return 0 2>/dev/null); then
    echo "This script must be sourced, not executed." >&2
    exit 1
fi
(
    cd "${SOURCE_ROOT}"
    set_window_title "Extracting archives"
    echo "Extracting archives…"
    for f in *.tar.*; do
        case "$f" in
            *.sig) continue ;;
        esac

        echo -n "$f…"
        diffs=$( (tar -df "$f" 2>&1 |
            grep -Ev 'Mode differs|Uid differs|Gid differs|Mod time differs') || true)
        if [ -z "$diffs" ]; then
            echo " skipped"
            continue
        fi

        # Detect compression type safely
        mime=$(file -b --mime-type "$f")
        case "$mime" in
            application/x-gzip) tar -xzf "$f" ;;
            application/x-bzip2) tar -xjf "$f" ;;
            application/x-xz) tar -xJf "$f" ;;
            application/x-lzip) tar --lzip -xf "$f" ;;
            application/x-lzma) tar --lzma -xf "$f" ;;
            application/x-lzop) tar --lzop -xf "$f" ;;
            application/zstd) tar --zstd -xf "$f" ;;
            application/x-compress) tar -Zxf "$f" ;;
            *) tar -xf "$f" ;; # fallback for plain .tar
        esac

        echo " done"
    done

    # Find the latest GCC directory automatically
    GCC_DIR=$(find "${SOURCE_ROOT}" -maxdepth 1 -type d -name "gcc-*" | sort -V | tail -n1)
    cd "$GCC_DIR"

    # For each dependency, symlink the latest available version
    echo -e "\nCreating GCC dependency symbolic links..."
    for dep in gmp isl mpc mpfr; do
        pkgdir=$(find "${SOURCE_ROOT}" -maxdepth 1 -type d \( -name "${dep}" -o -name "${dep}-*" \) |
            sort -V | tail -n1)

        # If not found, skip silently
        [ -z "$pkgdir" ] && continue

        echo "Linking $PWD/$dep -> $pkgdir"
        ln -sfn "$pkgdir" "$dep"
    done
)
