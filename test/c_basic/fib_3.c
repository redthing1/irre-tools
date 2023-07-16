
int fib(int n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int main() {
    // return fib(7); // 13
    // return fib(8); // 21
    return fib(12); // 144
}
