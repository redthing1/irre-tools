# set -e

# 0. preparations
git submodule update --init --recursive

# 1. build vbcc
pushd tools/vbcc
export VBCC=`pwd`
# make clean
mkdir -p bin
make -j TARGET=irre DTAUTO=1 all bin/vbccirre
popd

# 2. build irre tools
pushd src/irretool
export IRRE=`pwd`
# dub clean
dub build
popd
