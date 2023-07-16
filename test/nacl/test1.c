#include "../lib/corlib.h"

#include "tweetnacl.h"

#define INPUT_MAX 128

int randombytes(void *buf, int n);

int main() {
  // inputs
  const char *input = "Hello, world!";
  const char *key_st = "This is a key.";

  // sha256 hash the key
  unsigned char key[crypto_hash_BYTES];
  crypto_hash(key, key_st, strlen(key_st));

  // generate a random nonce
  unsigned char nonce[crypto_secretbox_NONCEBYTES];
  randombytes(nonce, crypto_secretbox_NONCEBYTES);

  // create a buffer for the plaintext
  unsigned char plaintext[crypto_secretbox_ZEROBYTES + INPUT_MAX];
  // copy the input into the plaintext buffer
  memset(plaintext, 0, crypto_secretbox_ZEROBYTES);
  memcpy(plaintext + crypto_secretbox_ZEROBYTES, input, INPUT_MAX);

  // create a buffer for the ciphertext
  unsigned char ciphertext[crypto_secretbox_ZEROBYTES + INPUT_MAX];
  // encrypt the plaintext
  crypto_secretbox(ciphertext, plaintext,
                   crypto_secretbox_ZEROBYTES + INPUT_MAX, nonce, key);

  // now try to decrypt the ciphertext
  unsigned char decrypted[crypto_secretbox_ZEROBYTES + INPUT_MAX];
  if (crypto_secretbox_open(decrypted, ciphertext,
                            crypto_secretbox_ZEROBYTES + INPUT_MAX, nonce,
                            key) != 0) {
    return 1;
  }

  return 0;
}