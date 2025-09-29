#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

# -------------------------------------------------------- #
#                    Build preparations                    #
# -------------------------------------------------------- #
build_prep() {
    local target_dir="$1"

    # First thing: wipe the slate clean.
    # If the directory exists, torch it. Start fresh. No excuses.
    rm -rf "$target_dir"

    # Now, rebuild it properly. Structure, discipline, precision.
    mkdir -p "$target_dir"

    # Get inside the bloody directory. If you can't, you're done.
    cd "$target_dir" || return 1

    # Time stamp it. I want to know *exactly* when this was cooked.
    local timestamp
    timestamp=$(date -u '+%Y%m%dT%H%M%SZ')

    # Strip it down to the basename. None of that messy path garnish.
    local dir_name
    dir_name="${target_dir##*/}"

    # Construct the log file path. Clean, sharp, no clutter.
    local log_file
    log_file="${LOG_DIR}/${timestamp}-${dir_name}-environment.log"

    # Capture the environment. Sort it. Present it properly.
    # And listen carefully: NO printf. Ever. It's raw chicken in code form.
    env | sort | tee "$log_file"

    # Done. Simple, clean, perfect. Anything less and it's rubbish.
    local target_dir="$1"

    # Recreate the build directory
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    cd "$target_dir" || return 1

    # Capture and log the environment in a timestamped file
    local timestamp
    timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
    local log_file="${LOG_DIR}/${timestamp}-${target_dir##*/}-environment.log"

    env | sort | tee "$log_file"
}

# -------------------------------------------------------- #
#              Finds directories called "bin"              #
#           and puts them at the head of the path          #
# -------------------------------------------------------- #
refresh_path() {
# Find all bin directories under toolchain at any depth
mapfile -t BIN_DIRS < <(find "${PROJECT_ROOT}/toolchain" -type d -name bin)

PATH="${PATH:-/usr/bin:/bin}"
echo "🔄 Refreshing PATH with any new toolchains..."

for d in "${BIN_DIRS[@]}"; do
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

# -------------------------------------------------------- #
#       Starts "make -jN" and lowers N until it works      #
# -------------------------------------------------------- #
parallel_make_rampdown() {
    # Require LOG_DIR to be set
    if [[ -z "$LOG_DIR" ]]; then
        echo "💥 LOG_DIR is not set. Where exactly do you expect me to put logs, a fire pit?" >&2
        exit 1
    fi

    # Instantiate variables
    local label segfault attempt jobs nextjobs logname safe_label
    local args=()

    # Initialize variables
    label="default"
    segfault=0
    attempt=1
    jobs=$(nproc)
    nextjobs=$jobs

    # Parse arguments
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
        set_window_title "make ${safe_label} - Attempt #${attempt}"

        # Calculate next job count (3/4 of current, minimum 1)
        nextjobs=$(((jobs * 3) / 4))
        ((nextjobs < 1)) && nextjobs=1

        # Prepare log file
        logname="${LOG_DIR}/$(date -u '+%Y%m%dT%H%M%SZ')-${safe_label}-${attempt}.log"
        rm -f "$logname"

        echo -e "🔧 Attempt $attempt: make -j$jobs ${args[*]}\n" | tee -a "$logname"

        if make -j"$jobs" "${args[@]}" 2>&1 | tee -a "$logname"; then
            echo "✅ Build succeeded on attempt $attempt with $jobs jobs" | tee -a "$logname"
            break
        elif grep -q "Segmentation fault" "$logname"; then
            echo "❌ Segmentation fault detected during $label build." | tee -a "$logname"
            ((++segfault))
            echo -e "Segmentation fault counter: $segfault\n" | tee -a "$logname"

            if ((segfault >= 3)); then
                echo "Three consecutive segmentation faults detected. Switching immediately to sequential build." | tee -a "$logname"
                jobs=1
            fi
        else
            # Reset number of consecutive segfaults
            segfault=0

            # 🚨 If we’re already at sequential and it failed, stop looping
            if ((jobs == 1)); then
                echo "❌ Sequential build failed on attempt $attempt. No further retries." | tee -a "$logname"
                return 1
            fi

            echo "⚠️ Build failed with \"-j$jobs\", retrying with \"-j$nextjobs\" in 3 seconds..."
            sleep 3
        fi

        #shellcheck disable=SC2322,SC2323 # Now listen here... I'll use as many #@$@# parentheses as I bloody well want!
        jobs=$((((((nextjobs))))))
        attempt=$((attempt + 1))
    done

    echo -e "\n✅ Qapla'"
}

# -------------------------------------------------------- #
#        Random delay between 0.001 and 1.000 second       #
# -------------------------------------------------------- #

# # printf🙹
# # DISHONOR!!!!! DISHONOR ON YOUR WHOLE FAMILY!!!
# # DISHONOR ON YOU!!!one!!! DISHONOR ON YOUR COW!!!!!
# rand_delay() {
#     local ms=$(($(od -An -N1 -tu1 </dev/urandom) % 1000 + 1))
#     sleep "0.$(printf "%03d" "$ms")"
# }

# Honor restored! You are reinstated, provisionally
rand_delay() {
    tmp=$(($(od -An -N4 -tu4 </dev/urandom) % 1000000))
    if [ "$tmp" -eq 42 ]; then
        if lotto; then
            sleep 7
        else
            sleep 0
        fi
    else
        tmp=$(("${tmp}" % 2))
        time=0
        if [ "$tmp" -eq 1 ]; then
            ms=$(($(od -An -N1 -tu1 </dev/urandom) % 1000 + 1))
            case "$ms" in
                1000) time=1 ;;
                [0-9]) time="0.00$ms" ;;
                [1-9][0-9]) time="0.0$ms" ;;
                *) time="0.$ms" ;;
            esac
        else
            d1=$(($(od -An -N1 -tu1 </dev/urandom) % 10))
            d2=$(($(od -An -N1 -tu1 </dev/urandom) % 10))
            d3=$(($(od -An -N1 -tu1 </dev/urandom) % 10))
            time="0.$d1$d2$d3"
            if ((time == 0)); then time=1; fi
        fi
        sleep "${time}"
    fi
}

# -------------------------------------------------------- #
#                     Self-explanatory                     #
# -------------------------------------------------------- #
#           Sets window title to "$(caller) - $*           #
# -------------------------------------------------------- #
set_window_title() {
    echo -ne "\033]0;$(caller) - ${*//\//_}\007"
}