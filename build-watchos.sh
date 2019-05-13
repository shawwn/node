#!/bin/sh
set -x

if [ `uname` == "Darwin" ]
then
  HOST_OS=linux
else
  HOST_OS=mac
fi

if [ ! -x ./Debug_torque ]
then
  set -x
  rm -f {Debug,Release}_*

  rm -rf out

  python configure.py --openssl-no-asm --without-intl --enable-static --verbose --debug
  cd out || exit $?
  make -j4 torque bytecode_builtins_list_generator || exit $?
  rsync -a Debug/obj.host/torque/ ../Debug_obj_host_torque/
  rsync -a Debug/obj.host/torque_base/ ../Debug_obj_host_torque_base/
  cp Debug/torque ../Debug_torque || exit $?
  cp Debug/bytecode_builtins_list_generator ../Debug_bytecode_builtins_list_generator || exit $?
  make -j4 torque bytecode_builtins_list_generator BUILDTYPE=Release || exit $?
  rsync -a Release/obj.host/torque/ ../Release_obj_host_torque/
  rsync -a Release/obj.host/torque_base/ ../Release_obj_host_torque_base/
  cp Release/torque ../Release_torque || exit $?
  cp Release/bytecode_builtins_list_generator ../Release_bytecode_builtins_list_generator || exit $?
  cd .. || exit $?

  rm -rf out
  set +x
fi

mkdir -p out/Debug/obj.host/torque
mkdir -p out/Release/obj.host/torque

rsync -a ./Debug_obj_host_torque/ ./out/Debug/obj.host/torque/ 
rsync -a ./Debug_obj_host_torque_base/ ./out/Debug/obj.host/torque_base/ 
cp Debug_torque out/Debug/torque || exit $?
cp Debug_bytecode_builtins_list_generator out/Debug/bytecode_builtins_list_generator || exit $?

rsync -a ./Release_obj_host_torque/ ./out/Release/obj.host/torque/ 
rsync -a ./Release_obj_host_torque_base/ ./out/Release/obj.host/torque_base/ 
cp Release_torque out/Release/torque || exit $?
cp Release_bytecode_builtins_list_generator out/Release/bytecode_builtins_list_generator || exit $?


#
# Build a fat binary for iOS

# Number of CPUs (for make -j)
NCPU=`sysctl -n hw.ncpu`
if test x$NJOB = x; then
    NJOB=$NCPU
fi

SRC_DIR=$(cd `dirname $0`; pwd)
if [ "$PWD" = "$SRC_DIR" ]; then
    PREFIX=$SRC_DIR/ios-build
    mkdir -p $PREFIX 
else
    PREFIX=$PWD
fi

BUILD_I386_IOSSIM=NO
BUILD_X86_64_IOSSIM=NO

BUILD_IOS_ARMV7=NO
BUILD_IOS_ARMV7S=NO
BUILD_IOS_ARM64=YES

# 13.4.0 - Mavericks
# 14.0.0 - Yosemite
# 15.0.0 - El Capitan
DARWIN=darwin15.0.0

XCODEDIR=`xcode-select --print-path`
IPHONEOS_SDK_VERSION=`xcrun --sdk iphoneos --show-sdk-version`
WATCHOS_SDK_VERSION=`xcrun --sdk watchos --show-sdk-version`
MIN_IPHONEOS_SDK_VERSION=8.0
MIN_WATCHOS_SDK_VERSION=5.1

IPHONEOS_PLATFORM=`xcrun --sdk iphoneos --show-sdk-platform-path`
IPHONEOS_SYSROOT=`xcrun --sdk iphoneos --show-sdk-path`
IPHONESIMULATOR_PLATFORM=`xcrun --sdk iphonesimulator --show-sdk-platform-path`
IPHONESIMULATOR_SYSROOT=`xcrun --sdk iphonesimulator --show-sdk-path`

WATCHOS_PLATFORM=`xcrun --sdk watchos --show-sdk-platform-path`
WATCHOS_SYSROOT=`xcrun --sdk watchos --show-sdk-path`
WATCHSIMULATOR_PLATFORM=`xcrun --sdk watchsimulator --show-sdk-platform-path`
WATCHSIMULATOR_SYSROOT=`xcrun --sdk watchsimulator --show-sdk-path`

# Uncomment if you want to see more information about each invocation
# of clang as the builds proceed.
CLANG_VERBOSE="${CLANG_VERBOSE:+--verbose}"

CC=gcc
CXX=g++

SILENCED_WARNINGS="-Wno-unused-local-typedef -Wno-unused-function"

CFLAGS="${CLANG_VERBOSE} ${SILENCED_WARNINGS} -DNDEBUG -g -O0"

set +x
echo "PREFIX ..................... ${PREFIX}"
echo "BUILD_MACOSX_X86_64 ........ ${BUILD_MACOSX_X86_64}"
echo "BUILD_I386_IOSSIM .......... ${BUILD_I386_IOSSIM}"
echo "BUILD_X86_64_IOSSIM ........ ${BUILD_X86_64_IOSSIM}"
echo "BUILD_IOS_ARMV7 ............ ${BUILD_IOS_ARMV7}"
echo "BUILD_IOS_ARMV7S ........... ${BUILD_IOS_ARMV7S}"
echo "BUILD_IOS_ARM64 ............ ${BUILD_IOS_ARM64}"
echo "DARWIN ..................... ${DARWIN}"
echo "XCODEDIR ................... ${XCODEDIR}"
echo "IPHONEOS_SDK_VERSION........ ${IPHONEOS_SDK_VERSION}"
echo "MIN_WATCHOS_SDK_VERSION .... ${MIN_WATCHOS_SDK_VERSION}"
echo "MIN_IPHONEOS_SDK_VERSION.... ${MIN_IPHONEOS_SDK_VERSION}"
echo "IPHONEOS_PLATFORM .......... ${IPHONEOS_PLATFORM}"
echo "IPHONEOS_SYSROOT ........... ${IPHONEOS_SYSROOT}"
echo "IPHONESIMULATOR_PLATFORM ... ${IPHONESIMULATOR_PLATFORM}"
echo "IPHONESIMULATOR_SYSROOT .... ${IPHONESIMULATOR_SYSROOT}"
echo "WATCHOS_PLATFORM ........... ${WATCHOS_PLATFORM}"
echo "WATCHOS_SYSROOT ............ ${WATCHOS_SYSROOT}"
echo "WATCHSIMULATOR_PLATFORM .... ${WATCHSIMULATOR_PLATFORM}"
echo "WATCHSIMULATOR_SYSROOT ..... ${WATCHSIMULATOR_SYSROOT}"
echo "CC ......................... ${CC}"
echo "CFLAGS ..................... ${CFLAGS}"
echo "CXX ........................ ${CXX}"
echo "CXXFLAGS ................... ${CXXFLAGS}"
echo "LDFLAGS .................... ${LDFLAGS}"
set -x

###################################################################
# This section contains the build commands for each of the 
# architectures that will be included in the universal binaries.
###################################################################

set -x

#DEFINES=" -D__arm__=1 -D__ARMEL__=1 -D__IPHONEOS__ -D__WATCHOS__ -DTARGET_OS_IPHONE=1 -DTARGET_OS_WATCH=1 -DV8_TARGET_OS_IPHONE=1 -DV8_TARGET_OS_IPHONE=1 -DWATCHOS_DEPLOYMENT_TARGET=$MIN_SDK_VERSION"
DEFINES=" -D__arm__=1 -D__ARMEL__=1 -DHAVE_FORK=0 -D__IPHONEOS__ -D__WATCHOS__ -DTARGET_OS_WATCH=1 -DV8_TARGET_OS_WATCH=1 -DCAN_USE_VFP3_INSTRUCTIONS=1"

IOS_FLAGS=" -mwatchos-version-min=$MIN_WATCHOS_SDK_VERSION -isysroot '${WATCHOS_SYSROOT}' "

IOS_BUILD_FLAGS=" -arch arm64_32 -target armv7k-apple-watchos5.1 "

CLANG_FLAGS=" -g -O0 ${CLANG_VERBOSE} "

CLANG_CPP_FLAGS=" -stdlib=libc++ -std=gnu++14 "
SNAPSHOT=" --without-snapshot "
#SNAPSHOT=

CLANG_FINAL=" ${CLANG_FLAGS} ${IOS_BUILD_FLAGS} ${IOS_FLAGS} ${DEFINES} "

GYP_DEFINES="target_arch=arm v8_target_arch=arm host_os=${HOST_OS} arm_fpu==vfpv3 " \
CC_host="clang -x c ${CLANG_FINAL} " \
CXX_host="g++ ${CLANG_CPP_FLAGS} ${CLANG_FINAL} " \
CC="${CC_host}" \
CXX="${CXX_host}" \
  python configure.py \
  --dest-os=mac \
  --dest-cpu=arm \
  $SNAPSHOT \
  --openssl-no-asm \
  --without-intl \
  --cross-compiling \
  --enable-static \
  --debug \
  --verbose \
  "$@" || exit $?

cd out || exit $?
make torque bytecode_builtins_list_generator || exit $?
cd .. || exit $?

mkdir -p out/Debug
mkdir -p out/Release

cp Debug_torque out/Debug/torque
cp Release_torque out/Release/torque
cp Debug_bytecode_builtins_list_generator out/Debug/bytecode_builtins_list_generator
cp Release_bytecode_builtins_list_generator out/Release/bytecode_builtins_list_generator

exec make -C out BUILDTYPE=Debug V=0 node "$@"
#exec make -j4 "$@"
