module irre.emulator.devices.terminal;

import irre.emulator.device;
import std.string;
import std.stdio;

class TerminalDevice : Device {
    enum Command : WORD {
        MAP = 0x01,
    }

    override void initialize(VirtualMachine vm, int id) {
        writefln("[TERM] device initialized.");
    }

    override void recieve(WORD command, WORD data) {
        writefln("[TERM] recieved (comamnd: %d, data: %d)", command, data);
    }
}