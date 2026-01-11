#!/usr/bin/env bash

if ! (return 0 2>/dev/null); then
    echo "Error" >&2
    exit 64
fi

git-sync() (
    # TODO: Finish all possible paths
    # set -euox'' pipefail

    # ---------------------------- Local Variables --------------------------- #
    local TARGET_DIR REF DEPTH FORCE=false depth_opt refspec ls_result

    # ------------------------------ Parameters ------------------------------ #
    {
        set -euo pipefail

        # Require at least one argument
        if [ $# -lt 1 ] || [ "$1" = "--help" ]; then
            echo "Usage: git-sync <repository> [--dir <directory>] [--ref <refspec>] [--depth N] [--force]" >&2
            return 64
        fi

        case "$1" in
        --dir | --ref | --depth | --force)
            echo "Error: missing repository argument before optional parameters" >&2
            return 64
            ;;
        --*)
            # https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?sectionNum=5150&lawCode=WIC
            echo "§5150" >&2
            return 69
            ;;
        esac

        REPO_URL="$1"
        shift

        # Validate Git URL format against man page examples
        if ! [[ "$REPO_URL" =~ ^(ssh://|git://|https?://|ftps?://|file://|/|[A-Za-z0-9._%+-]+@?[A-Za-z0-9.-]+:).+(\.git)?/?$ ]]; then
            echo "Error: '$REPO_URL' does not look like a valid Git URL" >&2
            return 64
        fi

        while [ $# -gt 0 ]; do
            case "$1" in
            --dir)
                if [ $# -ge 2 ]; then
                    TARGET_DIR="$2"
                    # verify directory name and permissions
                    if ! [ -d "$TARGET_DIR" ] && ! [ -w "$(dirname "$TARGET_DIR")" ]; then
                        echo "Error: cannot use '$TARGET_DIR' as a directory (invalid name or insufficient permissions)" >&2
                        return 64
                    fi
                    shift 2
                else
                    echo "Error: --dir requires a directory argument" >&2
                    return 64
                fi
                ;;
            --ref)
                # Nonfatal errors; script can continue with default branch if ref is invalid
                if [ $# -ge 2 ]; then
                    REF="$2"
                    if ! git check-ref-format --normalize --refspec-pattern "*/$REF" >/dev/null 2>&1; then
                        echo "Warning: '$REF' is not a valid reference name; ignoring value" >&2
                        unset REF
                    fi
                    shift 2
                else
                    echo "Warning: --ref requires a reference argument; ignoring option" >&2
                    unset REF
                    shift
                fi
                ;;
            --depth)
                # Nonfatal error; script can continue with full clone if depth is invalid
                if [ $# -ge 2 ] && [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
                    DEPTH="$2"
                    depth_opt=("--depth=${DEPTH}")
                    shift 2
                else
                    echo "Warning: --depth requires a positive integer; ignoring option" >&2
                    shift
                fi
                ;;
            --force)
                FORCE=true
                shift
                ;;
            *)
                echo "Ignoring unknown/unimplemented option: $1" >&2
                shift
                ;;
            esac
        done
    }
    # --------------------------- Nested Functions --------------------------- #
    {
        # Check if a remote branch exists
        remote_has_branch() {
            if (git ls-remote --exit-code --heads "${REPO_URL}" "refs/heads/$1"); then
                return 0
            fi
            return 1
        }

        # Check if a remote tag exists
        remote_has_tag() {
            if (git ls-remote --exit-code --tags "${REPO_URL}" "refs/tags/$1"); then
                return 0
            fi
            return 1
        }
    }

    # default target dir from repo URL if not provided
    if [ -z "${TARGET_DIR}" ]; then
        TARGET_DIR="${REPO_URL##*/}"
        TARGET_DIR="${TARGET_DIR%.git}"
    fi

    # See if there's anything in ${TARGET_DIR}
    ls_result=$(ls -A "${TARGET_DIR}" 2>/dev/null || true)

    if [ -v REF ]; then
        if remote_has_branch "${REF}"; then
            refspec=$(git check-ref-format --normalize "refs/heads/$REF" 2>/dev/null || echo "")
        elif remote_has_tag "${REF}"; then
            refspec=$(git check-ref-format --normalize "refs/tags/$REF" 2>/dev/null || echo "")
        else
            echo "Warning: ref '${REF}' not found. Staying on current branch." >&2
            unset REF
        fi
    fi

    # If ${TARGET_DIR} exists...
    if [ -d "${TARGET_DIR}" ]; then
        # If ${TARGET_DIR} is a git repository...
        if git -C "${TARGET_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
            echo "Updating existing repository in ${TARGET_DIR}..."

            # Do the thing!
            git -C "${TARGET_DIR}" fetch "${depth_opt[@]}" "${REPO_URL}" "${refspec:-}"
        elif [ -n "${ls_result}" ]; then
            if [ "${FORCE}" = true ]; then
                # ${TARGET_DIR} exists but is not a git repo. Deleting per --force option.
                echo "Attempting to clear non-git directory ${TARGET_DIR} per --force option..."
                rm -rf "${TARGET_DIR:?}/"{.,}*
                ls_result=$(ls -A "${TARGET_DIR}" 2>/dev/null || true)
                if [ -n "${ls_result}" ]; then
                    echo "Error: failed to clear directory ${TARGET_DIR} for cloning" >&2
                    return 74
                fi
            else
                echo "Error: directory ${TARGET_DIR} exists but is not a git repository (use --force to override)" >&2
                return 73
            fi
        fi
    fi
    if [ -z "${ls_result}" ] || [ ! -d "${TARGET_DIR}" ]; then
        fresh=true
        if git clone "${depth_opt[@]}" "${REPO_URL}" "${TARGET_DIR}"; then
            echo "Repository cloned successfully."
        else
            echo "Error: failed to clone repository into ${TARGET_DIR}" >&2
            return 74
        fi
    fi

    # If a ${REF} was specified, check it out, otherwise stay on default branch
    if [ -v REF ] && [ -n "${REF}" ]; then
        echo "Checking out ${REF}..."
        git -C "${TARGET_DIR}" checkout "${REF}"
        return 0
    else
        # For a fresh new clone with no specified ref, check out the default branch
        [ "${fresh:-false}" = true ] &&
            git checkout "$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
        return 0
    fi

    # shellcheck disable=SC2317
    return 66
    # The only unreachable code ShellCheck was able to catch
)

refresh_path() {
    # Find all bin directories under toolchain at any depth
    mapfile -t BIN_DIRS < <(find "${PROJECT_ROOT}/toolchain" -type d -name bin)

    PATH="${PATH:-/usr/bin:/bin}"
    echo "Refreshing PATH with any new ./bin directories..." >&2

    for d in "${BIN_DIRS[@]}"; do
        case ":$PATH:" in
        *":$d:"*) echo "    $d already in PATH" >&2 ;;
        *)
            echo "    Adding $d" >&2
            PATH="$d:$PATH"
            ;;
        esac
    done

    export PATH
    # write_log_msg --level="${INFO}" --std "Set path: PATH=${PATH}"
}

require_var() {
    local prompt=false
    [ "$1" == "--direct-run--" ] && prompt=true && shift

    for var in "$@"; do
        if [[ -z ${!var:-} ]]; then
            if [[ "${prompt}" == true ]]; then
                read -rp "Please enter a value for ${var}: " user_input
                # TODO: sanitize input
                export "${var}"="${user_input}"
            else
                echo "${var} must be set" >&2
                exit 78
            fi
        fi
    done
}
