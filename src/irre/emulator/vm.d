module irre.emulator.vm;

public import irre.encoding.instructions;
import irre.encoding.rega;
import std.algorithm.mutation;
import irre.emulator.device;

enum REGISTER_COUNT = 37;
enum MEMORY_SIZE = 64 * 1024; // 65K

class VirtualMachine {
    public UWORD[REGISTER_COUNT] reg;
    public BYTE[] mem;
    public bool executing = true;
    public bool took_branch = false; // whether the last instruction took a branch
    public ulong ticks;
    public Device[int] devices;
    private int device_id_counter = 0;

    public void initialize() {
        // allocate memory buffer
        mem = new BYTE[MEMORY_SIZE];

        // set SP to last word
        reg[Register.SP] = MEMORY_SIZE;

        // reset stats
        ticks = 0;

        // initialize all devices
        device_id_counter = 0;
        foreach (device; devices.byValue()) {
            device.initialize(this, device_id_counter++);
        }
    }

    public void attach_device(Device device) {
        auto dev_id = device_id_counter++;
        // initialize the device
        device.initialize(this, dev_id);

        devices[dev_id] = device;
    }

    public void detach_device(Device device) {
        devices.remove(device.id);
    }

    public RegaHeader load(const ubyte[] compiled_data) {
        auto decoder = new RegaDecoder();
        auto head = decoder.read_header(compiled_data[0 .. RegaHeader.OFFSET]);

        // copy the program into memory
        auto copy_size = head.program_size;
        auto program_slice = compiled_data[RegaHeader.OFFSET .. RegaHeader.OFFSET + copy_size];
        program_slice.copy(mem); // copy everything after the header

        return head;
    }

    /** decode the next instruction */
    public Instruction decode_instruction() {
        OpCode op = cast(OpCode) mem[reg[cast(int) Register.PC] + 0];
        ARG a1 = cast(ARG) mem[reg[cast(int) Register.PC] + 1];
        ARG a2 = cast(ARG) mem[reg[cast(int) Register.PC] + 2];
        ARG a3 = cast(ARG) mem[reg[cast(int) Register.PC] + 3];

        return Instruction(op, a1, a2, a3);
    }

    public void interrupt(UWORD code) {
        // TODO: handle interrupt
    }

    public bool execute_instruction(Instruction ins) {
        bool branched = false;
        switch (ins.op) {
        case OpCode.NOP:
            // literally do nothing
            break;
        case OpCode.ADD: {
                reg[ins.a1] = (cast(WORD) reg[ins.a2]) + (cast(WORD) reg[ins.a3]);
                break;
            }
        case OpCode.SUB: {
                reg[ins.a1] = (cast(WORD) reg[ins.a2]) - (cast(WORD) reg[ins.a3]);
                break;
            }
        case OpCode.AND: {
                reg[ins.a1] = reg[ins.a2] & reg[ins.a3];
                break;
            }
        case OpCode.ORR: {
                reg[ins.a1] = reg[ins.a2] | reg[ins.a3];
                break;
            }
        case OpCode.XOR: {
                reg[ins.a1] = reg[ins.a2] ^ reg[ins.a3];
                break;
            }
        case OpCode.NOT: {
                reg[ins.a1] = ~reg[ins.a2];
                break;
            }
        case OpCode.LSH: {
                immutable WORD shift = reg[ins.a3];
                if (shift >= 0) {
                    reg[ins.a1] = reg[ins.a2] << shift;
                } else {
                    reg[ins.a1] = reg[ins.a2] >> -shift;
                }
                break;
            }
        case OpCode.ASH: {
                immutable WORD shift = reg[ins.a3];
                if (shift >= 0) {
                    reg[ins.a1] = (cast(WORD) reg[ins.a2]) << shift;
                } else {
                    reg[ins.a1] = (cast(WORD) reg[ins.a2]) >> -shift;
                }
                break;
            }
        case OpCode.TCU: {
                WORD sign = 0;
                if (reg[ins.a2] > reg[ins.a3]) {
                    sign = 1;
                } else if (reg[ins.a2] < reg[ins.a3]) {
                    sign = -1;
                }
                reg[ins.a1] = sign;
                break;
            }
        case OpCode.TCS: {
                WORD sign = 0;
                if ((cast(WORD) reg[ins.a2]) > (cast(WORD) reg[ins.a3])) {
                    sign = 1;
                } else if ((cast(WORD) reg[ins.a2]) < (cast(WORD) reg[ins.a3])) {
                    sign = -1;
                }
                reg[ins.a1] = sign;
                break;
            }
        case OpCode.SET: {
                immutable short signed_val = cast(short)(ins.a2 | (ins.a3 << 8));
                immutable WORD signext_imm = signed_val;
                reg[ins.a1] = signext_imm;
                break;
            }
        case OpCode.MOV: {
                reg[ins.a1] = reg[ins.a2];
                break;
            }
        case OpCode.LDW: {
                immutable UWORD addr = reg[ins.a2];
                immutable byte offset = ins.a3;
                reg[ins.a1] = mem[addr + offset + 0] << 0 | mem[addr + offset + 1]
                    << 8 | mem[addr + offset + 2] << 16 | mem[addr + offset + 3] << 24;
                break;
            }
        case OpCode.STW: {
                immutable UWORD addr = reg[ins.a2];
                immutable byte offset = ins.a3;
                mem[addr + offset + 0] = (reg[ins.a1] >> 0) & 0xff;
                mem[addr + offset + 1] = (reg[ins.a1] >> 8) & 0xff;
                mem[addr + offset + 2] = (reg[ins.a1] >> 16) & 0xff;
                mem[addr + offset + 3] = (reg[ins.a1] >> 24) & 0xff;
                break;
            }
        case OpCode.JMI: {
                immutable UWORD addr = cast(UWORD) ((ins.a1) | (ins.a2 << 8) | (ins.a3) << 16);
                reg[Register.PC] = addr;
                branched = true;
                break;
            }
        case OpCode.JMP: {
                immutable UWORD addr = reg[ins.a1];
                reg[Register.PC] = addr;
                branched = true;
                break;
            }
        case OpCode.BIF: {
                immutable UWORD addr = cast(UWORD) (ins.a2);
                // branch to vB if rA == vC
                immutable WORD tc = reg[ins.a1]; // reg value
                immutable byte check = ins.a3; // imm value
                bool cond = false;
                if (check < 0) cond = tc <= check;
                if (check > 0) cond = tc >= check;
                if (check == 0) cond = tc == 0;
                if (cond) {
                    reg[Register.PC] = addr;
                    branched = true;
                }
                break;
            }
        case OpCode.BVE: {
                immutable UWORD addr = reg[ins.a1];
                // branch to @rA if rB == vC
                immutable WORD a = reg[ins.a2];
                immutable byte b = ins.a3;
                if (a == b) {
                    reg[Register.PC] = addr;
                    branched = true;
                }
                break;
            }
        case OpCode.BVN: {
                immutable UWORD addr = reg[ins.a1];
                // branch to @rA if rB != vC
                immutable WORD a = reg[ins.a2];
                immutable byte b = ins.a3;
                if (a != b) {
                    reg[Register.PC] = addr;
                    branched = true;
                }
                break;
            }
        case OpCode.CAL: {
                immutable UWORD addr = reg[ins.a1];
                // store next instruction in LR
                reg[Register.LR] = reg[Register.PC] + cast(uint) INSTRUCTION_SIZE;
                reg[Register.PC] = addr;
                branched = true;
                break;
            }
        case OpCode.RET: {
                immutable UWORD addr = reg[Register.LR];
                if (addr == 0) {
                    // attempted to RET to 0
                    // this is a HALT FAULT
                    executing = false;
                }
                reg[Register.PC] = addr;
                branched = true;
                reg[Register.LR] = 0; // clear LR
                break;
            }
        case OpCode.SND: {
                immutable UWORD device_data = reg[ins.a1];
                immutable UWORD device_id = reg[ins.a2];
                immutable UWORD device_command = reg[ins.a3];

                // get matching device
                if (device_id in devices) {
                    auto device = devices[device_id];
                    immutable WORD result = device.recieve(device_command, device_data);
                    reg[ins.a1] = result;
                } else {
                    // requested a device that was not found
                    // TODO: UNK_DEVICE interrupt
                }

                break;
            }
        case OpCode.INT: {
                UWORD code = reg[ins.a1];
                interrupt(code);
                break;
            }
        case OpCode.HLT:
            executing = false;
            break;
        default:
            // unhandled op
            break;
        }
        if (!branched) {
            reg[cast(int) Register.PC] += cast(uint) INSTRUCTION_SIZE; // increment PC
        }
        return branched;
    }

    public bool step() {
        // fetch instruction
        auto instruction = decode_instruction();
        // execute the instruction
        took_branch = execute_instruction(instruction);
        ticks++;
        return executing; // execution state
    }

    public void read_words(UWORD addr, WORD[] buffer, size_t count) {
        for (int i = 0; i < count; i += 1) {
            auto mem_i = addr + i * WORD.sizeof;
            buffer[i] = mem[mem_i + 0] << 0 | mem[mem_i + 1] << 8 | mem[mem_i + 2]
                << 16 | mem[mem_i + 3] << 24;
        }
    }

    public void read_bytes(UWORD addr, ubyte[] buffer, size_t count) {
        for (int i = 0; i < count; i += 1) {
            auto mem_i = addr + i;
            buffer[i] = mem[mem_i];
        }
    }
}
