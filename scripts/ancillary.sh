#!/usr/bin/env bash
set -ueo pipefail

if ! (return 0 2>/dev/null); then
    echo "This script must be sourced, not executed." >&2
    exit 1
fi

# -------------------------------- Trap stuff -------------------------------- #
# TODO: functions to remove existing traps?
# ---------------------------------------------------------------------------- #
add_trap() {
    local cmd="$1"
    local signal="$2"

    # Special case: unify EXIT handling with EXIT_HANDLERS
    if [[ "$signal" =~ ^(EXIT|exit)$ ]]; then
        add_exit_handler "$cmd"
        return 0
    fi

    local existing_cmd
    existing_cmd=$(trap -p "$signal" | awk -F"'" '{print $2}')
    # shellcheck disable=SC2064
    trap "${existing_cmd:+$existing_cmd; }$cmd" "$signal"
}

export EXIT_HANDLERS=()
add_exit_handler() {
    EXIT_HANDLERS+=("$1")
}
run_exit_handlers() {
    for handler in "${EXIT_HANDLERS[@]}"; do
        eval "$handler" || echo -e "${handler} exited with code $?" >&2
    done
}

cleanup() {
    status=$?
    cmd=$BASH_COMMAND
    echo "[EXIT] status=$status, last command: \"$cmd\"" >&2 | tee -a "${ERROR_LOG}"
    if [[ -n "${PROJECT_ROOT:-}" && -d "${PROJECT_ROOT}/tmp" ]]; then
        rm -rf "${PROJECT_ROOT}/tmp"
    fi
    echo "so long and thanks for all the fish" >&2
}

curl_wrapper() {
    # Just a thin shim around curl with basic failure handling
    curl --fail --silent --show-error "$@"
}

# ---------------------------------------------------------------------------- #
#       Does two Mega Millions-style draws and returns TRUE if they match      #
# ---------------------------------------------------------------------------- #
lotto() {
    org_temp=$(mktemp lotto_org.XXXXXX)
    ur_temp=$(mktemp lotto_ur.XXXXXX)
    {
        #----------------- What does the server say about our quota? ----------------- #
        (($(curl -s "https://www.random.org/quota/?format=plain") > 9000)) || return 1
        # -------------- What? 9000? There's no way that could be right. ------------- #

        # Get 5 numbers from random.org (1–70), sorted
        nums=$(curl_wrapper -s "https://www.random.org/integers/?num=5&min=1&max=70&col=1&base=10&format=plain&rnd=new")
        readarray -t arr <<<"$nums"
        sorted_org=$(for i in "${arr[@]}"; do echo "$i"; done | (LC_ALL=C sort -n))

        # Get 1 number from random.org (1–25)
        sixth=$(curl_wrapper -s "https://www.random.org/integers/?num=1&min=1&max=25&col=1&base=10&format=plain&rnd=new")
        echo "$sorted_org"$'\n'"$sixth" >"${org_temp}"
    } &

    {
        # Get 5 numbers from /dev/urandom (1–70), sorted
        ur_arr=()
        while [ "${#ur_arr[@]}" -lt 5 ]; do
            num=$((($(od -An -N2 -tu2 </dev/urandom) % 70) + 1))
            ur_arr+=("$num")
        done
        sorted_ur=$(for i in "${ur_arr[@]}"; do echo "$i"; done | (LC_ALL=C sort -n))

        # Get 1 number from /dev/urandom (1–25)
        sixth_ur=$((($(od -An -N2 -tu2 </dev/urandom) % 25) + 1))
        echo "$sorted_ur"$'\n'"$sixth_ur" >"${ur_temp}"
    } &

    wait

    mapfile -t org_nums <"$org_temp"
    mapfile -t ur_nums <"$ur_temp"
    rm -f "$org_temp" "$ur_temp"

    if [ "${org_nums[*]}" = "${ur_nums[*]}" ]; then
        return 0
    else
        return 1
    fi
}

# ---------------------------- Build preparations ---------------------------- #
# Usage:
#   build_prep [--no-wipe] <target_dir>
#
# Arguments:
#   --no-wipe    Optional flag. If provided, the function will NOT delete
#                the contents of <target_dir>. Instead, it will preserve
#                whatever is already there.
#   <target_dir> Required. The name of the directory that should be prepared.
#                The new directory will be under ${BUILD_ROOT}
#
# Behavior:
#   - Validates arguments and prints usage on error.
#   - By default, deletes and recreates <target_dir> to ensure a clean state.
#   - If --no-wipe is given, preserves existing contents.
#   - Creates the directory if it does not exist.
#   - Logs the current environment variables to $LOG_DIR for reproducibility.
build_prep() {
    local no_wipe=false
    local target_dir=""
    local nonflag_count=0
    local last_component sanitized

    # Thy must choose only one <target_dir>
    # The number of parameters shall be no more than 2.
    # Before 2, thou cannot even, so zero is not allowed.
    # Three is right out. Under no condition shall thou reach 5.
    # A negative number has square roots only within thine imagination.
    if (($# < 1 || $# > 2)); then
        echo "Usage: build_prep [--no-wipe] <target_dir>" >&2
        return 1
    fi

    if (($# < 0)); then
        echo "Error: Negative parameters are forbidden." >&2
        # shellcheck disable=SC2152
        return 420 # How dost thou even reach this line?
    fi

    for arg in "$@"; do
        case "$arg" in
            --no-wipe) no_wipe=true ;;
            *)
                target_dir="$arg"
                ((++nonflag_count))
                ;;
        esac
    done

    # Explicitly reject two non‑flag arguments
    if ((nonflag_count > 1)); then
        echo "Error: only one non-flag argument (target_dir) is allowed." >&2
        return 1
    fi

    if [[ -z "$target_dir" ]]; then
        echo "Error: target_dir is required." >&2
        return 1
    fi

    # Extract final component
    last_component="${target_dir##*/}"

    sanitized=$(echo "$last_component" | tr -d '\000-\037' | tr '/\\:*?"<>|' '_')

    # Handle reserved Windows device names
    case "$sanitized" in
        CON | PRN | AUX | NUL | COM[1-9] | LPT[1-9])
            sanitized="_${sanitized}"
            ;;
    esac

    # Detect multiple path components
    # Rule: only "path" or "/path" is considered a single component
    if [[ "$target_dir" == */* ]]; then
        write_log_msg --std --level=1 "Multiple path components detected; only the last will be used: $sanitized"
    else
        write_log_msg --std --level=0 echo "Using: $sanitized"
    fi

    target_dir=${BUILD_ROOT}/${sanitized}
    # Erase what's there and create a fresh new directory unless told otherwise
    if [[ "$no_wipe" == false ]]; then
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"

    local flag=${DEBUG:-}
    # TODO: different reporting levels?
    # If DEBUG is set at all, log the current environment
    if [[ -n $flag ]]; then

        # Capture the environment
        local log_file
        log_file="${LOG_DIR}/prep-${sanitized}-env-dump.log"
        echo -e "\n$(timestamp withdate)\n" | tee -a "$log_file" >/dev/null
        env | sort | tee -a "$log_file" >/dev/null
    fi

    cd "$target_dir" || return 1
}

# -------------------------------------------------------- #
#              Finds directories called "bin"              #
#           and puts them at the head of the path          #
# -------------------------------------------------------- #
refresh_path() {
    # Find all bin directories under toolchain at any depth
    mapfile -t BIN_DIRS < <(find "${PROJECT_ROOT}/toolchain" -type d -name bin)

    PATH="${PATH:-/usr/bin:/bin}"
    echo "🔄 Refreshing PATH with any new toolchains..." >&2

    for d in "${BIN_DIRS[@]}"; do
        case ":$PATH:" in
            *":$d:"*) echo "   ✅ $d already in PATH" >&2 ;;
            *)
                echo "   ➕ Adding $d" >&2
                PATH="$d:$PATH"
                ;;
        esac
    done

    export PATH
}

# -------------------------------------------------------- #
#       Starts "make -jN" and lowers N until it works      #
# -------------------------------------------------------- #
parallel_make() {
    # Require LOG_DIR to be set
    if [[ -z "$LOG_DIR" ]]; then
        echo "💥 LOG_DIR is not set. Where exactly do you expect me to put the logs, a fire pit?" >&2
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
            loglabel=*)
                label="${arg#loglabel=}" # explicit override
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
        set_window_title "make (${safe_label}) - Attempt #${attempt}"

        # Calculate next job count (3/4 of current, minimum 1)
        nextjobs=$(((jobs * 3) / 4))
        ((nextjobs < 1)) && nextjobs=1

        # Prepare log file
        logname="${LOG_DIR}/${safe_label}-${attempt}.log"
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
            debug_msg "make ${safe_label} failed"
            sleep 3
        fi

        #shellcheck disable=SC2322,SC2323 # Now listen here... I'll use as many #@$@# parentheses as I bloody well want!
        jobs=$((((((nextjobs))))))
        attempt=$((attempt + 1))
    done

    echo -e "\n✅ Qapla'"
}

# ---------------------------------------------------------------------------- #
#                  Random delay between 0.001 and 1.000 second                 #
# ---------------------------------------------------------------------------- #
# ------ Microsoft Copilot wanted to use printf. I vehemently disagreed. ----- #
#
# # printf🙹
# # DISHONOR!!!!! DISHONOR ON YOUR WHOLE FAMILY!!!
# # DISHONOR ON YOU!!!one!!! DISHONOR ON YOUR COW!!!!!
# rand_delay() {
#     local ms=$(($(od -An -N1 -tu1 </dev/urandom) % 1000 + 1))
#     sleep "0.$(printf "%03d" "$ms")"
# }
#
# ------------- Honor restored! You are reinstated, provisionally ------------ #
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
            if [[ "$time" == "0.000" ]]; then time=1; fi
        fi
        sleep "${time}"
    fi
}

# ---------------------------------------------------------------------------- #
#       Sets terminal window title to caller context & truncated message.      #
# ---------------------------------------------------------------------------- #
set_window_title() {
    local caller="${FUNCNAME[2]}"
    local current="${FUNCNAME[1]}"
    local raw="$*"

    # Sanitize: remove non-printable characters and escape sequences
    if [[ -t 1 ]] && tput cols >/dev/null 2>&1; then
        local clean
        clean=$(echo "$raw" | tr -dC '[:print:]' |
            sed 's/[[:space:]]\+/ /g' |
            sed 's/[\/\\\"\047]/_/g')

        # Truncate to a safe length (e.g., 80 characters)
        local max_length=128
        message="${caller} - ${current} - ${clean}"
        if ((${#message} > max_length)); then
            message="${message:0:max_length}…"
        fi

        # Actual window title setting thingy
        echo -ne "\033]0;${message}\007" >&2
        # BEL. James BEL.
    fi
}

# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed." >&2
    exit 1
fi

# ------------------------- Some "housekeeping" tasks ------------------------ #
{
    mkdir -p "${TMPDIR}" "${SOURCE_ROOT}" "${LOG_DIR}"

    trap 'echo "Interrupted (INT), cleaning up…" >&2; cleanup; exit 130' INT
    trap 'echo "Terminated (TERM), cleaning up…" >&2; cleanup; exit 143' TERM
    trap run_exit_handlers EXIT

    add_exit_handler cleanup
}

verify_artifacts() {
    local label="$1"
    shift
    local missing=0
    local ts
    ts="$(timestamp)"

    echo "🔍 Verifying artifacts for: $label"

    for file in "$@"; do
        if [[ ! -e "$file" ]]; then
            echo "${ts} - [${label}] - ⚠️ Warning: Missing expected file: $file" | tee -a "$ERROR_LOG" >&2
            ((++missing))
        else
            echo "✅ Found: $file"
        fi
    done

    if ((missing > 0)); then
        echo "${ts} - [${label}] - ⚠️ $missing artifact(s) missing for $label." | tee -a "$ERROR_LOG" >&2
    else
        echo "✅ All expected artifacts for $label are present."
    fi

    # Extra check only if label starts with "gcc-"
    if [[ $label == gcc-* ]]; then
        local cc="${HOST_INST_DIR}/bin/${HOST}-gcc"
        local sysroot
        sysroot="$($cc -print-sysroot 2>/dev/null)"
        local crtbegin
        crtbegin="$($cc -print-file-name=crtbegin.o 2>/dev/null)"

        if [ -z "$sysroot" ]; then
            echo "${ts} ❌ $label: compiler did not report a sysroot" | tee -a "$ERROR_LOG" >&2
        elif [ "$crtbegin" = "crtbegin.o" ] || [ ! -f "$crtbegin" ]; then
            echo "${ts} ❌ $label: compiler cannot locate crtbegin.o (sysroot=$sysroot)" | tee -a "$ERROR_LOG" >&2
        else
            echo "✅ $label: sysroot=$sysroot, crtbegin.o found at $crtbegin"
        fi
    fi
}

# Run a command with xtrace enabled, then restore the previous state
verbose() {
    set -x
    "$@"
    local status=$?
    set +x
    debug_msg "($*) returned with status $status" >&2
    return $status
}

# Run a command with errexit disabled, then restore it
YOLO() {
    set +e
    "$@"
    local status=$?
    set -e
    debug_msg "($*) returned with status $status" >&2
    return $status
}

# TODO: get rid of this
printsomestuff() {
    set -x
    find "${TOOLCHAIN_ROOT}" -name "crtbegin.o"
    echo
    echo "HOST_INST_DIR: ${HOST_INST_DIR}"
    echo "HOST_SYSROOT: ${HOST_SYSROOT}"
    # Microsoft Copilot needs to stop being so fucking condescending
    set +x
}
add_exit_handler printsomestuff

clean_shell() {
    if [ $# -eq 0 ]; then
        echo "clean_shell: command required" >&2
        return 1
    fi
    env -i \
        HOME="$HOME" \
        TERM="${TERM:-xterm}" \
        PATH="/usr/bin:/bin" \
        "$@"
}
