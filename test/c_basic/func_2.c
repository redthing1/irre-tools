int se7en(int n) {
    if (n < 7) {
        return se7en(n + 1);
    } else {
        return n;
    }
}

int main() {
    int a = 5;
    int c = se7en(a);

    return c;
}