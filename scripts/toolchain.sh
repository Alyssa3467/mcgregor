#!/usr/bin/env -iS PATH=/usr/bin:/bin HOME="${HOME}" USER="${USER}" TERM=xterm-256color LANG=C bash

# shellcheck disable=2096
# TODO: Convert to Makefile
set -ueox pipefail
export LOG_LEVEL=0

# open FD 3 to a line-unbuffered consumer that wraps each line in cyan
exec 3> >(sed -u $'s/.*/\033[36m&\033[0m/')

export BASH_XTRACEFD=3

_cleanup_xtrace() {
  exec 3>&- || true
}
trap _cleanup_xtrace EXIT


SCRIPT_DIR="$(
    if command -v readlink >/dev/null && readlink -f . >/dev/null 2>&1; then
        cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd
    else
        cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
    fi
)"

# ---------------------------------------------------------------------------- #
#                Set up additional build environment parameters                #
# ---------------------------------------------------------------------------- #
. "${SCRIPT_DIR}"/env.sh
. "${SCRIPT_DIR}"/logging.sh
. "${SCRIPT_DIR}"/ancillary.sh
. "${SCRIPT_DIR}"/gpg_settings.sh
. "${SCRIPT_DIR}"/pre-build.sh # functions to set up a build environment

# ---------------------------------------------------------------------------- #
#                     Clone Raspberry Pi Linux Kernel repo                     #
#                Install Raspberry Pi headers into $TGT_SYSROOT                #
# ---------------------------------------------------------------------------- #
. "${SCRIPT_DIR}"/rpi.sh

# ---------------------------------------------------------------------------- #
#                     Download the latest main Linux kernel                    #
# ---------------------------------------------------------------------------- #
. "${SCRIPT_DIR}"/get-verified-tarball.sh

# ---------------------------------------------------------------------------- #
#      Extract Linux kernel tarball and install headers into $HOST_SYSROOT     #
# ---------------------------------------------------------------------------- #
. "${SCRIPT_DIR}"/host.sh

# ---------------------------------------------------------------------------- #
#                             Download source files                            #
# ---------------------------------------------------------------------------- #
. "${SCRIPT_DIR}"/download_source.sh

# ---------------------------------------------------------------------------- #
#                             Extract source files                             #
# ---------------------------------------------------------------------------- #
. "${SCRIPT_DIR}"/extract_source.sh

# ---------------------------------------------------------------------------- #
#                              Build native tools                              #
# ---------------------------------------------------------------------------- #
. "${SCRIPT_DIR}"/build_native.sh

#(maybe put all of these into one file like with the native tools?)
# ---------------------------------------------------------------------------- #
#                             Build target binutils                            #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
#                           Build target GCC, Stage 1                          #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
#                          Build target glibc, Stage 1                         #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
#                           Build target GCC, Stage 2                          #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
#                          Build target glibc, Stage 2                         #
# ---------------------------------------------------------------------------- #
