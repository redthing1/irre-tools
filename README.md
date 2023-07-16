
![icon](doc/icon.png)

# irre-tools

toy handwritten assembler, emulator, compiler, toolchain for a lightweight RISC architecture 

## documentation

documentation and specifications ([arch](doc/arch.md), [asm](doc.asm.md)) are available in [doc](doc/).

## hacking

grab submodules:
```sh
git submodule update --init --recursive
```

install dependencies:
+ c compiler
+ dlang compiler + dub

### quickstart build
```sh
# build everything and export $VBCC and $IRRE
. ./script/build_tools.sh
```

tools you now have:
+ `$IRRE/irretool` (irre multitool)
+ `$VBCC/bin/vbccirre` (c->irre cross compiler)

### full build
build the irre multitool `irretool`
```sh
cd src/irretool
dub build
```

build the custom vbcc port for IRRE:
```sh
export VBCC=$(pwd)/tools/vbcc
cd tools/vbcc
mkdir -p bin
make TARGET=irre all bin/vbccirre # press enter for default answers
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

run `irre-asm` to assemble IRRE assembly to executable object:
```sh
./build/meson-out/irre-asm -m exe --dump-ast my_prog.asm my_prog.bin
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
