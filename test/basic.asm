; test some basic functions

%entry :main

main:
    nop
    set r1 $10
    set r2 #10
    add r1 r1 r2
    set r3 $0
    hlt