; ift test #2

%entry :main

test1:
    set r8 #0       ; dev 0 (ping)
    set r1 $01      ; cmd 0x01 (ping)
    set r2 #65      ; 'A'
    snd r2 r8 r1    ; send data (result in r2)

    set r1 $02      ; cmd 0x02 (count pings)
    set r3 #0       ; arg
    snd r3 r8 r1    ; send data (result in r3)

    ret

main:
    jmi ::test1
