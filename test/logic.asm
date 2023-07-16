; test more features

#entry :test1

end:
    hlt

cond1:
    set r2 $00ff
    int r2 ; raise r2
    jmi ::end ; resume the test

test1:
    ; test conditional jumping
    set r1 .11
    set r2 .10
    ; compare values
    tcu r3 r1 r2 ; r3 = cmp result
    set r4 ::cond1 ; set jump point
    brx r3 r4 ; branch if r3 > 0
