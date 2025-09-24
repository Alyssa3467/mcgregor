#!/bin/bash
set -e

# Build minimal cross GCC (stage 1)
mkdir -p "${BUILD_ROOT}/build-${ARCH}-gcc-stage1" && cd "${BUILD_ROOT}/build-${ARCH}-gcc-stage1"

"${SOURCE_ROOT}/gcc-15.2.0/configure" \
    --prefix="${XBIN_FOLDER}" \
    --target="${CCPREFIX}" \
    --with-sysroot="${SYSROOT}" \
    --enable-languages=c \
    --disable-multilib \
    --disable-shared \
    --disable-threads \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libvtv \
    --disable-nls

JOBS=$(nproc)
while ! (make -j"$JOBS" all-gcc); do
    echo "Attempting build with $JOBS jobs..."
    # Capture output to a log file
    if make -j"$JOBS" all-gcc 2>&1 | tee build.log; then
        break
    fi

    # Check for segmentation fault
    if grep -q "Segmentation fault" build.log; then
        echo "Segmentation fault detected during build. Aborting."
        exit 1
    fi

    echo "Build failed with $JOBS jobs, retrying in 3 seconds..."
    sleep 3
    JOBS=$(( JOBS / 2 ))
    if [ "$JOBS" -lt 1 ]; then
        JOBS=1
    fi
done

make install-gcc
