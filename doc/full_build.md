### full build (you can skip if you do quickstart)

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