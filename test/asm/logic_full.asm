%entry: main

s4:
    set r0 #4   ; progress
    ret         ; done

s3:
    ; test !=
    set r0 #3   ; progress
    set r1 #2
    set r2 #3
    cmp r1 r2
    bne ::s4

s2:
    ; test >
    set r0 #2 ; progress
    set r1 #5
    set r2 #2
    cmp r1 r2
    bgt ::s3

s1:
    ; test >=
    set r0 #1 ; progress
    set r1 #4
    set r2 #4
    cmp r1 r2
    bge ::s2

main:
    set r0 #0 ; progress
    ; test ==
    set r1 #5
    set r2 #5
    cmp r1 r2
    beq ::s1