#ifndef CORLIB_H
#define CORLIB_H

/* inline assembly function to call the SND instruction for I/O */
__regsused("r0/r1/r2") void __dev_msg(__reg("r0") int dev_id, __reg("r1") int cmd,
                                    __reg("r2") int arg) = "\tsnd r2 r0 r1"; // devices[dev_id].send(cmd, arg)

/* copy data between two memory locations */
void __memcpy(volatile char *dst, volatile char *src, int count) {
    for (int i = 0; i < count; i++) {
        dst[i] = src[i];
    }
}

#endif /* CORLIB_H */