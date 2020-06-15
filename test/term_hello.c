int msg[10] = {};

void load_data() {
    msg[0] = 'h';  // h
    msg[1] = 'e';  // e
    msg[2] = 'l';  // l
    msg[3] = 'l';  // l
    msg[4] = 'o';  // o
    msg[5] = '\n'; // \n
    msg[6] = 0;
}

volatile int* term_init() {
    // map the terminal and return the address
    volatile int* term_map_addr = (int*) 0x7000;
    asm("set r0 #1"); // DEV_ID
    asm("set r1 $b0"); // MAP
    asm("set r2 $7000"); // ADDR
    asm("snd r2 r0 r1"); // term.map(ADDR)
    return term_map_addr;
}

void term_write(volatile int* addr, int* data, int count) {
    for (int i = 0; i < count; i++) {
        addr[i] = data[i];
    }
}

int term_flush() {
    asm("set r0 #1");    // DEV_ID
    asm("set r1 $b0");   // FLUSH
    asm("snd r0 r0 r1"); // term.flush()
}

int main()
{
    load_data();
    volatile int* h_term = term_init();
    int device_id = 1; // terminal device
    term_write(h_term, msg, 10);
    term_flush();

    return 0;
}