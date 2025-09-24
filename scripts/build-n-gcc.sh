#!/usr/bin/bash

set -e

cd "${SOURCE_ROOT}/gcc-15.2.0"
ln -f -s ../mpfr-4.2.2 mpfr
ln -f -s ../gmp-6.3.0  gmp
ln -f -s ../mpc-1.3.1  mpc

# Build native gcc
mkdir -p "${BUILD_ROOT}/build-$(arch)-gcc" && cd "${BUILD_ROOT}/build-$(arch)-gcc"
"${SOURCE_ROOT}/gcc-15.2.0/configure" \
    --prefix="${NBIN_FOLDER}"\
    --disable-multilib \
    --enable-languages=c

JOBS=$(nproc)
while ! (make -j"$JOBS" bootstrap); do
    echo "Build failed with $JOBS jobs, retrying in 3 seconds..."
    sleep 3
    JOBS=$(( JOBS / 2 ))
    if [ "$JOBS" -lt 1 ]; then
        JOBS=1
    fi
done


make install-strip