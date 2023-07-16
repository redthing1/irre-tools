; test conditional branching

%entry :main

success:
    set r0 $1337   ; good! all passed
    hlt

lb1_fail:
    set r0 $DEAD   ; bad!
    hlt

main:
    set r1 #1
    set r2 #2

    ; check if r1 > r2
    tcu r9 r1 r2    ; r9 = sign of r1 - r2, if r1 > r2, then r9 = 1
    set r4 ::lb1_fail
    bve r4 r9 #1    ; conditional branch to lb1_fail if r9 = 1

    ; check if r1 = r2
    bve r4 r9 #0    ; conditional branch to lb1_fail if r9 = 0

    bvn r4 r9 #-1   ; conditional branch to fail if r9 != -1

    ; if we're still here, branch if r9 == -1 to success
    set r4 ::success
    bve r4 r9 #-1

    ; if we're still here, something's wrong
    jmi ::lb1_fail

    hlt