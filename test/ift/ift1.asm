; ift test #1

%entry :main

test1:
    mov r0 r3 ; set return value
    hlt

main:
    set r1 $f00
    set r2 $41 ; 'a'
    
    stw r2 r1 #0 ; store r2 to mem
    ldw r3 r1 #0 ; load r3 from mem

    jmi ::test1
