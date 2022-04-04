; ift test #6

%entry :main

test1:
    ; set r1 #1
    ; set r2 #2
    ; add r3 r1 r2    ; r3 = 1 + 2
    ; set r4 #3
    ; set r5 #4
    ; add r6 r4 r5    ; 3 + 4

    ; add r0 r3 r6    ; (1 + 2) + (3 + 4) -> r0 = 10

    ; set r7 #5
    ; set r8 #6

    ; add r3 r3 r7    ; r3 += 5 -> r3 = 8
    ; add r9 r7 r8    ; 5 + 6 -> r9 = 11

    ; add r0 r0 r9    ; r0 += 11 -> r0 = 21

    ; now for big numbers
    ; set r11 $ffff
    ; sup r11 $ffff
    set r12 $11
    add r11 r11 r12 ; r11 = $11
    add r11 r11 r12 ; r11 = $22
    add r11 r11 r12 ; r11 = $33
    add r11 r11 r12 ; r11 = $44
    add r11 r11 r12 ; r11 = $55
    add r11 r11 r12 ; r11 = $66
    add r11 r11 r12 ; r11 = $77
    sup r11 $ffff   ; r11 = $ffff0011
    add r11 r11 r12 ; r11 = $ffff0088
    add r11 r11 r12 ; r11 = $ffff0099
    add r11 r11 r12 ; r11 = $ffff00aa
    add r11 r11 r12 ; r11 = $ffff00bb
    add r11 r11 r12 ; r11 = $ffff00cc
    add r11 r11 r12 ; r11 = $ffff00dd
    add r11 r11 r12 ; r11 = $ffff00ee
    add r11 r11 r12 ; r11 = $ffff00ff

    ret

main:
    jmi ::test1
