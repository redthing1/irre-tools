#include "../lib/corlib.h"

#define MSG_SZ 16 // the size of our message string
#define TERM_MAP_ADDR (char *)0x7000 // the location (changeable) where we map the terminal
#define TERM_DEV_ID 1 // device ID of the terminal
#define TERM_CMD_MAP 0xb0 // the command ID for "map"
#define TERM_CMD_FLUSH 0x10 // the command ID for "flush"

char msg[MSG_SZ] = "hello, world!\n";

/* map the terminal device buffer to an address */
void term_init(int dev_id, volatile char *map_addr) {
    __dev_msg(dev_id, TERM_CMD_MAP, (int)map_addr);
}

/* send the flush command to the terminal device */
void term_flush(int dev_id) { __dev_msg(dev_id, TERM_CMD_FLUSH, 0); }

int main() {
    volatile char *h_term = TERM_MAP_ADDR;
    int device_id = TERM_DEV_ID;
    term_init(device_id, h_term);
    __memcpy(h_term, msg, MSG_SZ);
    term_flush(device_id);

    return 0;
}