#ifndef CORLIB_H
#define CORLIB_H

/* types */
#define CHAR (char)
#define CHARP (char *)
#define VCHARP (volatile char *)
#define INT (int)
#define UINT (unsigned int)
#define VOID (void)

#define int8_t char
#define uint8_t unsigned char
#define int16_t short
#define uint16_t unsigned short
#define int32_t int
#define uint32_t unsigned int
#define int64_t long
#define uint64_t unsigned long
#define size_t uint32_t

#define BOOL int
#define true (1)
#define false (0)

#define bool BOOL

/* intrinsics */

/** intrinsic for SND I/O instruction: devices[dev_id].send(cmd, arg) */
int __device_send(int device_id, int command, int arg) {
    // move arguments into r22, r23, r24
    asm inline volatile("\tmov\tr22\tr1");
    asm inline volatile("\tmov\tr23\tr2");
    asm inline volatile("\tmov\tr24\tr3");
    asm inline volatile("\tsnd\tr22\tr23\tr24\t; device send");
    // move return value (from the data arg r24) into r1
    asm inline volatile("\tmov\tr1\tr24");
}

/** intrinsic to break into the debugger */
#define __DEBUGGER_BREAK() asm inline volatile("\tint\t$a0\t; debugger break")

/* libc-like utility functions */

/** copy data between two memory locations */
void memcpy(volatile char *dst, volatile char *src, size_t count) {
    for (int i = 0; i < count; i++) {
        dst[i] = src[i];
    }
}

/** set data in memory */
void memset(volatile char *dst, int val, size_t count) {
    for (int i = 0; i < count; i++) {
        dst[i] = val;
    }
}

/** calculate length of null-terminated string */
size_t strlen(volatile char *str) {
    int len = 0;
    while (str[len] != 0) {
        len++;
    }
    return len;
}

/** compare two strings */
int memcmp(const void *str1, const void *str2, size_t n) {
    for (int i = 0; i < n; i++) {
        if (((char *)str1)[i] != ((char *)str2)[i]) {
            return 1;
        }
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