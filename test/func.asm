; test basic add function with asmv2

%entry :main

get_stk@ rA v_offset :
    set at v_offset
    add at sp at
    ldw rA at
::

put_stk@ v_offset rA :
    set at v_offset
    add at sp at
    stw at rA
::

main:
    set r1 .20
    set r2 .10

    ; push to the stack in reverse order
    psh r2 ; arg2
    psh r1 ; arg1
    psh r1 ; slt

    set r4 ::func_add
    cal r4

    pop r7 ; pop from slt
    ; tear down args
    pop r1
    pop r1

    hlt

func_add:
    ; | RET | SLT | R1 | R2 |
    get_stk r11 $8 ; arg1
    get_stk r12 $c ; arg2

    add r1 r11 r12
    ; put return value in SLT
    put_stk $4 r1

    ret
