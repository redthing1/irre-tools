; test function calls

#entry :main

sub:
    set r2 $0069 ; return value
    ; retval dest is [sp-4]
    set at $4
    sub r3 sp at
    stw r3 r2 ; store retval
    ret

main:
    set r1 $0041 ; arg1
    psh r1
    set r4 ::sub
    cal r4 ; call the subprocedure
    set r4 $01
    int r4 ; pause
    ; get the return value from [sp-8]
    set at $8
    sub r1 sp at
    ldw r2 r1 ; put the return value into r2
    pop r1 ; pop arg1 back into r1
    hlt ; r1 = $41, r2 = $69
