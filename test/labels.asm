; test labels and constant jump

#entry :main

nop

test1:
    hlt

main:
    ; test jump
    jmi ::test1 ; compiles to [set rA <offset>]