#!/usr/bin/env bash

if ! (return 0 2>/dev/null); then
    echo "Error" >&2
    exit 255
fi

git-sync() (
    set -euo pipefail

    if [ $# -lt 1 ]; then
        # echo "Usage: git-sync <repo> [--dir DIR] [--ref REF] [--depth N] [--force]" >&2
        echo "Usage: git-sync <repo> [--dir DIR] [--ref REF] [--depth N]" >&2
        return 2
    fi

    REPO_URL="$1"
    shift

    TARGET_DIR=
    REF=
    DEPTH=
    # FORCE=false

    while [ $# -gt 0 ]; do
        case "$1" in
        --dir)
            TARGET_DIR="$2"
            shift 2
            ;;
        --ref)
            REF="$2"
            shift 2
            ;;
        --depth)
            DEPTH="$2"
            shift 2
            ;;
        # --force)
        #     FORCE=true
        #     shift
        #     ;;
        --help)
            # echo "Usage: git-sync <repo> [--dir DIR] [--ref REF] [--depth N] [--force]"
            echo "Usage: git-sync <repo> [--dir DIR] [--ref REF] [--depth N]"
            return 0
            ;;
        *)
            echo "Ignoring unknown/unimplemented option: $1" >&2
            shift
            ;;
        esac
    done

    # default target dir from repo URL if not provided
    if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="$(basename -s .git "${REPO_URL%/}")"
    fi

    remote_has_branch() {
        git ls-remote --heads "$REPO_URL" "refs/heads/$1" | grep -q . 2>/dev/null
    }
    remote_has_tag() {
        git ls-remote --tags "$REPO_URL" "refs/tags/$1" | grep -q . 2>/dev/null
    }

    if [ -d "$TARGET_DIR/.git" ]; then
        echo "Updating existing repository in $TARGET_DIR..."
        git -C "$TARGET_DIR" fetch --all --append "$([ -n "${DEPTH}" ] && echo "--depth=${DEPTH}")" --update-shallow --prune 

        if [ -n "$REF" ]; then
            if ! remote_has_branch "$REF" &&
                ! remote_has_tag "$REF" &&
                ! git -C "$TARGET_DIR" rev-parse --verify --quiet "refs/heads/$REF" >/dev/null; then

                echo "Warning: ref '$REF' not found. Staying on current branch." >&2
                # REF="$(git -C "$TARGET_DIR" rev-parse HEAD)"
                unset REF
            fi
        fi
    fi
)
