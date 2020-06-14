; test some basic functions

%entry :main

main:
    nop
    set r1 #10
    set r2 #-5
    add r0 r1 r2 ; return
    hlt