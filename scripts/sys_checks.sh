#!/usr/bin/env bash

# --- Required tools ---
REQUIRED_TOOLS=(awk bash curl file git gpg gpgv kill read seq shuf tar tput)

echo "🔍 Checking required dependencies..."
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

if ((${#MISSING_TOOLS[@]} > 0)); then
    if ((${#MISSING_TOOLS[@]} == 1)); then
        echo "❌ The following required tool is missing:"
    else
        echo "❌ The following required tools are missing:"
    fi

    for tool in "${MISSING_TOOLS[@]}"; do
        echo "   - $tool"
    done
    echo "🛠️ Please install them and re-run the script."
    return 1
fi