#include "../lib/corlib.h"

const int DEMO_DEVICE_PING = 0x00001000;

int main() {
    int ret = __device_send(DEMO_DEVICE_PING, 0, 0x1234);
    return ret;
}