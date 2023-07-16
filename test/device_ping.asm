%entry: main

main:
    set r0 #0       ; dev 0 (ping)
    set r1 $01      ; cmd 0x01
    set r2 #65      ; 'A'
    snd r2 r0 r1    ; send data
    mov r0 r2       ; copy to return value

    hlt
