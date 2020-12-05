# irre-tools

toy handwritten assembler, emulator, compiler, toolchain for a lightweight RISC architecture 

## documentation

documentation and specifications ([arch](doc/arch.md), [asm](doc.asm.md)) are available in [doc](doc/).

## build

grab submodules:
```sh
git submodule update --init --recursive
```

install dependencies:
+ `meson`
+ `ninja`

```sh
./configure
cd build
ninja
```

to use another D compiler, such as `dmd`, set the environment variable ex. `DC=dmd` when running `configure`.

## hacking

build the custom vbcc port for IRRE:
```sh
cd tools/vbcc
make # don't worry if it fails
make TARGET=irre bin/vbccirre # press enter for default answers
export VBCC=$(pwd)
```

### compile a C program

```c
// my_prog.c

int add(int a, int b) {
    return a + b;
}

int main() {
    int a = 3;
    int b = 4;
    int sum = add(a, b);
    return sum;
}

```

build to an assembly file with VBCC-IRRE:
```sh
$VBCC/bin/vbccirre -c99 -default-main -o=my_prog.asm my_prog.c
```

run `irre-asm` to assemble IRRE to bin:
```sh
./build/meson-out/irre-asm my_prog.asm my_prog.bin
```

run `irre-emu` to run in the emulator:
```sh
./build/meson-out/irre-emu --debug my_prog.bin
```

which should output something like:

```
... long register dump ...
   PC: $00000000
   LR: $00000000
   AD: $00000000
   AT: $00000014
   SP: $00010000
program halted with code $0007
```

that's all she wrote, folks.
