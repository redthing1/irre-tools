set -e

# 0. preparations
git submodule update --init --recursive

# 1. build vbcc
pushd tools/vbcc
export VBCC=`pwd`
# make clean
yes "" | make TARGET=irre all bin/vbccirre
popd

# 2. build irre tools
pushd src/irretool
export IRRE=`pwd`
# dub clean
dub build
popd
