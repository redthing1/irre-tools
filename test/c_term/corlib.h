#ifndef CORLIB_H
#define CORLIB_H

#define CHAR (char)
#define CHARP (char*)
#define VCHARP (volatile char*)
#define INT (int)
#define UINT (unsigned int)
#define VOID (void)

/* inline assembly function to call the SND instruction for I/O */
__regsused("r0/r1/r2") int __dev_msg(__reg("r1") int dev_id, __reg("r2") int cmd,
                                    __reg("r0") int arg) = "\tsnd r0 r1 r2"; // devices[dev_id].send(cmd, arg)

/* copy data between two memory locations */
void __memcpy(volatile char *dst, volatile char *src, int count) {
    for (int i = 0; i < count; i++) {
        dst[i] = src[i];
    }
}

/** set data in memory */
void __memset(volatile char *dst, int val, int count) {
    for (int i = 0; i < count; i++) {
        dst[i] = val;
    }
}

#endif /* CORLIB_H */