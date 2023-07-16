; ift test #4

%entry :main

test1:
    set r1 #1
    set r2 #2
    add r3 r1 r2    ; 1 + 2
    set r4 #3
    set r5 #4
    add r6 r4 r5    ; 3 + 4
    ; store in memory
    stw r6 sp #-4

    add r0 r3 r6    ; (1 + 2) + (3 + 4)
    stw r0 sp #-8

    ret

main:
    jmi ::test1
