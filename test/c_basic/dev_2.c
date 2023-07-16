#include "../lib/corlib.h"

const u32 DEMO_DEVICE_RANDOM = 0x00007007;

#define NONCE_SIZE 128
volatile u8 nonce[NONCE_SIZE] = {0};

int main() {
    // fill the nonce with random bytes
    u8 *nonce_ptr = nonce;
    __device_send(DEMO_DEVICE_RANDOM, (u32)nonce_ptr, NONCE_SIZE);
}