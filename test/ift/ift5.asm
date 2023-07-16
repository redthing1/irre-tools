; ift test #5

%entry :main

main:
    ; set 32 bit value aabbccdd
    set r1 $ccdd
    sup r1 $aabb

    ; test stack pointer
    adi r2 r2 #8

    hlt
