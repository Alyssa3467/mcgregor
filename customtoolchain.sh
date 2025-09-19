#!/bin/sh

# Set up environment, maybe
if [ -f ".env" ]; then
    source .env
fi

# PROJECTROOT must be set externally before running this script.
# This is to avoid pushing internal information to a public git repo.
if [ -z "${PROJECTROOT}" ]; then
    echo "\$PROJECTROOT not set."
    exit 1
fi

set -eu

export ARCH=arm
export CCPREFIX=arm-linux-gnueabihf
export CROSS_COMPILE=${CCPREFIX}-
export NBIN_FOLDER="${PROJECTROOT}/openwrt-toolchain-native"
export XBIN_FOLDER="${PROJECTROOT}/openwrt-toolchain-${ARCH}"
export SYSROOT="${PROJECTROOT}/raspberrypi/sysroot"
export SOURCEROOT="${PROJECTROOT}/openwrt-toolchain-src"
export BUILDROOT="${PROJECTROOT}/openwrt-toolchain-build"
export KERNEL=kernel # following the example from https://www.raspberrypi.com/documentation/computers/linux_kernel.html#cross-compile-the-kernel


if [ ! -d "${PROJECTROOT}" ]; then
    echo "${PROJECTROOT} does not exist"
    exit 1
fi

mkdir -p "${PROJECTROOT}/raspberrypi"
mkdir -p "${SOURCEROOT}"

cd ${SOURCEROOT}
[ -f binutils-*.tar.bz2 ] || wget https://ftpmirror.gnu.org/binutils/binutils-2.45.tar.bz2
[ -f gcc-*.tar.gz ]       || wget https://ftpmirror.gnu.org/gcc/gcc-15.2.0/gcc-15.2.0.tar.gz
[ -f mpfr-*.tar.bz2 ]     || wget https://ftpmirror.gnu.org/mpfr/mpfr-4.2.2.tar.bz2
[ -f gmp-*.tar.bz2 ]      || wget https://ftpmirror.gnu.org/gmp/gmp-6.3.0.tar.bz2
[ -f mpc-*.tar.gz  ]      || wget https://ftpmirror.gnu.org/mpc/mpc-1.3.1.tar.gz
[ -f glibc-*.tar.gz ]     || wget https://ftpmirror.gnu.org/gnu/glibc/glibc-2.42.tar.bz2

cd ${PROJECTROOT}/raspberrypi
[ -d ./linux ] || git clone git@github.com:raspberrypi/linux ${PROJECTROOT}/raspberrypi/linux

cd ${PROJECTROOT}/raspberrypi/linux
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} bcmrpi_defconfig
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} zImage modules dtbs | tee ${PROJECTROOT}/build.log
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} INSTALL_HDR_PATH=${SYSROOT} headers_install

mkdir -p ${BUILDROOT}/build-binutils && cd ${BUILDROOT}/build-binutils
tar -xvf ${SOURCEROOT}/binutils-2.45.tar.bz2
cd binutils-2.45
./configure --target=${CCPREFIX} --prefix=${XBIN_FOLDER} --with-sysroot=${SYSROOT} --disable-multilib
make -j$(nproc)
make install

cd ${SOURCEROOT}
tar -xvf mpfr-4.2.2.tar.bz2
tar -xvf gmp-6.3.0.tar.bz2
tar -xvf mpc-1.3.1.tar.gz
tar -xvf gcc-15.2.0.tar.gz
cd gcc-15.2.0
ln -s ../mpfr-4.2.2 mpfr
ln -s ../gmp-6.3.0  gmp
ln -s ../mpc-1.3.1  mpc
mkdir -p ${BUILDROOT}/build-gcc && cd ${BUILDROOT}/build-gcc
${SOURCEROOT}/gcc-15.2.0/configure --target=${CCPREFIX} --prefix=${XBIN_FOLDER} --with-sysroot=${SYSROOT} \
    --enable-languages=c --disable-multilib --without-headers --disable-bootstrap
make all-gcc -j$(nproc)
make install-gcc

cd ${SOURCEROOT}
tar -xvf ${SOURCEROOT}/glibc-2.42.tar.bz2
mkdir -p ${BUILDROOT}/build-glibc && cd ${BUILDROOT}/build-glibc
${SOURCEROOT}/glibc-2.42/configure \
    --build=${uname -m}-linux-gnu \
    --host=${CCPREFIX} \
    --with-sysroot=${SYSROOT} \
    --with-headers=${SYSROOT}/usr/include \
    --prefix=/usr \
    --enable-kernel=3.2 \
    --disable-multilib
make install-bootstrap-headers=yes install-headers cross-compiling=yes
make -j$(nproc) csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o ${SYSROOT}/usr/lib
${CCPREFIX}gcc -nostdlib -nostartfiles -shared -x c /dev/null -o ${SYSROOT}/usr/lib/libc.so
touch ${SYSROOT}/usr/include/gnu/stubs.h

mkdir -p ${BUILDROOT}/build-gcc-stage2 && cd ${BUILDROOT}/build-gcc-stage2
${SOURCEROOT}/gcc-15.2.0/configure \
    --target=${CCPREFIX} \
    --prefix=${XBIN_FOLDER} \
    --with-sysroot=${SYSROOT} \
    --enable-languages=c,c++ \
    --disable-multilib \
    --disable-bootstrap \
    --enable-shared \
    --enable-threads=posix \
    --enable-__cxa_atexit \
    --with-headers=${SYSROOT}/usr/include

make -j$(nproc)
make install