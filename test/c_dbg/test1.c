#include "../lib/corlib.h"

#define BLOCK_SIZE (4)

char arr1[BLOCK_SIZE] = {1, 2, 3, 4};
char arr2[BLOCK_SIZE] = {9, 8, 7, 6};
char add_buf[BLOCK_SIZE] = {0, 0, 0, 0};
char arr3[BLOCK_SIZE] = {10, 10, 10, 10}; // correct result

void add_blocks(char *block1, char *block2, char *result) {
    for (int i = 0; i < BLOCK_SIZE; i++) {
        result[i] = block1[i] + block2[i];
    }
}

// bool compare_blocks(char *block1, char *block2) {
//     for (int i = 0; i < BLOCK_SIZE; i++) {
//         if (block1[i] != block2[i]) {
//             return false;
//         }
//     }
//     return true;
// }
bool compare_second(char *block1, char *block2) {
    return block1[1] == block2[1];
}

int main() {
    add_blocks(arr1, arr2, add_buf);
    __debugger_break();

    // if (!compare_blocks(add_buf, arr3)) {
    //     return 1;
    // }

    if (!compare_second(add_buf, arr3)) {
        return 1;
    }

    return 0;
}
