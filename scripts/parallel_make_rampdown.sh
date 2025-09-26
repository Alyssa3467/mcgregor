#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2120
parallel_make_rampdown() {
    local target=$1
    local attempt=1
    local jobs
    local label="${target:-default}"
    jobs=$(nproc)

    until make -j"$jobs" ${target:+$target} 2>&1 | tee "build_${label}_attempt_${attempt}.log"; do
        if grep -q "Segmentation fault" "build_${label}_attempt_${attempt}.log"; then
            echo "❌ Segmentation fault detected during $label build."
            echo "Switching immediately to sequential build."
            jobs=1
            continue
        fi

        echo "⚠️ Build target $target failed with $jobs jobs, retrying in 3 seconds..."
        sleep 3

        # back off parallelism
        jobs=$(((jobs * 3) / 4))
        if [ "$jobs" -lt 1 ]; then jobs=1; fi

        attempt=$((attempt + 1))
    done

    echo -e "\n✅ Qapla'"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        echo "ℹ️ No targets specified. Defaulting to 'make' with no target."
        set -- "" # Treat as one empty target
    fi

    while [[ $# -gt 0 ]]; do
        the_loop "$1"
        shift
    done
fi
