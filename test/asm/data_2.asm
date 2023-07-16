; test some basic functions

%entry :main

head_data:
    %d \x 22000000 ; $22 in little endian

main:
    set r2 ::head_data
    ldw r1 r2 #0 ; load the data
    set r2 ::tail_data_num
    ldw r2 r2 #0
    add r0 r1 r2 ; add
    hlt

tail_data_z:
    %d \z 8 ; 8 zero-bytes
tail_data_num:
    %d \x 33000000
