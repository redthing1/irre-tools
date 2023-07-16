#define MSG_SZ 10
#define TERM_MAP_ADDR (char *)0x7000
#define TERM_DEV_ID 1

char msg[MSG_SZ];

void load_data() {
    msg[0] = 'h';  // h
    msg[1] = 'e';  // e
    msg[2] = 'l';  // l
    msg[3] = 'l';  // l
    msg[4] = 'o';  // o
    msg[5] = '\n'; // \n
    msg[6] = 0;
}

__regsused("r0/r1/r2") void term_init(__reg("r0") int dev_id, __reg("r2") volatile char *map_addr) {
    // map the terminal and return the address
    __asm(
        // "\tset r0 #1"  // DEV_ID
        "\tset r1 $b0\n" // MAP
        // "\tset r2 $7000" // ADDR
        "\tsnd r2 r0 r1\n" // term.map(ADDR)
    );
}

void u_memcpy(volatile char *dst, volatile char *src, int count) {
    for (int i = 0; i < count; i++) {
        dst[i] = src[i];
    }
}

__regsused("r0/r1") void term_flush(__reg("r0") int dev_id) {
    __asm(
        // "\tset r0 #1"    // DEV_ID
        "\tset r1 $10\n"   // FLUSH
        "\tsnd r0 r0 r1\n" // term.flush()
    );
}

int main() {
    load_data();
    volatile char *h_term = TERM_MAP_ADDR;
    int device_id = TERM_DEV_ID; // terminal device
    term_init(device_id, h_term);
    u_memcpy(h_term, msg, MSG_SZ);
    term_flush(device_id);

    return 0;
}