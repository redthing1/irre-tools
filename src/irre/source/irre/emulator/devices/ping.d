module irre.emulator.devices.ping;

import irre.emulator.device;
import std.string;
import std.stdio;
import irre.util;

class PingDevice : Device {
    enum Command : WORD {
        PING = 0x01,
        COUNT = 0x02,
    }

    private int ping_count = 0;

    override WORD recieve(WORD command, WORD data) {
        log_put(format("[PING] recieved (command: %d, data: %d)", command, data));

        switch (command) {
        case Command.PING: {
                ping_count++;
                return 0; // success
            }
        case Command.COUNT: {
                return ping_count;
            }
        default:
            break;
        }

        return -1; // unhandled
    }
}
