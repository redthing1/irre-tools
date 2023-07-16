#ifndef CORLIB_H
#define CORLIB_H

/* types */
#define CHAR (char)
#define CHARP (char*)
#define VCHARP (volatile char*)
#define INT (int)
#define UINT (unsigned int)
#define VOID (void)

#define BOOL int
#define true (1)
#define false (0)

#define bool BOOL

/* intrinsics */

/** intrinsic for SND I/O instruction: devices[dev_id].send(cmd, arg) */
#define __DEV_MSG(dev_id, cmd, arg) asm inline volatile("\tsnd\t" #dev_id "\t" #cmd "\t" #arg)

/** intrinsic to break into the debugger */
#define __DEBUGGER_BREAK() asm inline volatile("\tint\t$a0\t; debugger break")

/* libc-like utility functions */

/** copy data between two memory locations */
void memcpy(volatile char *dst, volatile char *src, int count) {
    for (int i = 0; i < count; i++) {
        dst[i] = src[i];
    }
}

/** set data in memory */
void memset(volatile char *dst, int val, int count) {
    for (int i = 0; i < count; i++) {
        dst[i] = val;
    }
}

int seed;
int rng_a = 0xffffffff;
int rng_c = 12345;
int rng_m = 1103515245;

/** set seed for RNG */
void srand(int s) { seed = s; }

/** get next random number */
int rand() {
    seed = (rng_a * seed + rng_c) % rng_m;
    return seed;
}

#endif /* CORLIB_H */