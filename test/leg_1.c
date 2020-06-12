#define true 1
#define false 0

int add_or_sub(int a, int b, int add) {
    if (add) {
        return a + b;
    } else {
        return a - b;
    }
}

int main() {
    int a = 3;
    int b = 4;
    int sum = add_or_sub(a, b, true);   // a + b = 7
    int dif = add_or_sub(a, b, false);  // a - b = -1
    return sum + dif; // 7 + -1 = 6
}
