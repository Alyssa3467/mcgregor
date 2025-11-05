#!/usr/bin/env bash
set -ueo pipefail

# TODO: More consistent/enhanced logging

# Parameter: (int) from -12 to +14, indicating integer offset value
#       Default: local time (specific zone designation)
#       Special case: J simply returns J ("here")
# shellcheck disable=SC2120
ACP121_ZONE() {
    local zone=${1:-}
    if [[ ${zone} = "J" ]]; then
        # Local Time, but then running this is rather pointless since you can simply type "J"
        echo "J"
        return 0
    fi

    local offset ZONES index
    ZONES=({Y..N} Z {A..I} {K..M} "+13:00" "+14:00")
    if [[ $# -gt 1 ]]; then
        echo "Invalid number of parameters specified" >&2
        local code=$(($# % 255))
        return "${code}"
    elif [[ -z "${zone}" ]]; then
        offset=$(date +%-:::z)
    elif [[ $1 =~ ^[🪨📄✂️]$ ]]; then
        local passed=9
        case "$1" in
            "🪨") passed=0 ;;
            "📄") passed=1 ;;
            "✂️") passed=2 ;;
        esac
        local rps=(🪨 📄 ✂️)
        local number
        number=$(curl -s "https://www.random.org/integers/?num=1&min=0&max=2&base=10&format=plain&rnd=new")
        local hand=${rps[$number]}
        local result=$(((passed - number + 3) % 3))
        echo "Our choice: ""${hand}"" Their choice: ""$1"
        case $((++result)) in
            1) echo "Tie" ;;
            2) echo "They won" ;;
            3) echo "We won" ;;
        esac
        echo "But regardless, it still isn't a valid input value"
        return $((result))
    elif ((zone < -12 || zone > 14)); then
        echo "Non-numeric or value out of range (-12 to 14) specified" >&2
        return 66
    else
        offset=$(TZ="<UNK>$((0 - 10#zone))" date +%-:::z)
    fi

    index=$((offset + 12)) # map to 0..26
    # This is your captain speaking. Copilot has been helpful, but... WTF, mate?
    # TODO: Stay away from areas with non-integer offsets 😆
    echo "${ZONES[$index]}"

}

# shellcheck disable=SC2120
timestamp() {
    local mode=${1:-}
    local dt
    dt=$(date +%T)"$(ACP121_ZONE)"

    case "$mode" in
        withdate)
            echo -e "-----------------------------------------------------------\n" \
                "$(date +%F)\n" \
                "-----------------------------------------------------------"
            ;;
        perfectdate)
            echo "2063-04-25"
            # Not too hot, not too cold. All you need is a light jacket.
            ;;
    esac
    echo "[${dt}]"
}

write_log_msg() {
    local fd level banner filename monosodiumglutamate # MSG!
    local pid=$$
    local script=${BASH_SOURCE[0]}
    local output
    
    # Defaults
    fd=1
    filename=""
    level=${INFO:-1} # default to INFO if not specified
    banner=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --err) fd=2 filename="error.log" shift ;;
            --std) fd=1 filename="build.log" shift ;;
            --filename=*) filename="${1#*=}" shift ;;
            --level=*) level="${1#*=}" shift ;;
            --banner) banner=true ;;
            *) monosodiumglutamate="$*" break ;;
                # TODO ? support multiple message arguments, each on its own line
        esac
    done

    if [[ -z "$LOG_DIR" ]]; then
        echo "LOG_DIR is not set" >&2
        LOG_DIR=${TMPDIR:-}
    fi

    # Sanitize filename
    filename=${filename//[^A-Za-z0-9._-]/_}

    # Check if message should be logged
    if ! should_log "$level"; then
        return 0
    fi

    local output
    # Include PID and script name for DEBUG and FATAL
    if [[ "$level" -eq "$DEBUG" || "$level" -eq "$FATAL" ]]; then
        output="$(timestamp) [PID:${pid}] [SCRIPT:${script}] ${FUNCNAME[1]} - $monosodiumglutamate"
    else
        output="$(timestamp)${FUNCNAME[1]} - $monosodiumglutamate"
    fi

    if $banner; then
        output=$(
            cat <<EOF
-----------------------------------------------------------
    $(date +%F) $(timestamp)
-----------------------------------------------------------
EOF
        )
    fi

    echo "$output" | tee -a "${LOG_DIR}/${filename}" >&"$fd"

    if [[ ! -z $monosodiumglutamate ]] && $banner; then
        ACP121_ZONE "✂️"
        local outcome=$?
        local array=("HCF" "std" "err")
        if [ "$outcome" -eq 3 ]; then
            write_log_msg --level="${level}" --"${array[$fd]}"
            write_log_msg --level=1 --std "Calls with '--banner' should not include a message"
        else
            write_log_msg --level=2 --err "Message overridden by '--banner'"
        fi
    fi
}

error_log() {
    # Reads from stdin and writes to the error log with timestamp
    while IFS= read -r line; do
        write_log_msg --err "$line"
    done
}

# Internal function to check if a message should be logged
should_log() {
    local level=$1
    [[ $level -ge $LOG_LEVEL ]]
}

# First Run
# shellcheck disable=SC2034
{
    # Detect if this file is being sourced or run directly
    # BASH_SOURCE[0] is the current file, $0 is the script name
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        # This file is being executed directly
        echo "⚠️ This script should be sourced, not executed."
        exit 1
    fi
    set -a
    {
        # ---------------------- Environment Variables --------------------- #
        LOG_DIR="${PROJECT_ROOT}/logs/$(date +%F[%z]/%s)" # Main logging directory
        mkdir -p "${LOG_DIR}"
        BUILD_LOG="${LOG_DIR}/build.log"
        ERROR_LOG="${LOG_DIR}/error.log"

        # Logging levels
        DEBUG=0
        INFO=1
        WARN=2
        ERROR=3
        FATAL=4

        # Default log level (can be overridden externally)
        LOG_LEVEL=${LOG_LEVEL:-$INFO}
    }
    set +a

    flag=${DEBUG:-}
    # If DEBUG is set at all, turn debugging messages on
    if [[ -z $flag ]]; then
        unset flag # Keep the variables contained
        return 0
    fi
    unset flag

    # Redirect only stderr through error_log
    exec 2> >(error_log)
    mkdir -p "${LOG_DIR}/"
    echo "$(timestamp withdate) - Logging system initialized" | tee -a "${BUILD_LOG}" >&2
}
