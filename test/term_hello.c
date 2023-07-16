#define MSG_SZ 10
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

volatile char* term_init() {
    // map the terminal and return the address
    volatile char* term_map_addr = (char*) 0x7000;
    __asm("\tset r0 #1"); // DEV_ID
    __asm("\tset r1 $b0"); // MAP
    __asm("\tset r2 $7000"); // ADDR
    __asm("\tsnd r2 r0 r1"); // term.map(ADDR)
    return term_map_addr;
}

void term_write(volatile char* addr, char* data, int count) {
    for (int i = 0; i < count; i++) {
        addr[i] = data[i];
    }
}

int term_flush() {
    __asm("\tset r0 #1");    // DEV_ID
    __asm("\tset r1 $10");   // FLUSH
    __asm("\tsnd r0 r0 r1"); // term.flush()
}

int main()
{
    load_data();
    volatile char* h_term = term_init();
    int device_id = 1; // terminal device
    term_write(h_term, msg, MSG_SZ);
    term_flush();

    return 0;
}