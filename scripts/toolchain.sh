#!/usr/bin/env -iS PATH=${HOME}/.local/bin:/usr/bin:/bin HOME="${HOME}" USER="${USER}" TERM=xterm-256color LC_ALL=C LANG=C bash

# shellcheck disable=SC2096,SC2317
# TODO: Convert to Makefile
set -eou pipefail

# Import Intel OneAPI environment variables
{
  saved=("$@")

  export OCL_ICD_FILENAMES="" TCM_ROOT=""

  # Clear positional parameters so setvars.sh sees nothing
  set --

  source /opt/intel/oneapi/setvars.sh

  set -- "${saved[@]}"
  unset saved
}

set -x

SCRIPT_DIR="$(
  if command -v readlink >/dev/null && readlink -f . >/dev/null 2>&1; then
    cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd
  else
    cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
  fi
)"

# ------------------- Process (some) Command Line Arguments ------------------ #
. "${SCRIPT_DIR}"/gcc-symlink-flags.sh "$@"

# Replace positional parameters with remaining args
# If REMAINING_ARGS is non-empty, restore them into $@
if [ -n "${REMAINING_ARGS:-}" ]; then
  # Use eval to split the space-separated string into proper arguments
  eval "set -- ${REMAINING_ARGS}"
else
  # No remaining args; clear positional parameters
  set --
fi
if [[ -v REMAINING_ARGS ]]; then
  unset REMAINING_ARGS # cleanup: prevent leakage
fi
# ---------------------------------------------------------------------------- #

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
unset CREATE_RPI_KERNEL_HEADERS

# ---------------------------------------------------------------------------- #
#                     Download the latest main Linux kernel                    #
#                Install Linux Kernel Headers Into $HOST_SYSROOT               #
# ---------------------------------------------------------------------------- #
. "${SCRIPT_DIR}"/host-kernel.sh

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
