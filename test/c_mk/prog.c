#define ARR_SZ 6
int arr[ARR_SZ] = {1, 2, 3, 4, 5, 6};

int main() {
    int sum = 0;
    for (int i = 0; i < ARR_SZ; i++) {
        sum += arr[i];
    }

    return sum;
}