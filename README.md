
![icon](doc/icon.png)

# irre-tools

toy handwritten assembler, emulator, compiler, toolchain for a lightweight RISC architecture 

## documentation

documentation and specifications ([arch](doc/arch.md), [asm](doc.asm.md)) are available in [doc](doc/).

## setup

grab submodules:
```sh
git submodule update --init --recursive
```

install dependencies:
+ C compiler
+ [D compiler](https://dlang.org/download.html)

### quickstart build
```sh
./script/build_tools.sh
```

tools you now have:
+ `./src/irretool/irretool` (irre multitool)
+ `./tools/vbcc/bin/vbccirre` (c->irre cross compiler)

## compile a C program

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

now build and run:
```sh
# compile to binary
./script/irrecc -v -o my_prog.bin my_prog.c
# run in emulator
./src/irretool/irretool -v emu my_prog.bin
```

## run flow tracking

1. run a compiled program and log commits and snapshots

```
./src/irretool/irretool -v emu --commit-log --save-commits t1_trace.bin my_prog.bin
```
2. run analyzer

```
./src/irretool/irretool analyze --ift --pl --pl-threads 4 --ift-graph --ift-graph-analysis --ift-save-graph t1_graph.dot t1_trace.bin
```
