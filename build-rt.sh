set -x
set -e

pushd android-toolchain/sysroot/usr/lib/aarch64-linux-android
rm -f librt.a
if [ ! -e librt.a ]
then
  echo 'int stdin=0; int stdout=1; int stderr=2;' > rt.c
  ../../../../bin/aarch64-linux-android21-clang -c rt.c
  ../../../../bin/aarch64-linux-android-ar crs librt.a rt.o
fi
popd

pushd android-toolchain/sysroot/usr/lib/arm-linux-androideabi
rm -f librt.a
if [ ! -e librt.a ]
then
  echo 'int stdin=0; int stdout=1; int stderr=2;' > rt.c
  clang=`ls -1 ../../../../bin | grep clang$ | grep arm | grep 21`
  ar=`ls -1 ../../../../bin | grep ar$ | grep arm-linux`
  ../../../../bin/$clang -c rt.c
  ../../../../bin/$ar crs librt.a rt.o
fi
popd
