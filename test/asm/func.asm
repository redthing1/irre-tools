; test basic add function

%entry :main

main:
    set r0 #2
    set r1 #1

    set r4 ::func_add
    cal r4

    ; return value is in r0

    hlt

func_add:
    add r0 r0 r1
    ret