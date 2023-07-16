module irre.emulator.devices.ping;

import irre.emulator.device;
import std.string;
import std.stdio;

class PingDevice : Device {
    enum Command : WORD {
        PING = 0x01,
    }

    override WORD recieve(WORD command, WORD data) {
        writefln("[PING] recieved (command: %d, data: %d)", command, data);
        return 0; // success
    }
}
