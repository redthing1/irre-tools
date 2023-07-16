module irre.emulator.vm;

import irre.encoding.instructions;
import irre.encoding.rega;
import std.algorithm.mutation;

enum REGISTER_COUNT = 32;
enum MEMORY_SIZE = 64 * 1024; // 65K

class VirtualMachine {
    public UWORD[REGISTER_COUNT] reg;
    public BYTE[] mem;
    public bool executing = true;
    public ulong ticks;

    this() {
        initialize();
    }

    public void initialize() {
        // allocate memory buffer
        mem = new BYTE[MEMORY_SIZE];

        // set SP to last word
        reg[Register.SP] = MEMORY_SIZE;

        // reset stats
        ticks = 0;
    }

    RegaHeader load(const ubyte[] compiled_data) {
        auto decoder = new RegaDecoder();
        auto head = decoder.read_header(compiled_data[0 .. RegaHeader.OFFSET]);

        // copy the program into memory
        auto copy_size = head.data_size + head.code_size;
        auto program_slice = compiled_data[RegaHeader.OFFSET .. RegaHeader.OFFSET + copy_size];
        program_slice.copy(mem); // copy everything after the header

        return head;
    }

    /** decode the next instruction */
    Instruction decode_instruction() {
        OpCode op = cast(OpCode) mem[reg[cast(int) Register.PC] + 0];
        ARG a1 = cast(ARG) mem[reg[cast(int) Register.PC] + 1];
        ARG a2 = cast(ARG) mem[reg[cast(int) Register.PC] + 2];
        ARG a3 = cast(ARG) mem[reg[cast(int) Register.PC] + 3];

        return Instruction(op, a1, a2, a3);
    }

    void interrupt(UWORD code) {
        // TODO: handle interrupt
    }

    void execute_instruction(Instruction ins) {
        bool branched = false;
        switch (ins.op) {
        case OpCode.NOP:
            // literally do nothing
            break;
        case OpCode.ADD: {
                reg[ins.a1] = reg[ins.a2] + reg[ins.a3];
                break;
            }
        case OpCode.SUB: {
                reg[ins.a1] = reg[ins.a2] - reg[ins.a3];
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
                reg[ins.a1] = ins.a2 | (ins.a3 << 8);
                break;
            }
        case OpCode.MOV: {
                reg[ins.a1] = reg[ins.a2];
                break;
            }
        case OpCode.LDW: {
                immutable UWORD addr = reg[ins.a2];
                immutable UWORD offset = ins.a3;
                reg[ins.a1] = mem[addr + offset + 0] << 0 | mem[addr + offset + 1]
                    << 8 | mem[addr + offset + 2] << 16 | mem[addr + offset + 3] << 24;
                break;
            }
        case OpCode.STW: {
                immutable UWORD addr = reg[ins.a2];
                immutable UWORD offset = ins.a3;
                mem[addr + offset + 0] = (reg[ins.a1] >> 0) & 0xff;
                mem[addr + offset + 1] = (reg[ins.a1] >> 8) & 0xff;
                mem[addr + offset + 2] = (reg[ins.a1] >> 16) & 0xff;
                mem[addr + offset + 3] = (reg[ins.a1] >> 24) & 0xff;
                break;
            }
        case OpCode.JMI: {
                immutable UWORD addr = ins.a1;
                reg[Register.PC] = addr;
                branched = true;
                break;
            }
        case OpCode.BIF: {
                immutable UWORD addr = ins.a2;
                // branch to vB if rA == vC
                immutable UWORD tc = reg[ins.a1];
                if (tc == ins.a3) {
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
    }

    bool step() {
        // fetch instruction
        auto instruction = decode_instruction();
        // execute the instruction
        execute_instruction(instruction);
        ticks++;
        return executing; // execution state
    }
}
