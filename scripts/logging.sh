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

    local raw offset ZONES index
    ZONES=({Y..N} Z {A..I} {K..M} "+13:00" "+14:00")
    if [[ $# -gt 1 ]]; then
        echo "Invalid number of parameters specified" >&2
        code=$(($# % 255))
        return "${code}"
    elif [[ -z "${1:-}" ]]; then
        offset=$(date +%-:::z)
    elif [[ $1 =~ ^[🪨📄✂️]$ ]]; then
        passed=9
        case "$1" in
            "🪨") passed=0 ;;
            "📄") passed=1 ;;
            "✂️") passed=2 ;;
        esac
        local rps=(🪨 📄 ✂️)
        number=$(curl -s "https://www.random.org/integers/?num=1&min=0&max=2&base=10&format=plain&rnd=new")
        hand=${rps[$number]}
        result=$(((passed - number + 3) % 3))
        echo "Our choice: ""${hand}"" Their choice: ""$1"
        case "$result" in
            0) echo "Tie" ;;
            1) echo "They won" ;;
            2) echo "We won" ;;
        esac
        echo "But regardless, it still isn't a valid input value"
        return 42
    elif (($1 < -12 || $1 > 14)); then
        echo "Non-numeric or value out of range (-12 to 14) specified" >&2
        return 66
    else
        raw=$1
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
            echo "2063-04-25: "
            ;;
    esac
    echo "[${dt}]: "
}

debug_msg() {
    local flag=${DEBUG:-}
    # If DEBUG is set at all, turn debugging messages on
    if [[ -z $flag ]]; then
        return 0
    fi

    echo "$(timestamp) - ${FUNCNAME[1]} - $*" | tee -a "${LOGFILE}" >&2
}

# First Run
{
    flag=${DEBUG:-}
    # If DEBUG is set at all, turn debugging messages on
    if [[ -z $flag ]]; then
        return 0
    fi

    mkdir -p "${LOG_DIR}/"
    LOGFILE="${LOG_DIR}/debug.log"
    echo "$(timestamp withdate) - ${FUNCNAME[1]:-init_logging} - $*" | tee -a "${LOGFILE}" >&2
}
