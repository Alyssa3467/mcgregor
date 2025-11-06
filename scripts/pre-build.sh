#!/usr/bin/env bash
set -ueo pipefail

if ! (return 0 2>/dev/null); then
    echo "This script must be sourced, not executed." >&2
    exit 1
fi

# Canonicalize a target triple using config.sub
canonicalize_triple() {
    local triple="$1"
    local config_sub="${SCRIPT_DIR}/config.sub"

    if [[ ! -x "$config_sub" ]]; then
        echo "Error: config.sub not found or not executable at $config_sub" >&2
        return 1
    fi

    "$config_sub" "$triple"
}

# Parse arguments: [--no-wipe] <target_triple> <target_dir>
parse_build_prep_args() {
    local no_wipe=false
    local target_dir=""
    local target_triple=""

    if (($# < 1 || $# > 2)); then
        write_log_msg --level="$ERROR" \
            --err "Usage: build_prep [--no-wipe] <target_triple> <target_dir> [--no-wipe]"
        return 1
    elif (($# == 2)); then
        target_triple="$1"
        target_dir="$2"
    else
        case "$1" in
            --no-wipe)
                no_wipe=true
                target_triple="$2"
                target_dir="$3"
                # Emit the requested messages
                write_log_msg --level="$WARN" "[--no-wipe] should be the last parameter."
                write_log_msg --level="$DEBUG" "Nobody listens to me. That makes me sad."
                ;;
            *)
                target_triple="$1"
                target_dir="$2"
                if [[ "$3" == "--no-wipe" ]]; then
                    no_wipe=true
                elif [[ "$2" == "--no-wipe" ]]; then
                    # flag in the middle: accept but warn
                    no_wipe=true
                    target_dir="$3"
                    write_log_msg --level="$WARN" "--no-wipe flag in the middle; accepted but unusual."
                fi
                ;;
        esac
    fi

    # Must have exactly one triple and one dir
    if [[ -z "$target_triple" || -z "$target_dir" ]]; then
        write_log_msg --level="$FATAL" "Must provide one target triple and one target directory." >&2
        return 1
    fi

    echo "$target_triple $target_dir $no_wipe"
}

# Sanitize the last path component for filesystem safety
sanitize_component() {
    local input="$1"
    local sanitized

    sanitized=$(echo "$input" | tr -d '\000-\037' | tr '/\\:*?"<>|' '_')

    case "$sanitized" in
        CON | PRN | AUX | NUL | COM[1-9] | LPT[1-9])
            sanitized="_${sanitized}"
            ;;
    esac

    echo "$sanitized"
}

# Decide message based on path components; only last is used
report_component_usage() {
    local target_dir="$1"
    local sanitized="$2"

    if [[ "$target_dir" == */* ]]; then
        echo "Multiple path components detected; only the last will be used: $sanitized"
    else
        echo "Using: $sanitized"
    fi
}

# Safely prepare the target directory
prepare_target_dir() {
    local specific_build_root="$1"
    local sanitized="$2"
    local no_wipe="$3"

    local dir="${specific_build_root}/${sanitized}"

    if [[ -z "$specific_build_root" || -z "$sanitized" ]]; then
        echo "Error: specific_build_root and sanitized must be set." >&2
        return 1
    fi

    if [[ "$no_wipe" == false ]]; then
        # Lest ye smite the wrong directory, verify the target before removal.
        if [[ "$dir" == "/" || -z "$dir" ]]; then
            echo "Error: unsafe target directory for removal." >&2
            return 1
        fi
        rm -rf -- "$dir"
    fi

    mkdir -p -- "$dir"
    echo "$dir"
}

# Optional environment logging when DEBUG is set
log_environment_if_debug() {
    local debug_flag="$1"
    local the_log_dir="$2"
    local sanitized="$3"

    if [[ -n "$debug_flag" ]]; then
        local log_file="${the_log_dir}/prep-${sanitized}-env-dump.log"
        echo -e "\n$(timestamp withdate)\n" | tee -a "$log_file" >/dev/null
        env | sort | tee -a "$log_file" >/dev/null
    fi
}

# Orchestrator
build_prep() {
    local target_triple target_dir no_wipe

    # Capture parser output directly into variables
    read -r target_triple target_dir no_wipe < <(parse_build_prep_args "$@") || return 1

    # Canonicalize the triple
    target_triple=$(canonicalize_triple "$target_triple") || return 1

    # Verify directory exists
    if [ ! -d "${BUILD_ROOT}/${target_triple}" ]; then
        write_log_msg --level="$ERROR" --err "Invalid target specified calling build_prep()"
        exit "$ERROR"
    fi

    sanitized=$(sanitize_component "$target_dir")

    write_log_msg --level="$INFO" --std "Preparing build directory: ${BUILD_ROOT}/${target_triple}/${sanitized}"

    target_path=$(prepare_target_dir "$target_triple" "$sanitized" "$no_wipe") || return 1

    log_environment_if_debug "${DEBUG:-}" "${LOG_DIR}" "${sanitized}"

    cd "$target_path" || return 1
}
