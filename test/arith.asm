; test more features

%entry :main

test1:
    hlt

main:
    set r1 .20
    set r2 .10
    
    ; addition
    add r1 r1 r2 ; r1 = .30
    ; subtraction
    sub r2 r1 r2 ; r2 = .20

    jmi ::test1
