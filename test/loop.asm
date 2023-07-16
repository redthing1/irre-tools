#entry :main

main:
    nop
    set r4 $4 ; loop bound
    set r2 $0 ; loop counter
    ; it will loop ([bnd-ctr] + 1) times [5]
loop:
    ; do loop work
    adi r7 $1
    ; loop branch
    tcu r3 r4 r2 ; r3 = SIGN[r4 - r2]
    adi r2 $1
    set r1 ::loop
    brx r1 r3 ; branch to ::loop, if r3
    sbi r2 $1 ; post-loop fix

end:
    hlt