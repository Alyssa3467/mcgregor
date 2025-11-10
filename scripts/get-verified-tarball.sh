#!/bin/bash

if ! (return 0 2>/dev/null); then
    echo "This script must be sourced, not executed." >&2
    exit 1
fi

get_verified_tarball() {
    (
        set_window_title "Linux kernel source"
        write_log_msg "Downloading Linux kernel source"
        GPGBIN=$(command -v gpg)
        GPGVBIN=$(command -v gpgv)
        SHA256SUMBIN=$(command -v sha256sum)
        CURLBIN=$(command -v curl)
        GZIPBIN=$(command -v gzip)

        DEVKEYS=("torvalds@kernel.org" "gregkh@kernel.org")
        SHAKEYS=("autosigner@kernel.org")

        VER=$(${CURLBIN} -sL https://www.kernel.org/finger_banner |
            grep 'latest stable version' |
            awk -F: '{gsub(/ /,"", $0); print $2}')

        if [[ -z ${VER} ]]; then
            echo "Could not figure out the latest stable version."
            exit 1
        fi

        MAJOR="$(echo "${VER}" | cut -d. -f1)"

        if [[ ! -d ${SOURCE_ROOT} ]]; then
            echo "${SOURCE_ROOT} does not exist"
            exit 1
        fi

        TARGET="${SOURCE_ROOT}/linux-${VER}.tar.gz"
        if [[ -f ${TARGET} ]]; then
            echo "✔️  Already have linux-${VER}.tar.gz, skipping download"
            exit 0
        fi

        if [[ ! -x ${GPGBIN} ]]; then
            echo "Could not find gpg in ${GPGBIN}"
            exit 1
        fi
        if [[ ! -x ${GPGVBIN} ]]; then
            echo "Could not find gpgv in ${GPGVBIN}"
            exit 1
        fi

        # shellcheck disable=SC2174
        mkdir -p -m 0700 "${KEYRING_DIR}"
        echo "Making sure we have all the necessary keys"
        if ! "${GPGBIN}" --batch \
            --homedir "${KEYRING_DIR}" \
            --auto-key-locate wkd \
            --locate-keys "${DEVKEYS[@]}" "${SHAKEYS[@]}"; then
            echo "Something went wrong fetching keys" >&2
            exit 1
        fi
        SHAKEYRING=${TMPDIR}/shakeyring.gpg
        ${GPGBIN} --batch \
            --no-default-keyring --keyring "${KEYRING_FILE}" \
            --export "${SHAKEYS[@]}" >"${SHAKEYRING}"
        DEVKEYRING=${TMPDIR}/devkeyring.gpg
        ${GPGBIN} --batch \
            --no-default-keyring --keyring "${KEYRING_FILE}" \
            --export "${DEVKEYS[@]}" >"${DEVKEYRING}"

        # Now that we know we can verify them, grab the contents
        TGZ="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${VER}.tar.gz"
        SIG="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${VER}.tar.sign"
        SHA="https://www.kernel.org/pub/linux/kernel/v${MAJOR}.x/sha256sums.asc"

        SHAFILE=${TMPDIR}/sha256sums.asc
        echo "Downloading the checksums file for linux-${VER}"
        if ! ${CURLBIN} -sL -o "${SHAFILE}" "${SHA}"; then
            echo "Failed to download the checksums file"
            exit 1
        fi
        echo "Verifying the checksums file"
        COUNT=$(${GPGVBIN} --keyring="${SHAKEYRING}" --status-fd=1 "${SHAFILE}" |
            grep -c -E '^\[GNUPG:\] (GOODSIG|VALIDSIG)')
        if [[ ${COUNT} -lt 2 ]]; then
            echo "FAILED to verify the sha256sums.asc file."
            exit 1
        fi
        SHACHECK=${TMPDIR}/sha256sums.txt
        grep "linux-${VER}.tar.gz" "${SHAFILE}" >"${SHACHECK}"

        echo
        echo "Downloading the signature file for linux-${VER}"
        SIGFILE=${TMPDIR}/linux-${VER}.tar.asc
        if ! ${CURLBIN} -sL -o "${SIGFILE}" "${SIG}"; then
            echo "Failed to download the signature file"
            exit 1
        fi
        echo "Downloading the GZ tarball for linux-${VER}"
        TGZFILE=${TMPDIR}/linux-${VER}.tar.gz
        if ! ${CURLBIN} -L -o "${TGZFILE}" "${TGZ}"; then
            echo "Failed to download the tarball"
            exit 1
        fi

        pushd "${TMPDIR}" >/dev/null || exit 1
        echo "Verifying checksum on linux-${VER}.tar.gz"
        if ! ${SHA256SUMBIN} -c "${SHACHECK}"; then
            echo "FAILED to verify the downloaded tarball checksum"
            popd >/dev/null || exit 1
            exit 1
        fi
        popd >/dev/null || exit 1

        echo
        echo "Verifying developer signature on the tarball"
        COUNT=$(${GZIPBIN} -cd "${TGZFILE}" |
            ${GPGVBIN} --keyring="${DEVKEYRING}" --status-fd=1 "${SIGFILE}" - |
            grep -c -E '^\[GNUPG:\] (GOODSIG|VALIDSIG)')
        if [[ ${COUNT} -lt 2 ]]; then
            echo "FAILED to verify the tarball!"
            exit 1
        fi
        mv -f "${TGZFILE}" "${TARGET}"
        echo
        echo "Successfully downloaded and verified ${TARGET}"
        write_log_msg "Linux kernel source downloaded and verified"
    )
}

# run the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This file is being executed directly
    echo "⚠️ This script should be sourced, not executed." >&2
    exit 1
else
    get_verified_tarball
fi
