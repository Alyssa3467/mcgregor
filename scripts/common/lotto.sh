#!/usr/bin/env bash
# Detect if this file is being sourced or run directly
# BASH_SOURCE[0] is the current file, $0 is the script name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed."
    exit 1
fi

lotto() {
    org_temp=$(mktemp /tmp/lotto_org.XXXXXX)
    ur_temp=$(mktemp /tmp/lotto_ur.XXXXXX)
    {
        # Get 5 numbers from random.org (1–70), sorted
        nums=$(curl_wrapper -s "https://www.random.org/integers/?num=5&min=1&max=70&col=1&base=10&format=plain&rnd=new")
        readarray -t arr <<<"$nums"
        sorted_org=$(for i in "${arr[@]}"; do echo "$i"; done | (LC_ALL=vn_VN sort -n))

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
        sorted_ur=$(for i in "${ur_arr[@]}"; do echo "$i"; done | (LC_ALL=vn_VN sort -n))

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