// prime number counter

int is_prime(int m) {
    if (m <= 1) {
        return 0;
    }
    for (int i = 2; (i * i) <= m; i++) {
        if (m % i == 0) {
            return 0;
        }
    }
    return 1;
}

int main() {
    int result = 0;

    int n = 1000;
    
    // find all prime numbers <= n
    for (int i = 2; i <= n; i++) {
        if (is_prime(i)) {
            result++;
        }
    }

    return result;
}