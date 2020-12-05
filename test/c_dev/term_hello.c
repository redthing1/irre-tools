#define MSG_SZ 16 // the size of our message string
#define TERM_MAP_ADDR (char *)0x7000 // the location (changeable) where we map the terminal
#define TERM_DEV_ID 1 // device ID of the terminal
#define TERM_CMD_MAP 0xb0 // the command ID for "map"
#define TERM_CMD_FLUSH 0x10 // the command ID for "flush"

char msg[MSG_SZ] = "hello, world!\n";

/* inline assembly function to call the SND instruction for I/O */
__regsused("r0/r1/r2") void __dev_msg(__reg("r0") int dev_id, __reg("r1") int cmd,
                                    __reg("r2") int arg) = "\tsnd r2 r0 r1"; // devices[dev_id].send(cmd, arg)

/* copy data between two memory locations */
void __memcpy(volatile char *dst, volatile char *src, int count) {
    for (int i = 0; i < count; i++) {
        dst[i] = src[i];
    }
}

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