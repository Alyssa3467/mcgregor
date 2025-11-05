#!/usr/bin/env bash
set -euo pipefail

# Detect if this file is being sourced or run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "⚠️  This script should be sourced, not executed." >&2
    exit 1
fi

# shellcheck disable=SC2034
{
    set -a

    KEYRING_DIR="${PROJECT_ROOT}/keys"
    KEYRING_FILE="${KEYRING_DIR}/project-keyring.gpg"
    GNUPGHOME="${KEYRING_DIR}"
    GPG_CONF_FILE="${KEYRING_DIR}/gpg.conf"
    GPG_LOG_FILE="${LOG_DIR}/gpg.log"

    set +a
}
echo "$(timestamp withdate) Begin GPG Logs" | tee -a "${GPG_LOG_FILE}"
mkdir -p "$KEYRING_DIR" "$LOG_DIR"
chmod 700 "$KEYRING_DIR"
cd "$KEYRING_DIR"
touch "$KEYRING_FILE"
chmod 600 "$KEYRING_FILE"

# Write gpg.conf fresh each time (It's within the project tree anyway)
cat >"$GPG_CONF_FILE" <<EOF
no-default-keyring
auto-key-locate wkd,keyserver,local
auto-key-import
auto-key-retrieve
keyserver-options honor-keyserver-url timeout=4
keyring $KEYRING_FILE
log-file $GPG_LOG_FILE
keyring ~/.gnupg/pubring.kbx
EOF

# Helper to check if a key is present
has_key() {
    gpg --no-default-keyring --keyring "$KEYRING_FILE" \
        --list-keys "$1" >/dev/null 2>&1
}