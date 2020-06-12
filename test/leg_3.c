
int main() {
    int c = 0;
    #pragma nounroll
    for (int i = 0; i < 1; i++) {
        c += 0x10;
    }
    return c;
}
