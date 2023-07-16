; test memory instructions

%entry :main

test1:
    int r3
    hlt

main:
    set r1 $f00
    set r2 $41 ; 'a'
    
    stw r1 r2 #0 ; store r2 to mem
    ldw r3 r1 #0 ; load r3 from mem

    jmi ::test1
