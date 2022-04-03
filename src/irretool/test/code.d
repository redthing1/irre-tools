module irretool.test.code;

enum PROG_BASIC_ADD = `
%entry :main

main:
    set r1 #10
    set r2 #-5
    add r0 r1 r2
    hlt
`;