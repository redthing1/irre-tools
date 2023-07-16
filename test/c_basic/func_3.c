int pyramid(int n) {
    if (n <= 1)
        return n;
    return n + pyramid(n - 1);
}

int main() {
    int a = 3;
    // pyramid(3) = 3 + pyramid(2) = 3 + 2 + pyramid(1) = 3 + 2 + 1 = 6
    int c = pyramid(a); // 6
    return c;
}