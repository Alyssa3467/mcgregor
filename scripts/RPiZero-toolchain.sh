#!/usr/bin/env -S PATH=/usr/bin:/bin HOME="${HOME}" USER="${USER}" TERM=xterm-256color LC_ALL=C LANG=C bash

set -ETueox pipefail

# set SCRIPT_DIR to the directory the script is in
SCRIPT_DIR="$(
  if command -v readlink >/dev/null && readlink -f . >/dev/null 2>&1; then
    cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd
  else
    cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
  fi
)"
echo ${SCRIPT_DIR}

# ------------------- Process (some) Command Line Arguments ------------------ #
# Sets flags for which gcc symlinks to use
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

. ${SCRIPT_DIR}/env.sh

mkdir -p ${SOURCE_ROOT}
cd ${SOURCE_ROOT}

# git clone git@github.com:raspberrypi/linux

curl -4 -L -Z -o gnu-keyring.gpg https://mirrors.ocf.berkeley.edu/gnu/gnu-keyring.gpg
gpg --import gnu-keyring.gpg

# musl libc Signing Key
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys \
  836489290BB6B70F99FFDA0556BCDB593020450F

exts={.tar.xz,.tar.xz.sig}
pkgs={binutils/binutils-2.47,\
gcc/gcc-16.1.0/gcc-16.1.0,\
mpfr/mpfr-4.2.2,\
gmp/gmp-6.3.0,\
mpc/mpc-1.4.1}
curl -4 -L -Z --remote-name-all https://mirrors.ocf.berkeley.edu/gnu/"$pkgs""$exts"
curl -L -Z --remote-name-all https://musl.libc.org/releases/musl-1.2.6.tar.gz \
https://musl.libc.org/releases/musl-1.2.6.tar.gz.asc


for sig in *.sig *.asc; do
    # Extract the matching archive name by removing the extension
    archive="${sig%.*}"
    
    echo "=============================================="
    echo "Checking: $archive"
    echo "=============================================="
    
    # Run the GPG verification check
    gpg --keyserver hkps://keyserver.ubuntu.com --keyserver-options auto-key-retrieve --verify "$sig" "$archive"
done

for archive in *.tar.?z; do
    tar -xf $archive
done

mkdir -p ${HOST_BUILD}/binutils
cd ${HOST_BUILD}/binutils
${SOURCE_ROOT}/binutils-*/configure --prefix="${HOST_INSTALL}" --disable-nls --disable-werror --disable-multilib
make
make install