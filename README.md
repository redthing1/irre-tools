# irre-tools
continuation of regularvm

## build

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

see the [leg tools](doc/leg_tools.org) page for instructions on setting up a `clang-leg` compiler.

then, use the [`regular` branch of llvm-leg](https://github.com/xdrie/llvm-leg/tree/regular).

once you have LLVM/Clang built, store the path of `lvvm-leg` in `$LLVM_LEG_PATH`.

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

build to a `.s` file with Clang:
```sh
$LLVM_LEG_PATH/build/bin/clang -cc1 -triple leg-unknown-unknown -S -o my_prog.s my_prog.c
```

run `irre-legc` to translate LEG to IRRE:
```sh
./build/meson-out/irre-legc my_prog.s my_prog.asm
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

and that's all she wrote, folks.
