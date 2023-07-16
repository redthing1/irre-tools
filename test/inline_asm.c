
// test inline assembly

__regsused("r1") int asm_increment(__reg("r1") int n) {
    __asm("\tadi r0 r1 #1");
}

__regsused("r1/r4") void asm_add5_ref(__reg("r1") int* n) {
    __asm(
        "\tldw r4 r1 #0\n"
        "\tadi r4 r4 #5\n"
        "\tstw r4 r1 #0\n"
    );
}

int main()
{
    int a = 2;
    int b = 3;
    b = asm_increment(b); // b = 4
    asm_add5_ref(&a); // a = 7

    return a + b; // 11
}
