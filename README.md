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

to use another D compiler, such as `gdc`, set the environment variable ex. `CC=gdc` when running `configure`.
