#include "corlib.h"

#define MSG_SZ 16 // the size of our message string
#define TERM_MAP_ADDR (char *)0x7000 // the location (changeable) where we map the terminal
#define TERM_DEV_ID 1 // device ID of the terminal
#define TERM_CMD_MAP 0xb0 // the command ID for "map"
#define TERM_CMD_FLUSH 0x10 // the command ID for "flush"

char msg1[MSG_SZ] = "writing things\n";

/* map the terminal device buffer to an address */
void term_init(volatile char *map_addr) {
    __dev_msg(TERM_DEV_ID, TERM_CMD_MAP, (int)map_addr);
}

/* send the flush command to the terminal device */
void term_flush() { __dev_msg(TERM_DEV_ID, TERM_CMD_FLUSH, 0); }

int main() {
    // map terminal
    volatile char *h_term = TERM_MAP_ADDR;
    term_init(h_term);
    // write data to terminal buffer
    __memcpy(h_term, msg1, MSG_SZ);
    // flush terminal
    term_flush();

    return 0;
}