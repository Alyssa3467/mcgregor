#!/usr/bin/env -iS PATH=/usr/bin:/bin HOME="${HOME}" USER="${USER}" TERM=xterm-256color LANG=C bash

# shellcheck disable=2096
# TODO: Convert to Makefile
set -Eueo pipefail

SCRIPT_DIR="$(
  if command -v readlink >/dev/null && readlink -f . >/dev/null 2>&1; then
    cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd
  else
    cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
  fi
)"

. "${SCRIPT_DIR}"/gcc-symlink-flags.sh "$@"

# Replace positional parameters with remaining args
# If REMAINING_ARGS is empty, this sets an empty positional list
if [[ -n "${REMAINING_ARGS:-}" ]]; then
  eval "set -- ${REMAINING_ARGS}"
else
  set --
fi

# ---------------------------------------------------------------------------- #
#                              Ancillary Functions                             #
# ---------------------------------------------------------------------------- #
. "${SCRIPT_DIR}"/ancillary.sh

# ---------------------------------------------------------------------------- #
#                      Set Up Build Environment Parameters                     #
# ---------------------------------------------------------------------------- #
. "${SCRIPT_DIR}"/env.sh

# ---------------------------------------------------------------------------- #
#                     Clone Raspberry Pi Linux Kernel repo                     #
#               Install Raspberry Pi Headers Into $TARGET_SYSROOT              #
# ---------------------------------------------------------------------------- #
export CREATE_RPI_KERNEL_HEADERS="yes"
. "${SCRIPT_DIR}"/rpi-kernel.sh

# ---------------------------------------------------------------------------- #
#                     Download the latest main Linux kernel                    #
#                Install Linux Kernel Headers Into $HOST_SYSROOT               #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
#                             Download source files                            #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
#                             Extract source files                             #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
#                              Build native tools                              #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
#                              Build Target Tools                              #
# ---------------------------------------------------------------------------- #
