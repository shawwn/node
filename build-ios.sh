set -x
set -e
./configure --dest-os=mac --dest-cpu=arm64 --without-snapshot --openssl-no-asm --with-intl=small-icu --cross-compiling --debug --verbose "$@"
make -j4 BUILDTYPE=Debug V=1
