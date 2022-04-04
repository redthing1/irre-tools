
// #define TABLE_SIZE (32 * 1024)
// #define TABLE_SIZE (1 * 512)
#define TABLE_SIZE (512)
int table[TABLE_SIZE];

int seed;
int rng_a = 0xffffffff;
int rng_c = 12345;
int rng_m = 1103515245;

int rand() {
    seed = (rng_a * seed + rng_c) % rng_m;
    return seed;
}

void fill(int* arr, int size) {
    for (int i = 0; i < size; i++) {
        arr[i] = rand();
    }
}

void shuffle(int* arr, int size, int iter) {
    // do some shuffling
    for (int i = 0; i < iter; i++) {
        int a = rand() % size;
        int b = rand() % size;
        int tmp = arr[a];
        arr[a] = arr[b];
        arr[b] = tmp;
    }
}

int sum(int* arr, int size) {
    int s = 0;
    for (int i = 0; i < size; i++) {
        s += arr[i];
    }
    return s;
}

int main() {
    seed = 8289893;

    fill(table, TABLE_SIZE);

    shuffle(table, TABLE_SIZE, 1);

    return sum(table, TABLE_SIZE);
}
