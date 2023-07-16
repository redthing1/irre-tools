
// test arbitrary memory access

int main() {
    volatile int* mem_loc = (int*) 0x1000; // the address in memory
    *mem_loc = 17;
    int c = 15;
    return c + *mem_loc;
}
