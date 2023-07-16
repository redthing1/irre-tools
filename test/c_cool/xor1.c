#include "../lib/corlib.h"

#define BLOCK_SIZE (8)

char xor_input[BLOCK_SIZE] = {'i', 'c', 'e', 'c', 'r', 'e', 'a', 'm'}; // 6963 6563 7265 616d
char xor_key[BLOCK_SIZE] = {'c', 'a', 'n', 'd', 'y', 'b', 'a', 'r'};   // 6361 6e64 7962 6172
char xor_encrypted[BLOCK_SIZE];                                        // should be 0a02 0b07 0b07 001f
char xor_decrypted[BLOCK_SIZE];                                        // should be 6963 6563 7265 616d
char xor_check[BLOCK_SIZE] = {0x0a, 0x02, 0x0b, 0x07, 0x0b, 0x07, 0x00, 0x1f};

void xor_blocks(char *block1, char *block2, char *result) {
    for (int i = 0; i < BLOCK_SIZE; i++) {
        result[i] = block1[i] ^ block2[i];
    }
}

bool compare_blocks(char *block1, char *block2) {
    for (int i = 0; i < BLOCK_SIZE; i++) {
        if (block1[i] != block2[i]) {
            return false;
        }
    }
    return true;
}

int main() {
    xor_blocks(xor_input, xor_key, xor_encrypted);

    // compare xor_encrypted with xor_check
    bool xor_encrypted_matches_xor_check = compare_blocks(xor_encrypted, xor_check);

    if (!xor_encrypted_matches_xor_check) {
        __DEBUGGER_BREAK();
        return 1;
    }

    // now, xor the output with the key again to get the original input
    xor_blocks(xor_encrypted, xor_key, xor_decrypted);

    // compare xor_decrypted with xor_input
    bool xor_decrypted_matches_xor_input = compare_blocks(xor_decrypted, xor_input);
    if (!xor_decrypted_matches_xor_input) {
        __DEBUGGER_BREAK();
        return 2;
    }

    return 0;
}
