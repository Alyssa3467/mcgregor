#!/usr/bin/env bash
# auxiliaryfunctions

# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

refresh_toolchains() {
    echo "🔄 Refreshing PATH with any new toolchains..."
    for d in "$PWD"/toolchain-*/bin; do
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
    # Pick a label: first arg that isn't a flag or VAR=value
    local label="default"
    for arg in "$@"; do
        if [[ $arg != -* && $arg != *=* ]]; then
            label=$arg
            break
        fi
    done
    local segfault=0
    local attempt=1
    local jobs nextjobs logname
    jobs=$(nproc)
    nextjobs=${jobs}
    label="${PWD##*/}-${label}"
    local safe_label="${label//\//_}"

    while true; do
        nextjobs=$(((jobs * 3) / 4))
        ((nextjobs < 1)) && nextjobs=1
        logname="${LOG_FOLDER}/$(date -u '+%Y%m%dT%H%M%SZ')-${safe_label}-${attempt}.log"
        echo "🔧 Attempt $attempt: make -j$jobs $*" | tee "${logname}"
        if make -j"$jobs" "$@" 2>&1 | tee -a "${logname}"; then
            echo "✅ Build succeeded on attempt $attempt with $jobs jobs"
            break
        elif grep -q "Segmentation fault" "${logname}"; then
            echo "❌ Segmentation fault detected during $label build." | tee -a "${logname}"
            clear
            ((++segfault))
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
            nextjobs=$(((jobs * 3) / 4))
            ((nextjobs < 1)) && nextjobs=1
            echo "⚠️ Build failed with \"-j$jobs\", retrying with \"-j$((nextjobs))\" in 3 seconds..."
            sleep 3
        fi

        #shellcheck disable=SC2322,SC2323 # Now listen here... I'll use as many #@$@# parentheses as I bloody well want!
        jobs=$((((((nextjobs))))))
        attempt=$((attempt + 1))
    done

    echo -e "\n✅ Qapla'"
}
