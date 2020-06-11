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
    int sum = add_or_sub(a, b, true);
    int dif = add_or_sub(a, b, false);
}
