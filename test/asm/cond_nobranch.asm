; constructing a basic conditional jump

%entry :main

; "compare-jump"
jeq@ rA v_cmp v_loc :
    set at v_cmp ; the compare target (zero)
    tcu ad rA at ; -1, 0, 1 depending on comparison
    set at $4
    add ad ad ad ; -2, 0, 2
    add ad ad ad ; -4, 0, 4
    add ad ad at ;  0, 4, 8
    add pc pc ad ; skip 0, 1, 2 instructions
    add pc pc at ; skip the SET
    set pc v_loc ; the "branch"
::

main:
    set r7 $7
    ; branch if r7 == 7
    jeq r7 $7 ::is_seven

not_seven:
    set r1 $b000 ; fail
    hlt

is_seven:
    set r1 $1337 ; based
    hlt
