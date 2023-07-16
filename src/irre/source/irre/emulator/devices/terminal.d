module irre.emulator.devices.terminal;

import irre.emulator.device;
import std.string;
import std.stdio;
import irre.util;

class TerminalDevice : MappedDevice {
    enum Command : WORD {
        FLUSH = 0x10,
    }

    this() {
        super(256);
    }

    override void initialize(VirtualMachine vm, int id) {
        super.initialize(vm, id);
        log_put(format("[TERM] device initialized."));
    }

    override WORD recieve(WORD command, WORD data) {
        log_put(format("[TERM] recieved (comamnd: %08x, data: %d)", command, data));
        WORD result = super.recieve(command, data);
        if (result == 0)
            return result;

        switch (command) {
        case Command.FLUSH: {
                // read the buffer and write it to console
                auto buffer = new ubyte[mapped_block_size];
                vm.read_bytes(map_address, buffer, mapped_block_size);
                // write the buffer
                for (int i = 0; i < buffer.length; i++) {
                    if (buffer[i] == 0) break;
                    // print a character
                    auto ch = cast(char) buffer[i];
                    write(ch);
                }
                // clear the memory block
                // TODO
                return 0;
            }
        default:
            return 1; // unhandled
        }
    }
}
