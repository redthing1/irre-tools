%entry: main

main:
    set r0 #1       ; dev 1 (term)

    ; first, map the terminal

    set r1 $b0      ; MAP command
    set r2 $0140    ; MAP address
    snd r2 r0 r1    ; send data

    ; store characters
    set r3 #65      ; 'A'
    stw r3 r2 #0

    ; flush the terminal
    set r1 $10
    snd r2 r0 r1    ; term.flush()

    hlt
