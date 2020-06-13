; test some basic functions

%entry :main

head_data:
    %d \x 22000000 ; $22 in little endian

main:
    set r2 ::head_data
    ldw r1 r2 #0 ; load the data into r1
    hlt

tail_data:
    %d \z 8 ; 8 zero-bytes
