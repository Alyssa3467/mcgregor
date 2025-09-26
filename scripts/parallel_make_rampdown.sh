#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2120
parallel_make_rampdown() {
    local target="${1:-}"
    local attempt=1
    local jobs tried
    local label="${target:-default}"
    jobs=$(nproc)

    while true; do
        echo "🔧 Attempt $attempt: make -j$jobs ${target:+$target}"
        if make -j"$jobs" ${target:+$target} 2>&1 | tee "build_${label}_attempt_${attempt}.log"; then
            echo "✅ Build succeeded on attempt $attempt with $jobs jobs"
            break
        elif grep -q "Segmentation fault" "build_${label}_attempt_${attempt}.log"; then
            echo "❌ Segmentation fault detected during $label build."
            echo "Switching immediately to sequential build."
            jobs=1
        else
            tried=$jobs
            jobs=$(((jobs * 3) / 4))
            if ((jobs < 1)); then jobs=1; fi
            echo "⚠️ Build target $target failed with $tried jobs, retrying with $jobs jobs in 3 seconds..."
            sleep 3
        fi

        attempt=$((attempt + 1))
    done

    echo -e "\n✅ Qapla'"
}
