; recursive implementation of fib(n)
; n is specified in r1 in ::main
; result is placed in r7

#entry :main

jl@ rA v_cmp v_loc : ; jump to v_loc if rA < v_cmp
    ; less means sign = 1
    set at v_cmp ; the compare target (zero)
    tcu ad at rA ; -1, 0, 1 depending on comparison
    set at $4
    add ad ad ad ; -2, 0, 2
    add ad ad ad ; -4, 0, 4
    add ad ad at ;  0, 4, 8
    add ad ad at ;  4, 8, 12
    add pc pc ad ; skip 1, 2, 3 instructions
    nop
    nop
    add pc pc at ; skip the jump
    jmi v_loc
::

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

fib:
    get_stk r11 $8 ; n (arg1)
    ; branch if n < 2
    jl r11 $2 ::fib_base_case
    ; F(n) := F(n-1) + F(n-2)

    ; calculate F(n-1)
    set r2 $1
    sub r1 r1 r2 ; r1 = (n-1)
    psh r1 ; (n-1) (arg1)
    psh r14 ; slot
    set r4 ::fib
    cal r4
    pop r3  ; r3 <- result
    pop r1 ; pop (n-1) -> r1

    ; save our r3
    psh r3

    ; calculate F(n-2)
    sub r1 r1 r2 ; r1 = (n-2)
    psh r1 ; (n-2) (arg1)
    psh r14 ; slot
    set r4 ::fib
    cal r4
    pop r4 ; r4 <- result
    pop r1 ; pop (n - 2) -> r1

    ; retrieve our r3
    pop r3

    add r5 r3 r4 ; r5 = F(n)
    put_stk $4 r5 ; r5 -> slot

    ret

fib_base_case: ; F(n) := n
    put_stk $4 r11
    ret

main:
    set r14 $00 ; GLB: default slot value

    set r1 .10 ; n
    psh r1     ; n (arg1)
    psh r14    ; slot

    set r4 ::fib
    cal r4 ; fib(n)

    pop r7 ; pop slot
    pop r1 ; pop arg1

    hlt
