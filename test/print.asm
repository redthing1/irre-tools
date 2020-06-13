; try printing to terminal device

%entry :main

data0:
    %d \68656c6c6f20776f726c642100000000 ; "hello, world!\0\0\0\0"

write_str: ; write_str(char* str, void* addr)
    ret

main:
    nop
    set r2 ::data0 ; r2 = &data0
    set r1 ::write_str
    cal r1
    hlt