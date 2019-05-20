#!/bin/bash
set -x

if [ `uname` == "Darwin" ]
then
  HOST_OS=linux
else
  HOST_OS=mac
fi

#
# Build a fat binary for iOS

# Number of CPUs (for make -j)
NCPU=`sysctl -n hw.ncpu`
if test x$NJOB = x; then
    NJOB=$NCPU
fi

SRC_DIR="$(cd "$(dirname "$0")/.."; pwd)"
#if [ "$PWD" = "$SRC_DIR" ]; then
    #PREFIX=$SRC_DIR/node-ios-build
    #mkdir -p $PREFIX
#else
    #PREFIX=$PWD
#fi

# if [ ! -x ./Release_torque ]
# then
#   set -x
#   rm -f {Debug,Release}_{torque,bytecode_builtins_list_generator}
# 
#   rm -rf out
# 
#   python configure.py --openssl-no-asm --with-intl=full-icu --enable-static --verbose --debug
#   cd out || exit $?
#   #make -j4 torque bytecode_builtins_list_generator BUILDTYPE=Debug || exit $?
#   #cp Debug/torque ../Debug_torque || exit $?
#   #cp Debug/bytecode_builtins_list_generator ../Debug_bytecode_builtins_list_generator || exit $?
#   make -j4 torque bytecode_builtins_list_generator BUILDTYPE=Release || exit $?
#   cp Release/torque ../Release_torque || exit $?
#   cp Release/bytecode_builtins_list_generator ../Release_bytecode_builtins_list_generator || exit $?
#   cd .. || exit $?
# 
#   rm -rf out
#   set +x
# fi

function copy_artifacts () {
  set +e

  mkdir -p artifacts
  cd artifacts
  if [ ! -d node-ios-artifacts ]
  then
    git clone https://github.com/shawwn/node-ios-artifacts || exit $?
  fi

  set -e
  if [ ! -d node-ios-artifacts/deps ]
  then
    cd node-ios-artifacts
    tar xvf deps_icu.tar.gz
    cd ..
  fi
  if [ ! -d node-ios-artifacts/bin ]
  then
    cd node-ios-artifacts
    tar xvf bin.tar.gz
    cd ..
  fi
  cd ..

  rsync -Pa artifacts/node-ios-artifacts/deps/icu/ deps/icu/
  mkdir -p out/Debug
  mkdir -p out/Release
  cp artifacts/node-ios-artifacts/bin/* out/Debug
  cp artifacts/node-ios-artifacts/bin/* out/Release
  cp deps/icu/source/bin/* out/Debug/
  cp deps/icu/source/bin/* out/Release/
}
copy_artifacts

BUILD_I386_IOSSIM=NO
BUILD_X86_64_IOSSIM=YES

BUILD_IOS_ARMV7=NO
BUILD_IOS_ARMV7S=NO
BUILD_IOS_ARM64=NO

# 13.4.0 - Mavericks
# 14.0.0 - Yosemite
# 15.0.0 - El Capitan
DARWIN=darwin15.0.0

XCODEDIR=`xcode-select --print-path`
IOS_SDK_VERSION=`xcrun --sdk iphoneos --show-sdk-version`
MIN_SDK_VERSION=9.0

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
set -e

if [ "${BUILD_IOS_ARM64}" == "YES" ]
then

DEFINES=" -D__arm64__=1 -D__AARCH64EL__ -D_M_ARM64 -D__IPHONEOS__ -DTARGET_OS_IPHONE=1 -DV8_TARGET_OS_IPHONE=1 -DIPHONEOS_DEPLOYMENT_TARGET=$MIN_SDK_VERSION"

IOS_FLAGS=" -miphoneos-version-min=$MIN_SDK_VERSION -isysroot '${IPHONEOS_SYSROOT}' "

IOS_BUILD_FLAGS=" -m64 -arch arm64 -target arm64-apple-ios -fembed-bitcode "

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

CLANG_FINAL=" ${CLANG_FLAGS} ${IOS_BUILD_FLAGS} ${IOS_FLAGS} ${DEFINES} "

GYP_DEFINES="v8_enable_inspector=1 target_arch=arm64 v8_target_arch=arm64 host_os=${HOST_OS} " \
CC_host="clang -x c ${CLANG_FINAL} " \
CXX_host="g++ ${CLANG_CPP_FLAGS} ${CLANG_FINAL} " \
CC="${CC_host}" \
CXX="${CXX_host}" \
  python configure.py \
  --dest-os=mac \
  --dest-cpu=arm64 \
  --without-snapshot \
  --openssl-no-asm \
  --with-intl=full-icu \
  --cross-compiling \
  --enable-static \
  --debug \
  --verbose \
  "$@"

cd out
make -j4 torque bytecode_builtins_list_generator icutools BUILDTYPE=Release
cd ..

copy_artifacts

# build will fail once due to host / target platform mismatch
set +e
make -j4 -C out BUILDTYPE=Release V=1 node "$@"
set -e
# copy artifacts for host platform and try again
copy_artifacts
make -j4 -C out BUILDTYPE=Release V=1 node "$@"

fi

if [ "${BUILD_X86_64_IOSSIM}" == "YES" ]
then

DEFINES=" -D__x86_64__=1 -D_M_X64 -D__IPHONEOS__ -DTARGET_OS_IPHONE=1 -DV8_TARGET_OS_IPHONE=1 -DIPHONEOS_DEPLOYMENT_TARGET=$MIN_SDK_VERSION"

IOS_FLAGS=" -mios-simulator-version-min=$MIN_SDK_VERSION -isysroot '${IPHONESIMULATOR_SYSROOT}' "

IOS_BUILD_FLAGS=" -m64 -arch x86_64 -target x86_64-apple-ios -fembed-bitcode "

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

CLANG_FINAL=" ${CLANG_FLAGS} ${IOS_BUILD_FLAGS} ${IOS_FLAGS} ${DEFINES} "

GYP_DEFINES="v8_enable_inspector=1 target_arch=x64 v8_target_arch=x64 host_os=${HOST_OS} " \
CC_host="clang -x c ${CLANG_FINAL} " \
CXX_host="g++ ${CLANG_CPP_FLAGS} ${CLANG_FINAL} " \
CC="${CC_host}" \
CXX="${CXX_host}" \
  python configure.py \
  --dest-os=mac \
  --dest-cpu=x64 \
  --without-snapshot \
  --openssl-no-asm \
  --with-intl=full-icu \
  --cross-compiling \
  --enable-static \
  --debug \
  --verbose \
  "$@"

cd out
make -j4 torque bytecode_builtins_list_generator icutools BUILDTYPE=Release V=1
cd ..

copy_artifacts

# build will fail once due to host / target platform mismatch
#      /opt/sweet/node/out/Release/obj.target/icuucx/deps/icu/source/common/utrace.o /opt/sweet/node/out/Release/obj.target/icuucx/deps/icu/source/common/brkiter.o
#       LD_LIBRARY_PATH=/opt/sweet/node/out/Release/lib.host:/opt/sweet/node/out/Release/lib.target:$LD_LIBRARY_PATH; export LD_LIBRARY_PATH; cd ../tools/icu; mkdir -p /opt/sweet/node/out/Release/obj/gen; "/opt/sweet/node/out/Release/icupkg" -tl ../../deps/icu/source/data/in/icudt63l.dat "/opt/sweet/node/out/Release/obj/gen/icudt63l.dat"
#       clang -x c   -g    -m64 -arch x86_64 -target x86_64-apple-ios -fembed-bitcode   -mios-simulator-version-min=9.0 -isysroot '/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator12.1.sdk'   -D__x86_64__=1 -D_M_X64 -D__IPHONEOS__ -DTARGET_OS_IPHONE=1 -DV8_TARGET_OS_IPHONE=1 -DIPHONEOS_DEPLOYMENT_TARGET=9.0   -o /opt/sweet/node/out/Release/obj.target/openssl-cli/deps/openssl/openssl/apps/asn1pars.o ../deps/openssl/openssl/apps/asn1pars.c '-DV8_DEPRECATION_WARNINGS' '-DV8_IMMINENT_DEPRECATION_WARNINGS' '-D_DARWIN_USE_64_BIT_INODE=1' '-D__x86_64__=1' '-D_M_X64' '-D__IPHONEOS__' '-DTARGET_OS_IPHONE=1' '-DV8_TARGET_OS_IPHONE=1' '-DIPHONEOS_DEPLOYMENT_TARGET=9.0' '-DOPENSSL_THREADS' '-DOPENSSL_NO_ASM' '-DNDEBUG' '-DL_ENDIAN' '-DOPENSSL_PIC' '-DOPENSSLDIR="/System/Library/OpenSSL/"' '-DENGINESDIR="/dev/null"' -I../deps/openssl/openssl -I../deps/openssl/openssl/include -I../deps/openssl/openssl/crypto -I../deps/openssl/openssl/crypto/include -I../deps/openssl/openssl/crypto/modes -I../deps/openssl/openssl/crypto/ec/curve448 -I../deps/openssl/openssl/crypto/ec/curve448/arch_32 -I../deps/openssl/config -I../deps/openssl/config/archs/darwin64-x86_64-cc/no-asm/include -I../deps/openssl/openssl/include  -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator12.1.sdk -Os -gdwarf-2 -arch x86_64 -Wall -Wendif-labels -W -Wno-unused-parameter -Wno-missing-field-initializers -g -fno-strict-aliasing -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator12.1.sdk -mios-simulator-version-min=9.0 -fembed-bitcode -MMD -MF /opt/sweet/node/out/Release/.deps//opt/sweet/node/out/Release/obj.target/openssl-cli/deps/openssl/openssl/apps/asn1pars.o.d.raw   -c
#       clang -x c   -g    -m64 -arch x86_64 -target x86_64-apple-ios -fembed-bitcode   -mios-simulator-version-min=9.0 -isysroot '/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator12.1.sdk'   -D__x86_64__=1 -D_M_X64 -D__IPHONEOS__ -DTARGET_OS_IPHONE=1 -DV8_TARGET_OS_IPHONE=1 -DIPHONEOS_DEPLOYMENT_TARGET=9.0   -o /opt/sweet/node/out/Release/obj.target/openssl-cli/deps/openssl/openssl/apps/ca.o ../deps/openssl/openssl/apps/ca.c '-DV8_DEPRECATION_WARNINGS' '-DV8_IMMINENT_DEPRECATION_WARNINGS' '-D_DARWIN_USE_64_BIT_INODE=1' '-D__x86_64__=1' '-D_M_X64' '-D__IPHONEOS__' '-DTARGET_OS_IPHONE=1' '-DV8_TARGET_OS_IPHONE=1' '-DIPHONEOS_DEPLOYMENT_TARGET=9.0' '-DOPENSSL_THREADS' '-DOPENSSL_NO_ASM' '-DNDEBUG' '-DL_ENDIAN' '-DOPENSSL_PIC' '-DOPENSSLDIR="/System/Library/OpenSSL/"' '-DENGINESDIR="/dev/null"' -I../deps/openssl/openssl -I../deps/openssl/openssl/include -I../deps/openssl/openssl/crypto -I../deps/openssl/openssl/crypto/include -I../deps/openssl/openssl/crypto/modes -I../deps/openssl/openssl/crypto/ec/curve448 -I../deps/openssl/openssl/crypto/ec/curve448/arch_32 -I../deps/openssl/config -I../deps/openssl/config/archs/darwin64-x86_64-cc/no-asm/include -I../deps/openssl/openssl/include  -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator12.1.sdk -Os -gdwarf-2 -arch x86_64 -Wall -Wendif-labels -W -Wno-unused-parameter -Wno-missing-field-initializers -g -fno-strict-aliasing -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator12.1.sdk -mios-simulator-version-min=9.0 -fembed-bitcode -MMD -MF /opt/sweet/node/out/Release/.deps//opt/sweet/node/out/Release/obj.target/openssl-cli/deps/openssl/openssl/apps/ca.o.d.raw   -c
#     dyld: mach-o, but built for simulator (not macOS)
#     /bin/sh: line 1: 26397 Abort trap: 6           "/opt/sweet/node/out/Release/icupkg" -tl ../../deps/icu/source/data/in/icudt63l.dat "/opt/sweet/node/out/Release/obj/gen/icudt63l.dat"
#     make: *** [/opt/sweet/node/out/Release/obj/gen/icudt63l.dat] Error 134
#     make: *** Waiting for unfinished jobs....
#     rm 082aa0b677da21a8333c8ff0595ec974f5fcfb27.intermediate 0fcb52d300c7e9ed21eabf1a8bcdf10173b78a4a.intermediate
set +e
make -j4 -C out BUILDTYPE=Release V=1 node "$@"
set -e
# copy artifacts for host platform and try again
copy_artifacts
make -j4 -C out BUILDTYPE=Release V=1 node "$@"

#exec make -j4 "$@"

fi
