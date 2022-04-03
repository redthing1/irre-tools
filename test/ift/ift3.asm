; ift test #3
; IMPORTANT: the SND command should !NOT! be optimized away!
; even though the SND ping will return 0, and the arg was 0, the SND should still be called!

%entry :main

test1:
    set r8 #0       ; dev 0 (ping)
    set r1 $01      ; cmd 0x01 (ping)
    set r2 #0       ; 0x00
    snd r2 r8 r1    ; send data (result in r2)

    ret

main:
    jmi ::test1
