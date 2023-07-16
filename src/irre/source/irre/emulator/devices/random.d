module irre.emulator.devices.random;

import irre.emulator.device;
import std.string;
import std.stdio;
import irre.util;
import std.random : rndGen;

class RandomDevice : Device {
    override @property UWORD id() {
        return 0x00005005;
    }

    override WORD recieve(WORD command, WORD data) {
        log_put(format("[RANDOM] recieved (command: %08x, data: %08x)\n", command, data));

        UWORD out_address = command;
        UWORD out_length = data;

        // generate random bytes and store them in memory
        for (UWORD i = 0; i < out_length; i++) {
            BYTE rnd_byte = cast(BYTE) rndGen.front;
            vm.mem[out_address + i] = rnd_byte;
            rndGen.popFront();
        }
        log_put(format("[RANDOM] generated %d random bytes from %08x to %08x\n",
                out_length, out_address, out_address + out_length));

        return 0;
    }
}
