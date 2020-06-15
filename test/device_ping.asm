%entry: main

main:
    set r0 #0   ; dev 0
    set r1 $01  ; cmd 0x01
    set r2 #65  ; 'A'
    snd r0 r1 r2

    hlt
