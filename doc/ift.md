
# ift

IRRE contains an experimental algorithm for information flow tracking.

TBD

examples
```sh
$IRRE/irretool emu --commit-log --ift --ift-quiet --ift-pl --save-commits fib3_trace.bin test/c_basic/fib_3.bin

$IRRE/irretool emu --commit-log --ift --ift-pl test/c_basic/shuffle1.bin

$IRRE/irretool emu --commit-log --ift --ift-quiet --ift-pl test/c_basic/fib_3.bin

```

sample output:
```
❯ time $IRRE/irretool -v emu --commit-log --ift --ift-pl test/ift/ift4.bin
[IRRE] emulator v3.11
program size: $0028
[log] [TERM] device initialized.
[log] halted after 10 cycles with code $000a (#0010).

commit log
     0 reg @0x$0000   PC <- $0024 <source:  i=$0024> (jmi  $000024)
     1 reg @0x$0024   PC <- $0004 <source:  i=$0004> (jmi  $000004)
     2 reg @0x$0004   R1 <- $0001 <source:  i=$0001> (set  r1   $0001)
     3 reg @0x$0008   R2 <- $0002 <source:  i=$0002> (set  r2   $0002)
     4 reg @0x$000c   R3 <- $0003 <source:  R1=$0001 R2=$0002> (add  r3   r1   r2)
     5 reg @0x$0010   R4 <- $0003 <source:  i=$0003> (set  r4   $0003)
     6 reg @0x$0014   R5 <- $0004 <source:  i=$0004> (set  r5   $0004)
     7 reg @0x$0018   R6 <- $0007 <source:  R4=$0003 R5=$0004> (add  r6   r4   r5)
     8 reg @0x$001c   R0 <- $000a <source:  R3=$0003 R6=$0007> (add  r0   r3   r6)
     9 reg @0x$0020   PC <- $0000   LR <- $0000 <source:  LR=$0000> (ret)
 clobber (10 commits):
  memory:
  regs:
   reg R0 <- $000a
   reg R1 <- $0001
   reg R2 <- $0002
   reg R3 <- $0003
   reg R4 <- $0003
   reg R5 <- $0004
   reg R6 <- $0007

ift analysis (parallel x12)
backtracking information flow for node: R0=$000a
  visiting: node: R0=$000a, commit pos: 8
   found last touching commit (#8) for node: InfoNodeWalk(R0=$000a, 8): reg @0x$001c   R0 <- $000a <source:  R3=$0003 R6=$0007> (add  r0   r3   r6)
    found dependency: R6=$0007
    found dependency: R3=$0003
  visiting: node: R3=$0003, commit pos: 7
   found last touching commit (#4) for node: InfoNodeWalk(R3=$0003, 7): reg @0x$000c   R3 <- $0003 <source:  R1=$0001 R2=$0002> (add  r3   r1   r2)
    found dependency: R2=$0002
    found dependency: R1=$0001
  visiting: node: R1=$0001, commit pos: 3
   found last touching commit (#2) for node: InfoNodeWalk(R1=$0001, 3): reg @0x$0004   R1 <- $0001 <source:  i=$0001> (set  r1   $0001)
    found dependency: i=$0001
  visiting: node: i=$0001, commit pos: 1
   leaf (source): InfoSource(node: i=$0001, commit_id: 1)
  visiting: node: R2=$0002, commit pos: 3
   found last touching commit (#3) for node: InfoNodeWalk(R2=$0002, 3): reg @0x$0008   R2 <- $0002 <source:  i=$0002> (set  r2   $0002)
    found dependency: i=$0002
  visiting: node: i=$0002, commit pos: 2
   leaf (source): InfoSource(node: i=$0002, commit_id: 2)
  visiting: node: R6=$0007, commit pos: 7
   found last touching commit (#7) for node: InfoNodeWalk(R6=$0007, 7): reg @0x$0018   R6 <- $0007 <source:  R5=$0004 R4=$0003> (add  r6   r4   r5)
    found dependency: R4=$0003
    found dependency: R5=$0004
  visiting: node: R5=$0004, commit pos: 6
   found last touching commit (#6) for node: InfoNodeWalk(R5=$0004, 6): reg @0x$0014   R5 <- $0004 <source:  i=$0004> (set  r5   $0004)
    found dependency: i=$0004
  visiting: node: i=$0004, commit pos: 5
   leaf (source): InfoSource(node: i=$0004, commit_id: 5)
  visiting: node: R4=$0003, commit pos: 6
   found last touching commit (#5) for node: InfoNodeWalk(R4=$0003, 6): reg @0x$0010   R4 <- $0003 <source:  i=$0003> (set  r4   $0003)
    found dependency: i=$0003
  visiting: node: i=$0003, commit pos: 4
   leaf (source): InfoSource(node: i=$0003, commit_id: 4)
 backtraces:
  reg R6:
   InfoSource(node: i=$0003, commit_id: 4)
   InfoSource(node: i=$0004, commit_id: 5)
  reg R0:
   InfoSource(node: i=$0001, commit_id: 1)
   InfoSource(node: i=$0002, commit_id: 2)
   InfoSource(node: i=$0004, commit_id: 5)
   InfoSource(node: i=$0003, commit_id: 4)
  reg R5:
   InfoSource(node: i=$0004, commit_id: 5)
  reg R4:
   InfoSource(node: i=$0003, commit_id: 4)
  reg R3:
   InfoSource(node: i=$0002, commit_id: 2)
   InfoSource(node: i=$0001, commit_id: 1)
  reg R2:
   InfoSource(node: i=$0002, commit_id: 2)
 summary:
  num commits:                  10
  registers traced:              7
  memory traced:                 0
  analysis time:          0.001895s
$IRRE/irretool -v emu --commit-log --ift --ift-pl test/ift/ift4.bin  0.00s user 0.01s system 110% cpu 0.007 total
```
