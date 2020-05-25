; test more features

#entry :main

test1:
    hlt

main:
    set r1 .20
    set r2 .10
    
    ; special add instructions
    adi r1 $01
    sbi r1 $01

    jmi ::test1
