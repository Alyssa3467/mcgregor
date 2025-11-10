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
    withdatebanner)
        local banner
        banner="
-----------------------------------------------------------
                         $(date +%F)
-----------------------------------------------------------"
        echo "${banner}"
        ;;
    perfectdate)
        echo "2063-04-25"
        # Not too hot, not too cold. All you need is a light jacket.
        ;;
    esac
    echo "[${dt}]"
}

write_log_msg() {
    local fd level banner show_banner filename output level_prefix message_prefix flavoring
    local pid=$$
    local monosodiumglutamate=() # MSG!
    local script=${BASH_SOURCE[0]}
    banner="
-----------------------------------------------------------
    $(date +%F) $(timestamp)
-----------------------------------------------------------"

    fd=1
    filename="build.log"
    level=${INFO:-1} # default to INFO if not specified
    show_banner=false

    local param
    for param in "$@"; do
        case "$param" in
        --err)
            fd=2
            filename="error.log"
            ;;
        --std)
            fd=1
            filename="build.log"
            ;;
        --filename=*)
            filename="${param#*=}"
            ;;
        --level=*)
            level="${param#*=}"
            ;;
        --banner)
            show_banner=true
            ;;
        *)
            monosodiumglutamate+=("$param")
            ;;
        esac
    done

    if [[ ! "${level}" =~ ^([0-9]+|\"\$[A-Za-z_]+\")$ ]]; then
        monosodiumglutamate+=("Invalid log level specified: ${level}")
        level=${ERROR:-3}
        fd=2
        filename="error.log"
    fi

    if [[ -z "$LOG_DIR" ]]; then
        echo "LOG_DIR is not set" >&2
        LOG_DIR=${TMPDIR:-/tmp}
    fi

    # Sanitize filename
    filename=${filename//[^A-Za-z0-9._-]/_}

    # Check if message should be logged
    if ! should_log "$level"; then
        return 0
    fi

    if [[ ${#monosodiumglutamate[@]} -eq 0 ]]; then
        if [[ "${show_banner}" == true ]]; then
            echo "${banner}" | tee -a "${LOG_DIR}/${filename}" >&"$fd"
        else
            echo "$(timestamp) [This line intentionally left blank]" | tee -a "${LOG_DIR}/${filename}" >&"$fd"
        fi
        return 0 # Early return
    fi

    if [[ ${level} -lt 0 || ${level} -gt ${#LOG_LEVEL_NAMES[@]}-1 ]]; then
        echo "$(timestamp) ${FUNCNAME[1]} [${LOG_LEVEL_NAMES[${WARN:-2}]}] - Invalid log level: ${level}." | tee -a "${LOG_DIR}/error.log" >&2
        level_prefix="[ERROR LEVEL: ${level}]"
    else
        level_prefix="[${LOG_LEVEL_NAMES[${level}]}]"
    fi

    colorized_level() {
        (
            RED='\033[0;31m'
            YELLOW='\033[0;33m'
            GREEN='\033[0;32m'
            BLUE='\033[0;34m'
            RESET='\033[0m'

            if [ "$level" -ge "${ERROR:-3}" ]; then
                color_prefix=$RED
            elif [ "$level" -eq "${WARN:-2}" ]; then
                color_prefix=$YELLOW
            elif [ "$level" -eq "${INFO:-1}" ]; then
                color_prefix=$GREEN
            else
                color_prefix=$BLUE
            fi

            if [[ -t ${fd} ]]; then
                # Output is a terminal; use colors
                echo -e "${color_prefix}${level_prefix}${RESET}"
            else
                # No colors
                echo "${level_prefix}"
            fi
        )
    }

    # Include PID and script name for DEBUG and FATAL
    if [[ "$level" -eq "${DEBUG:-0}" || "$level" -eq "${FATAL:-999}" ]]; then
        message_prefix="$(timestamp) $(colorized_level) [PID:${pid}] [SCRIPT:${script}] ${FUNCNAME[1]} - "
    else
        message_prefix="$(timestamp) $(colorized_level) ${FUNCNAME[1]} - "
    fi

    local first_line=true
    for flavoring in "${monosodiumglutamate[@]}"; do
        if [[ "$first_line" == true ]]; then
            first_line=false
            output="${message_prefix}"
        else
            output="              · "
        fi

        output+="${flavoring}"$'\n'
        # Write primary output
        echo -en "$output" | tee -a "${LOG_DIR}/${filename}" >&"$fd"
        output=""
    done
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
        LOG_LEVEL_NAMES=("DEBUG" "INFO" "WARN" "ERROR" "FATAL")

        # Default log level (can be overridden externally)
        LOG_LEVEL=${LOG_LEVEL:-$INFO}
    }
    set +a

    flag=${DEBUG:-}
    if [[ -z $flag ]]; then
        unset flag # Keep the variables contained
        return 0
    fi
    unset flag

    mkdir -p "${LOG_DIR}/"
    write_log_msg --banner --std
    write_log_msg --banner --err

    echo "$(timestamp) Begin session standard logs" | tee -a "${BUILD_LOG}" >&1
    echo "$(timestamp) Begin session error logs" | tee -a "${ERROR_LOG}" >&2
}
