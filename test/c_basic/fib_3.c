// dp fibonacci

#define TABLE_SIZE (64 + 1)
int table[TABLE_SIZE]; // max dp table size

int fib(int n) {
    // 1. init dp table
    for (int i = 0; i < TABLE_SIZE; i++) {
        table[i] = -1;
    }
    table[0] = 0;
    table[1] = 1;

    // 2. dp to calculate fib(n)
    for (int i = 2; i <= n; i++) {
        table[i] = table[i - 1] + table[i - 2];
    }

    return table[n];
}

int main() {
    // return fib(7); // 13
    // return fib(8); // 21
    // return fib(12); // 144
    return fib(26);
}
