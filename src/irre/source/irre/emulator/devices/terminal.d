module irre.emulator.devices.terminal;

import irre.emulator.device;
import std.string;
import std.stdio;
import std.conv;
import irre.util;

class TerminalDevice : MappedDevice {
    enum Command : WORD {
        FLUSH = 0x10,
        READCHAR = 0x11,
        WRITECHAR = 0x12,
        READLN = 0x13,
        READF = 0x14,
        // SETCURSOR = 0x16,
        // GETCURSOR = 0x17,
        // SETATTR = 0x20,
    }

    this() {
        super(256);
    }

    override void initialize(VirtualMachine vm, int id) {
        super.initialize(vm, id);
        log_put(format("[TERM] device initialized."));
    }

    override WORD recieve(WORD command, WORD data) {
        log_put(format("[TERM] recieved (command: $%04x, data: %d)", command, data));
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
                for (int i = 0; i < mapped_block_size; i++)
                    buffer[i] = 0;
                vm.write_bytes(map_address, buffer, mapped_block_size);
                return 0;
            }
        case Command.READCHAR: {
                // read a key from the console
                auto ch = getchar();
                return ch;
            }
        case Command.WRITECHAR: {
                // write a character to the console
                auto ch = cast(char) data;
                putchar(ch);
                return 0;
            }
        case Command.READLN: {
            auto read_str = stdin.readln();
            auto read_data =  cast(ubyte[]) read_str.to!(char[]);
            vm.write_bytes(map_address, read_data, read_data.length);

            return cast(UWORD) read_data.length;
        }
        case Command.READF: {
            // read data from stdin
            auto buffer = new ubyte[mapped_block_size];
            auto read_data = stdin.rawRead(buffer);
            vm.write_bytes(map_address, read_data, read_data.length);

            return cast(UWORD) read_data.length;
        }
        default:
            return -1; // unhandled
        }
    }
}
