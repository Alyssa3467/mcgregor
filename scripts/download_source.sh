#!/bin/bash
set -ueo pipefail

if ! (return 0 2>/dev/null); then
    echo "This script must be sourced, not executed." >&2
    exit 1
fi

download_source() {
    local BADV6_FILE="${HOME}/.bad_ipv6_hosts"
    local normal_urls=()
    local ipv4_urls=()

    needs_ipv4() {
        local host="$1"
        grep -qx "$host" "$BADV6_FILE" 2>/dev/null
    }
    mark_bad_ipv6() {
        local host="$1"
        echo "$host" >>"$BADV6_FILE"
        sort -u -o "$BADV6_FILE" "$BADV6_FILE"
    }
    verify_with_keyring() {
        local homedir="$1"
        local keyring_opt=("${@:2}") # optional extra args like --keyring FILE
        if gpg "${keyring_opt[@]}" --homedir "$homedir" --verify "$sig" "$base" 2>/dev/null; then
            echo "✔️  Verified with ${label}"
            if [[ -n "$keyid" ]]; then
                echo "🔑 Signer information:"

                gpg "${keyring_opt[@]}" --homedir "$homedir" \
                    --list-keys --with-subkey-fingerprints "$keyid" |
                    awk '/^pub/ { print "    " $0; getline; print "    " $0} /^uid/ { sub(/\[\s+/, "[") sub(/uid[[:space:]]+/, "uid   "); print "    " $0; exit }'

                file_ts=$(stat -c %Y "$base")
                key_expiry=$(gpg --with-colons --list-keys "$keyid" | awk -F: '/^pub:/ {print $7; exit}')

                if [[ -n "$key_expiry" ]]; then
                    if [[ "$file_ts" -gt "$key_expiry" ]]; then
                        echo "⚠️  File $base is newer than the key's expiration date ($key_expiry)"
                        exit 1
                    elif [[ "$file_ts" -lt "$key_expiry" && "$(date +%s)" -gt "$key_expiry" ]]; then
                        echo "ℹ️  Key $keyid is currently expired, but it was valid when $base was signed."
                    fi
                fi
            fi
            return 0
        fi
        return 1
    }

    cd "${SOURCE_ROOT}"

    local GNU_mirror_host="https://ftpmirror.gnu.org/"
    local GNU_mirror_files=(
        "gcc/gcc-15.2.0/gcc-15.2.0.tar.gz"
        "gettext/gettext-0.26.tar.gz"
        "glibc/glibc-2.42.tar.gz"
        "gmp/gmp-6.3.0.tar.bz2"
        "mpc/mpc-1.3.1.tar.gz"
        "mpfr/mpfr-4.2.2.tar.bz2"
    )
    local otherDownloads=(
        "https://ftp.gnu.org/gnu/gnu-keyring.gpg"
        "https://gcc.gnu.org/pub/gcc/infrastructure/md5.sum"
        "https://gcc.gnu.org/pub/gcc/infrastructure/sha512.sum"
    )
    local GIT_repos=(
        "git://sourceware.org/git/binutils-gdb.git"
        "git://repo.or.cz/isl.git"
        "git@github.com:madler/zlib.git"
    )
    local GIT_refs=(
        "binutils-2_45"
        "isl-0.27"
        "master"
    )
    if [[ ${#GIT_repos[@]} -ne ${#GIT_refs[@]} ]]; then
        echo "❌ Repo and ref arrays are mismatched!" >&2
        exit 1
    fi

    local fname
    local -a downloads_list=()
    for i in $(for x in "${GNU_mirror_files[@]}"; do
        echo "${x}" "${x}.sig"
    done) "${otherDownloads[@]}"; do
        fname=$(basename "$i")
        if [[ -s "$fname" ]]; then
            echo "✔️  Already have $fname, skipping"
        elif [[ $i =~ ^https?:// ]]; then
            downloads_list+=("$i")
        else
            downloads_list+=("${GNU_mirror_host}${i}")
        fi
    done

    roll=$((($(od -An -N1 -tu1 /dev/urandom) % 4 + 1) + ($(od -An -N1 -tu1 /dev/urandom) % 4 + 1)))

    for url in "${downloads_list[@]}"; do
        host=$(printf '%s\n' "$url" | awk -F/ '{print $3}')
        if needs_ipv4 "$host"; then
            ipv4_urls+=("$url")
        else
            normal_urls+=("$url")
        fi
    done

    {
        if [[ ${#normal_urls[@]} -gt 0 ]]; then
            if ! curl --ipv4 \
                --continue-at - \
                --retry $((roll + roll)) \
                --retry-delay "$roll" \
                --parallel \
                --fail \
                --show-error \
                --location \
                --remote-time \
                --remote-name-all \
                --parallel-max "$roll" \
                "${normal_urls[@]}"; then
                # If it fails, retry each individually with IPv4 and mark bad hosts
                for url in "${normal_urls[@]}"; do
                    host=$(printf '%s\n' "$url" | awk -F/ '{print $3}')
                    if ! curl --remote-time --remote-name --fail --show-error --location "$url"; then
                        echo "❌ $host failed, retrying with IPv4..."
                        if curl --ipv4 --remote-time --remote-name --fail --show-error --location "$url"; then
                            mark_bad_ipv6 "$host"
                        else
                            echo "❌ Download failed for $url"
                            exit 1
                        fi
                    fi
                done
            fi
        fi

        if [[ ${#ipv4_urls[@]} -gt 0 ]]; then
            curl --ipv4 \
                --continue-at - \
                --retry $((roll + roll)) \
                --retry-delay "$roll" \
                --parallel \
                --fail \
                --show-error \
                --location \
                --remote-time \
                --remote-name-all \
                --parallel-max "$roll" \
                "${ipv4_urls[@]}"
        fi
    }

    for sig in *.sig; do
        base="${sig%.sig}"
        keyid=$(gpg --list-packets "$sig" | awk '/keyid/ {print $6; exit}')
        echo 
        echo "❓ Verifying: $base" | tee -a "${LOG_DIR}/download.log"

        label="local keyring"
        if verify_with_keyring "$HOME/.gnupg/"; then
            continue
        fi

        label="project keyring"
        if verify_with_keyring "${KEYRING_DIR}" --no-default-keyring --keyring "${KEYRING_FILE}"; then
            continue
        fi

        # Try fetching missing keys from common keyservers
        if [[ -n "$keyid" ]]; then
            echo "🌐 Attempting to fetch key $keyid from keyservers..."
            # Are you the keymaster?
            for ks in zuul.rediris.es gozer.rediris.es keys.openpgp.org keyserver.ubuntu.com pgp.mit.edu; do
                echo "$ks:"
                if gpg --keyserver-options timeout=47 --homedir "${KEYRING_DIR}" --keyserver "$ks" --recv-keys "$keyid"; then
                    label="key from $ks"
                    if verify_with_keyring "${KEYRING_DIR}"; then
                        # Export into project keyring
                        gpg --homedir "${KEYRING_DIR}" --export "$keyid" |
                            gpg --no-default-keyring --keyring "$KEYRING_FILE" --import
                        continue 2
                    fi
                fi
            done
        fi

        # Fallback: use the downloaded GNU keyring
        label="gnu-keyring.gpg (fallback)"
        if verify_with_keyring "${KEYRING_DIR}" --no-default-keyring --keyring ./gnu-keyring.gpg; then
            continue
        fi
        echo "❌ Signature check failed for $base"
        exit 1
    done
}

# run the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed." >&2
    exit 1
else
    download_source
fi
