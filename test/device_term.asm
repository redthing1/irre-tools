%entry: main

main:
    sbi sp sp #8
    set r0 #1       ; dev 1 (term)

    ; first, map the terminal

    set r1 $b0      ; MAP command
    set r2 $0140    ; MAP address
    stw r2 sp #4    ; addr = r2
    snd r2 r0 r1    ; send data

    ; store characters
    ldw r2 sp #4    ; r2 = addr
    set r3 #104     ; 'H'
    stw r3 r2 #0
    set r3 #101     ; 'E'
    stw r3 r2 #1
    set r3 #108     ; 'L'
    stw r3 r2 #2
    set r3 #108     ; 'L'
    stw r3 r2 #3
    set r3 #111     ; 'O'
    stw r3 r2 #4
    set r3 #10      ; '\n'
    stw r3 r2 #5

    ; flush the terminal
    set r1 $10
    snd r2 r0 r1    ; term.flush()

    ; done
    adi sp sp #8

    hlt
