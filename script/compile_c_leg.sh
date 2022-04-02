#!/usr/bin/env bash

# exit when any command fails
set -e

SRC=$1

# run clang
$LLVM_LEG_PATH/build/bin/clang -cc1 -triple leg-unknown-unknown -S -o $SRC.s $SRC

# run legc
meson-out/irre-legc $SRC.s $SRC.asm

# run asm
meson-out/irre-asm $SRC.asm $SRC.bin
