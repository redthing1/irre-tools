; test some basic functions

%entry :main

data:
    %d \x 22000000 ; $22 in little endian

main:
    set r2 ::data
    ldw r1 r2 #0 ; load the data into r1
    hlt