#define MSG_SZ 16
#define TERM_MAP_ADDR (char *)0x7000
#define TERM_DEV_ID 1
#define TERM_CMD_MAP 0xb0
#define TERM_CMD_FLUSH 0x10

char msg[MSG_SZ] = "hello, world!\n";

__regsused("r0/r1/r2") void dev_msg(__reg("r0") int dev_id, __reg("r1") int cmd,
                                    __reg("r2") int arg) = "\tsnd r2 r0 r1"; // devices[dev_id].send(cmd, arg)

void term_init(int dev_id, volatile char *map_addr) {
    // send MAP cmd to term
    dev_msg(dev_id, TERM_CMD_MAP, (int)map_addr);
}

void u_memcpy(volatile char *dst, volatile char *src, int count) {
    for (int i = 0; i < count; i++) {
        dst[i] = src[i];
    }
}

void term_flush(int dev_id) { dev_msg(dev_id, TERM_CMD_FLUSH, 0); }

int main() {
    volatile char *h_term = TERM_MAP_ADDR;
    int device_id = TERM_DEV_ID; // terminal device
    term_init(device_id, h_term);
    u_memcpy(h_term, msg, MSG_SZ);
    term_flush(device_id);

    return 0;
}