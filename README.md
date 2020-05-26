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
