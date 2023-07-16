add_to@ rA rB v0 : ; this macro sets rA = rB + v0
    set ad v0
    add rA rB ad
::

main:
    set r1 $0
    set r2 $4
    add_to r2 r2 $8
