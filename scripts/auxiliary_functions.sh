#!/usr/bin/env bash
# auxiliaryfunctions

# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

build_prep() {
    local dir="$1"
    rm -rf "$dir"
    mkdir -p "$dir"
    cd "$dir" || return 1
    env | sort | tee "${LOG_FOLDER}/$(date -u '+%Y%m%dT%H%M%SZ')-${dir##*/}-environment.log"
}

refresh_toolchains() {
    PATH="${PATH:-/usr/bin:/bin}"
    echo "🔄 Refreshing PATH with any new toolchains..."
    for d in "${PROJECT_ROOT}"/toolchain-*/bin; do
        [ -d "$d" ] || continue
        case ":$PATH:" in
        *":$d:"*) echo "   ✅ $d already in PATH" ;;
        *)
            echo "   ➕ Adding $d"
            PATH="$d:$PATH"
            ;;
        esac
    done
    export PATH
}

parallel_make_rampdown() {
    # Require LOG_FOLDER to be set
    if [[ -z "$LOG_FOLDER" ]]; then
        echo "💥 LOG_FOLDER is not set. Where exactly do you expect me to put logs, in the fire pit?" >&2
        exit 1
    fi

    # Instantiate variables
    local label segfault attempt jobs nextjobs logname safe_label

    # Initialize variables
    label="default"
    segfault=0
    attempt=1
    jobs=$(nproc)
    nextjobs=${jobs}

    # Parse arguments
    local args=()
    for arg in "$@"; do
        case "$arg" in
        startjobs=*)
            jobs="${arg#startjobs=}"
            ;;
        label=*)
            label="${arg#label=}" # explicit override
            ;;
        *)
            args+=("$arg")
            # If no explicit label yet, use first non-flag/assignment arg
            if [[ $label == "default" && $arg != -* && $arg != *=* ]]; then
                label=$arg
            fi
            ;;
        esac
    done

    # Prepend working directory to the label, and sanitize it
    label="${PWD##*/}-${label}"
    safe_label="${label//\//_}"

    while true; do
        nextjobs=$(((jobs * 3) / 4))
        ((nextjobs < 1)) && nextjobs=1
        logname="${LOG_FOLDER}/$(date -u '+%Y%m%dT%H%M%SZ')-${safe_label}-${attempt}.log"
        rm -f "${logname}"
        echo -e "🔧 Attempt $attempt: make -j$jobs ${args[*]}\n" | tee -a "${logname}"
        if make -j"$jobs" "${args[@]}" 2>&1 | tee -a "${logname}"; then
            echo "✅ Build succeeded on attempt $attempt with $jobs jobs" | tee -a "${logname}"
            break
        elif grep -q "Segmentation fault" "${logname}"; then
            echo "❌ Segmentation fault detected during $label build." | tee -a "${logname}"
            clear
            ((++segfault))
            echo -e "Segmentation fault counter: ${segfault}\n" | tee -a "${logname}"
            if ((segfault >= 3)); then
                echo "Three consecutive segmentation faults detected. Switching immediately to sequential build." | tee -a "${logname}"
                jobs=1
            fi
        else
            # Reset number of consecutive segfaults
            segfault=0
            # 🚨 If we’re already at sequential and it failed, stop looping
            if ((jobs == 1)); then
                echo "❌ Sequential build failed on attempt $attempt. No further retries." | tee -a "${logname}"
                return 1
            fi

            echo "⚠️ Build failed with \"-j$jobs\", retrying with \"-j$((nextjobs))\" in 3 seconds..."
            sleep 3
        fi

        #shellcheck disable=SC2322,SC2323 # Now listen here... I'll use as many #@$@# parentheses as I bloody well want!
        jobs=$((((((nextjobs))))))
        attempt=$((attempt + 1))
    done

    echo -e "\n✅ Qapla'"
}
