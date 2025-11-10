#!/usr/bin/env bash
set -ueo pipefail

if ! (return 0 2>/dev/null); then
    echo "This script must be sourced, not executed." >&2
    exit 1
fi

is_valid_filename() {
    local filename="$1"
    if [[ ! $- =~ e ]]; then
        set -e
        write_log_msg --std --level="$INFO" "Reasserting 'set -e'"
    fi

    # filename empty or has invalid characters
    if [[ -z "$filename" || ! "$filename" =~ ^[A-Za-z0-9._-]+$ ]]; then
        exit 1
    fi

    # reserved Windows device names (case-insensitive)
    shopt -s nocasematch
    case "$filename" in
    CON | PRN | AUX | NUL | COM[1-9] | LPT[1-9])
        shopt -u nocasematch
        exit 1
        ;;
    esac
    shopt -u nocasematch

    # Passed all checks
    return 0
}

function build_prep() {
    function niche_function() {
        (
            if [[ ! $- =~ e ]]; then
                set -e
                write_log_msg --std --level="$INFO" "Reasserting 'set -e'" 1>&2
            fi
            # keep the outside environment clean
            cross_build_env
            native_build_env
            case "$1" in
            --host)
                echo "${HOST_BUILD_DIR}"
                ;;
            --target)
                echo "${TGT_BUILD_DIR}"
                ;;
            *)
                echo "Not implemented"
                ;;
            esac
        )
    }

    if [[ ! $- =~ e ]]; then
        set -e
        write_log_msg --std --level="$INFO" "Reasserting 'set -e'"
    fi

    # Bitmask flags
    local nw=$((2#0001))   # no-wipe
    local hs=$((2#0010))   # host set
    local ts=$((2#0100))   # target set
    local hsts=$((2#0110)) # host/target set
    local ds=$((2#1000))   # directory set
    local no_wipe=false    # Wipe by default
    local num_args=$# status=0
    local err_level=-1 err_msg="" err_channel=("--std" "--err") exit_code=0

    status=$((status & 0xFF))

    if ((num_args < 2)); then
        err_level="$FATAL"
        err_msg="Missing required argument(s) for build_prep"
        set --
        # Now you're missing *all* of the arguments! Muhahahaha!
        exit_code=2
    elif ((num_args > 3)); then
        err_level="$WARN"
        err_msg="build_prep received extra arguments; ignoring extras.\narguments: $*"
    fi

    # loop through the arguments
    for arg in "$@"; do
        if [[ num_args -le 0 ]]; then
            err_level="$FATAL"
            err_msg="Internal error in build_prep: argument parsing went awry" >&2
            exit_code=47
        elif (((status == 2#1011) || (status == 2#1101))); then
            err_level="${WARN}"
            err_msg="Extra argument(s) to build_prep; ignoring extras.\narguments: $*"
        fi

        case $arg in
        --no-wipe)
            num_args=$((num_args - 1))

            if (((status & nw) == nw)); then
                err_level="${WARN}"
                err_msg="--no-wipe specified multiple times; ignoring extras."
            fi
            # I can't even... ('tis a joke... ${status} is an odd number when --no-wipe is set)

            no_wipe=true
            status=$((status | nw)) # set no-wipe flag
            ;;

        --host)
            num_args=$((num_args - 1))

            if (((status & hsts) == 0)); then
                destination="$(niche_function --host)"
                status=$((status | hs))
                err_level=0
            elif (((status & hsts) == hs)); then
                err_level="${WARN}"
                err_msg="Duplicate --host flag. Ignoring."
            elif (((status & hsts) == ts)); then
                err_level="${FATAL}"
                err_msg="--host and --target may not be specified together."
                exit_code=2#0010
            elif (((status & hsts) == hsts)); then
                err_level="${FATAL}"
                err_msg="Internal error in build_prep: conflicting host/target status."
                exit_code=2#0010
            fi
            ;;

        --target)
            num_args=$((num_args - 1))

            if (((status & hsts) == ts)); then
                err_level="${WARN}"
                err_msg="Duplicate --target flag. Ignoring."
            elif (((status & hsts) == hs)); then
                err_level="${FATAL}"
                err_msg="--host and --target may not be specified together."
                exit_code=2#0100
            elif (((status & hsts) == hsts)); then
                err_level="${FATAL}"
                err_msg="Internal error in build_prep: conflicting host/target status."
                exit_code=2#0100
            elif (((status & hsts) == 0)); then
                destination="$(niche_function --target)"
                status=$((status | ts))
            fi
            ;;

        --*)
            num_args=$((num_args - 1))

            err_level="${WARN}"
            err_msg="Invalid option: ${arg}. Ignoring."
            ;;

        *)
            num_args=$((num_args - 1))

            if ! is_valid_filename "${arg}"; then
                if ((num_args == 1)); then
                    # Ran out of arguments
                    err_level="${FATAL}"
                    err_msg="No valid directory name specified: ${arg}"
                    exit_code=3
                fi
            fi

            if (((status & ds) == ds)); then
                err_level="${WARN}"
                err_msg="Duplicate directory name argument. Ignoring."
            fi
            target_dir="${arg}"
            status=$((status | ds))
            ;;
        esac
    done

    status=$((status & 2#1111))
    # 0b1010, 0b1011, 0b1100b, and 0b1101 are all valid
    if (((status < 10) || (status > 13))); then
        err_level="${FATAL}"
        err_msg="Improper argument(s) for build_prep"
        exit_code=2
    fi

    if [[ -n $err_msg && err_level -ge 0 ]]; then
        local chan=0
        if [[ $err_level -ge $ERROR ]]; then
            chan=1
        fi
        write_log_msg --level="$err_level" --err "$err_msg" "${err_channel[chan]}"
    fi

    if ((exit_code != 0)); then
        #     echo "This is supposed to cause the program to end"
        exit ${exit_code}
    fi

    # All is well if this point is reached
    # echo "$destination $target_dir $no_wipe"
    local new_dir
    new_dir=${destination}/${target_dir}

    if [ "${new_dir}" != "$(niche_function --target)/${target_dir}" ] && [ "${new_dir}" != "$(niche_function --host)/${target_dir}" ]; then
        false # TODO: come up with something witty
        exit 99
    fi
    write_log_msg --level="$INFO" "Preparing build directory: ${new_dir}"
    # should be equivalent to "${TGT_BUILD_DIR}/${target_dir}" or "${HOST_BUILD_DIR}/${target_dir}"
    # tested above

    if [[ ${no_wipe} == false ]]; then
        write_log_msg --level="$DEBUG" "Preparing to delete: ${new_dir}"
        if ! rm -rf "${new_dir}"; then
            write_log_msg --err --level="$FATAL" "Failed to wipe build directory: ${new_dir}"
            exit 1
        else
            write_log_msg --level="$INFO" "Deleted: ${new_dir}"
        fi
    fi

    write_log_msg --level="$DEBUG" "Preparing to create: ${new_dir}"
    if ! mkdir -p "${new_dir}"; then
        write_log_msg --err --level="$FATAL" "Failed to create build directory: ${new_dir}"
        exit 1
    else
        write_log_msg --level="$INFO" "Created: ${new_dir}"
    fi

    cd "${new_dir}" || {
        write_log_msg --err --level="$FATAL" "Failed to change directory to build directory: ${new_dir}"
        exit 1
    }

    if should_log "${DEBUG}"; then
        local log_file="${LOG_DIR}/prep-${target_dir}-env-dump.log"
        write_log_msg --level="$DEBUG" "Dumping environment to log file: ${log_file}"
        echo -e "\n$(timestamp withdate)\n" | tee -a "$log_file" >/dev/null
        env | sort | grep -v '^BASH_FUNC_' | tee -a "$log_file" >/dev/null
        echo -e "\n\nNormal order because stupid reasons" | tee -a "${log_file}" >/dev/null
        env | tee -a "$log_file" >/dev/null
    
    fi

    echo "${PWD}"
    # Let's hope this works!
    return 0
}
