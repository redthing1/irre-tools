// https://github.com/shiffthq/chacha20/blob/master/src/chacha20.h
#ifndef __CHACHA20_H
#define __CHACHA20_H

void ChaCha20XOR(uint8_t key[32], uint32_t counter, uint8_t nonce[12], uint8_t *input, uint8_t *output, int inputlen);

#endif
