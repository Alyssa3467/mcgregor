#!/usr/bin/env bash

# --- Required tools ---
REQUIRED_TOOLS=(awk bash curl file flock git gpg gpgv kill read seq shuf tar tput)

# Colors (fall back to no color if tput fails)
if tput setaf 1 >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RESET=$(tput sgr0)
else
    RED=""; GREEN=""; YELLOW=""; RESET=""
fi

echo "🔍 Checking required dependencies..."
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

if ((${#MISSING_TOOLS[@]} > 0)); then
    if ((${#MISSING_TOOLS[@]} == 1)); then
        echo "${RED}❌ The following required tool is missing:${RESET}"
    else
        echo "${RED}❌ The following required tools are missing:${RESET}"
    fi

    for tool in "${MISSING_TOOLS[@]}"; do
        echo "   - ${YELLOW}$tool${RESET}"
    done
    echo "🛠️  Please install them and re-run the script."
    exit 1
else
    echo "${GREEN}✅ All required tools are present.${RESET}"
fi