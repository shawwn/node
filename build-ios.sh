#!/bin/sh
set -x

if [ `uname` == "Darwin" ]
then
  HOST_OS=linux
else
  HOST_OS=mac
fi

if [ ! -x ./Release_torque ]
then
  set -x
  rm -f {Debug,Release}_{torque,bytecode_builtins_list_generator}

  rm -rf out

  python configure.py --openssl-no-asm --with-intl=full-icu --enable-static --verbose --debug
  cd out || exit $?
  #make -j4 torque bytecode_builtins_list_generator BUILDTYPE=Debug || exit $?
  #cp Debug/torque ../Debug_torque || exit $?
  #cp Debug/bytecode_builtins_list_generator ../Debug_bytecode_builtins_list_generator || exit $?
  make -j4 torque bytecode_builtins_list_generator BUILDTYPE=Release || exit $?
  cp Release/torque ../Release_torque || exit $?
  cp Release/bytecode_builtins_list_generator ../Release_bytecode_builtins_list_generator || exit $?
  cd .. || exit $?

  rm -rf out
  set +x
fi

mkdir -p out/Debug
mkdir -p out/Release

#cp Debug_torque out/Debug/torque || exit $?
#cp Debug_bytecode_builtins_list_generator out/Debug/bytecode_builtins_list_generator || exit $?
cp Release_torque out/Debug/torque || exit $?
cp Release_bytecode_builtins_list_generator out/Debug/bytecode_builtins_list_generator || exit $?
cp deps/icu/source/bin/* out/Debug/

cp Release_torque out/Release/torque || exit $?
cp Release_bytecode_builtins_list_generator out/Release/bytecode_builtins_list_generator || exit $?
cp deps/icu/source/bin/* out/Release/


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
IOS_SDK_VERSION=`xcrun --sdk iphoneos --show-sdk-version`
MIN_SDK_VERSION=8.0

IPHONEOS_PLATFORM=`xcrun --sdk iphoneos --show-sdk-platform-path`
IPHONEOS_SYSROOT=`xcrun --sdk iphoneos --show-sdk-path`

IPHONESIMULATOR_PLATFORM=`xcrun --sdk iphonesimulator --show-sdk-platform-path`
IPHONESIMULATOR_SYSROOT=`xcrun --sdk iphonesimulator --show-sdk-path`

# Uncomment if you want to see more information about each invocation
# of clang as the builds proceed.
CLANG_VERBOSE="${CLANG_VERBOSE:+--verbose}"

CC=gcc
CXX=g++

SILENCED_WARNINGS="-Wno-unused-local-typedef -Wno-unused-function"

CFLAGS="${CLANG_VERBOSE} ${SILENCED_WARNINGS} -g"

echo "PREFIX ..................... ${PREFIX}"
echo "BUILD_MACOSX_X86_64 ........ ${BUILD_MACOSX_X86_64}"
echo "BUILD_I386_IOSSIM .......... ${BUILD_I386_IOSSIM}"
echo "BUILD_X86_64_IOSSIM ........ ${BUILD_X86_64_IOSSIM}"
echo "BUILD_IOS_ARMV7 ............ ${BUILD_IOS_ARMV7}"
echo "BUILD_IOS_ARMV7S ........... ${BUILD_IOS_ARMV7S}"
echo "BUILD_IOS_ARM64 ............ ${BUILD_IOS_ARM64}"
echo "DARWIN ..................... ${DARWIN}"
echo "XCODEDIR ................... ${XCODEDIR}"
echo "IOS_SDK_VERSION ............ ${IOS_SDK_VERSION}"
echo "MIN_SDK_VERSION ............ ${MIN_SDK_VERSION}"
echo "IPHONEOS_PLATFORM .......... ${IPHONEOS_PLATFORM}"
echo "IPHONEOS_SYSROOT ........... ${IPHONEOS_SYSROOT}"
echo "IPHONESIMULATOR_PLATFORM ... ${IPHONESIMULATOR_PLATFORM}"
echo "IPHONESIMULATOR_SYSROOT .... ${IPHONESIMULATOR_SYSROOT}"
echo "CC ......................... ${CC}"
echo "CFLAGS ..................... ${CFLAGS}"
echo "CXX ........................ ${CXX}"
echo "CXXFLAGS ................... ${CXXFLAGS}"
echo "LDFLAGS .................... ${LDFLAGS}"

###################################################################
# This section contains the build commands for each of the 
# architectures that will be included in the universal binaries.
###################################################################

set -x

DEFINES=" -D__arm64__=1 -D__AARCH64EL__ -D_M_ARM64 -D__IPHONEOS__ -DTARGET_OS_IPHONE=1 -DV8_TARGET_OS_IPHONE=1 -DIPHONEOS_DEPLOYMENT_TARGET=$MIN_SDK_VERSION"

IOS_FLAGS=" -miphoneos-version-min=$MIN_SDK_VERSION -isysroot '${IPHONEOS_SYSROOT}' "

IOS_BUILD_FLAGS=" -m64 -arch arm64 -target arm64-apple-ios "

#RELEASE=${RELASE:-}
#
CLANG_FLAGS=" -g ${CLANG_VERBOSE} "
# 
# if [ -z $RELEASE ]
# then
#   #CLANG_FLAGS=" $CLANG_FLAGS -O0 "
# else
#   #CLANG_FLAGS=" $CLANG_FLAGS -O3 "
#   #DEFINES=" -DNDEBUG $DEFINES"
# fi

CLANG_CPP_FLAGS=" -stdlib=libc++ -std=c++17 "

SNAPSHOT=" --without-snapshot "
#SNAPSHOT=

CLANG_FINAL=" ${CLANG_FLAGS} ${IOS_BUILD_FLAGS} ${IOS_FLAGS} ${DEFINES} "

GYP_DEFINES="v8_enable_inspector=1 target_arch=arm64 v8_target_arch=arm64 host_os=${HOST_OS} " \
CC_host="clang -x c ${CLANG_FINAL} " \
CXX_host="g++ ${CLANG_CPP_FLAGS} ${CLANG_FINAL} " \
CC="${CC_host}" \
CXX="${CXX_host}" \
  python configure.py \
  --dest-os=mac \
  --dest-cpu=arm64 \
  $SNAPSHOT \
  --openssl-no-asm \
  --with-intl=full-icu \
  --cross-compiling \
  --enable-static \
  --debug \
  --verbose \
  "$@" || exit $?

cd out || exit $?
make -j4 torque bytecode_builtins_list_generator icutools BUILDTYPE=Release || exit $?
cd .. || exit $?

mkdir -p out/Debug
mkdir -p out/Release

#cp Debug_torque out/Debug/torque
#cp Debug_bytecode_builtins_list_generator out/Debug/bytecode_builtins_list_generator

cp Release_torque out/Debug/torque
cp Release_bytecode_builtins_list_generator out/Debug/bytecode_builtins_list_generator
cp deps/icu/source/bin/* out/Debug/

cp Release_torque out/Release/torque
cp Release_bytecode_builtins_list_generator out/Release/bytecode_builtins_list_generator
cp deps/icu/source/bin/* out/Release/

exec make -j4 -C out BUILDTYPE=Release V=0 node "$@"
#exec make -j4 "$@"
