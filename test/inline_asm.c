
// test inline assembly

int asm_add(int a, int b) {
    asm("nop\n\
    mov r14 r0\n\
    mov r15 r1\n\
    add r0 r14 r15");
}

int main()
{
    return asm_add(2, 3);
}
