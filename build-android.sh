#!/bin/sh
set -x
set -e


if [ ! -x ./Debug_torque ]
then
  set -x
  rm -f {Debug,Release}_{torque,bytecode_builtins_list_generator}

  rm -rf out

  python configure.py --openssl-no-asm --without-intl --enable-static --verbose --debug
  cd out
  make -j4 torque bytecode_builtins_list_generator
  cp Debug/torque ../Debug_torque
  cp Debug/bytecode_builtins_list_generator ../Debug_bytecode_builtins_list_generator
  make -j4 torque bytecode_builtins_list_generator BUILDTYPE=Release
  cp Release/torque ../Release_torque
  cp Release/bytecode_builtins_list_generator ../Release_bytecode_builtins_list_generator
  cd ..

  rm -rf out
  set +x
fi

mkdir -p out/Debug
mkdir -p out/Release

cp Debug_torque out/Debug/torque
cp Debug_bytecode_builtins_list_generator out/Debug/bytecode_builtins_list_generator

cp Release_torque out/Release/torque
cp Release_bytecode_builtins_list_generator out/Release/bytecode_builtins_list_generator

./android-configure

sh build-rt.sh

set +e

#CC="clang -x c" CC_host="clang -x c" CXX="clang++" CXX_host=clang++ LINK=clang++ AR=ar make -C out -j4 torque bytecode_builtins_list_generator CC=clang CXX=clang


mkdir -p out
rm -f out/mock_stdio.o
echo "int stdout=1; int stderr=2;" > out/mock_stdio.c
android-toolchain/bin/clang -c out/mock_stdio.c -o out/mock_stdio.o

LDFLAGS_Debug="-fPIE -pie `pwd`/out/mock_stdio.o -v " \
LDFLAGS_Release="-fPIE -pie `pwd`/out/mock_stdio.o -v " \
make -C out torque bytecode_builtins_list_generator -e

set -e

cp Debug_torque out/Debug/torque
cp Release_torque out/Release/torque
cp Debug_bytecode_builtins_list_generator out/Debug/bytecode_builtins_list_generator
cp Release_bytecode_builtins_list_generator out/Release/bytecode_builtins_list_generator

exec make -C out BUILDTYPE=Debug V=0 node "$@" -j4
#exec make -j4 "$@"
