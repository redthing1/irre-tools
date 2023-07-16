module irre.emulator.vm;

import irre.encoding.instructions;
import irre.encoding.rega;
import std.algorithm.mutation;

enum REGISTER_COUNT = 32;
enum MEMORY_SIZE = 64 * 1024; // 65K

class VirtualMachine {
    public UWORD[REGISTER_COUNT] reg;
    public BYTE[] mem;
    public bool executing;
    public ulong ticks;

    this() {
        initialize();
    }

    public void initialize() {
        // allocate memory buffer
        mem = new BYTE[MEMORY_SIZE];

        // set RSP to last word
        reg[Register.RSP] = MEMORY_SIZE - WORD.sizeof;

        // reset stats
        ticks = 0;
    }

    RegaHeader load(const ubyte[] compiled_data) {
        auto decoder = new RegaDecoder();
        auto head = decoder.read_header(compiled_data[0 .. RegaHeader.OFFSET]);

        // copy the program into memory
        auto copy_size = head.data_size + head.code_size;
        auto program_slice = compiled_data[RegaHeader.OFFSET .. RegaHeader.OFFSET + copy_size];
        program_slice.copy(mem);

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

    void execute_instruction(Instruction instr) {
        reg[cast(int) Register.PC] += INSTRUCTION_SIZE; // increment PC
    }

    bool step() {
        // fetch instruction
        auto instruction = decode_instruction();
        // execute the instruction
        execute_instruction(instruction);
        return executing; // execution state
    }
}
