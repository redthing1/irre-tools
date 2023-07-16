# set -e

# git submodule update --init --recursive

pushd tools/chcc
# make clean
make -j
popd

pushd src/irretool
# dub clean
dub build
popd
