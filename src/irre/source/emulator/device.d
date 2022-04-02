module irre.emulator.device;

public import irre.emulator.vm;
import irre.util;

/** represents a device for the IRRE VM machine */
abstract class Device {
    protected VirtualMachine vm;
    public int id;

    public void initialize(VirtualMachine vm, int id) {
        this.vm = vm;
        this.id = id;
    }

    public abstract WORD recieve(WORD command, WORD data);
}

abstract class MappedDevice : Device {
    public enum Command : WORD {
        MAP = 0xb0,
        UNMAP = 0xb1,
    }

    public UWORD mapped_block_size;
    public UWORD map_address = 0;
    @property bool mapped() {
        return map_address > 0;
    }

    this(UWORD block_size) {
        mapped_block_size = block_size;
    }

    public override WORD recieve(WORD command, WORD data) {
        switch (command) {
        case Command.MAP: {
                map_address = data;
                log_put(format("dev %d mapped BLOCK @%d (size: %d)", id, map_address, mapped_block_size));
                return 0;
            }
        case Command.UNMAP: {
                log_put(format("dev %d unmapped BLOCK @%d (size: %d)", id,
                        map_address, mapped_block_size));
                map_address = 0;
                return 0;
            }
        default:
            return 1; // unhandled
        }
    }
}
