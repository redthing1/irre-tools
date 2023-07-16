#include "../lib/corlib.h"

uint64_t test[4];

int main() {
    uint64_t b = 0x1020304050607080;
    
    uint32_t c_lower = (b & 0xffffffff);
    uint32_t c_upper = (b >> 32);

    test[0] = b;
    test[1] = c_lower;

    return c_upper; // $10203040
}