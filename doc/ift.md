
# ift

IRRE contains an experimental algorithm for information flow tracking.

TBD

examples
```sh
$IRRE/irretool emu --commit-log --ift --ift-quiet --ift-pl --save-commits fib3_trace.bin test/c_basic/fib_3.bin

$IRRE/irretool emu --commit-log --ift --ift-pl test/c_basic/shuffle1.bin

$IRRE/irretool emu --commit-log --ift --ift-quiet --ift-pl test/c_basic/fib_3.bin

```
