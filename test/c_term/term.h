#ifndef TERM_H
#define TERM_H

#include "../lib/corlib.h"

#define TERM_BUF_SZ 256 // the size of our terminal buffer
#define TERM_DEV_ID 1 // device ID of the terminal
#define TERM_CMD_MAP 0xb0 // the command ID for "map"
#define TERM_CMD_FLUSH 0x10 // the command ID for "flush"
#define TERM_CMD_READCHAR 0x11
#define TERM_CMD_WRITECHAR 0x12
#define TERM_CMD_READLN 0x13
#define TERM_CMD_READF 0x14

/* map the terminal device buffer to an address */
void term_init(volatile char *map_addr) {
    __dev_msg(TERM_DEV_ID, TERM_CMD_MAP, (int)map_addr);
}

/* send the flush command to the terminal device */
void term_flush() { __dev_msg(TERM_DEV_ID, TERM_CMD_FLUSH, 0); }

void term_clear_buf(volatile char *buf) {
    __memset(buf, 0, TERM_BUF_SZ);
}

/** write data to terminal buffer */
void term_write(volatile char* h_term, char* msg, int len) {
    __memcpy(h_term, msg, len);
}

void term_writechar(int c) {
    __dev_msg(TERM_DEV_ID, TERM_CMD_WRITECHAR, c);
}

int term_readchar() {
    return __dev_msg(TERM_DEV_ID, TERM_CMD_READCHAR, 0);
}

int term_readln(volatile char* h_term) {
    return __dev_msg(TERM_DEV_ID, TERM_CMD_READLN, 0);
}

int term_readf(volatile char* h_term) {
    return __dev_msg(TERM_DEV_ID, TERM_CMD_READF, 0);
}

#endif // TERM_H
