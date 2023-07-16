; test an add function

#entry :main

func_add: ; add(a, b) => a + b
    ; get arg1 [sp+4] -> r5
    set at $4
    add r1 sp at
    ldw r5 r1
    ; get arg2 [sp+8] -> r6
    set at $8
    add r1 sp at
    ldw r6 r1
    add r5 r5 r6 ; compute result -> r5
    ; return (arg1 + arg2) to [sp-4]
    set at $4
    sub r1 sp at
    stw r1 r5 ; store return value (r5)
    int r7 ; dumpstk
    ret

main:
    set r2 $0015 ; arg2 (21 DEC)
    psh r2
    set r1 $0013 ; arg1 (19 DEC)
    psh r1
    set r7 $4
    int r7 ; dumpstk
    set r4 ::func_add
    cal r4
    ; get the return value from [sp-8]
    set at $8
    sub r1 sp at
    ldw r5 r1 ; put the return value into r5
    ; tear down arguments
    pop r1
    pop r2
    int r7 ; dumpstk
    hlt
