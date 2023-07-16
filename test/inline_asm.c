
// test inline assembly

int main()
{
    int a = 2;
    int b = 3;
    register int *c asm ("r4");
    asm("nop");
    return *c;
}
