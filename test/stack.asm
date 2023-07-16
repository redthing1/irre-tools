; test stack

#entry :main

main:
    set r1 $00ff
    psh r1
    pop r2
    hlt
