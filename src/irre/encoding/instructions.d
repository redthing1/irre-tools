module irre.encoding.instructions;

import std.typecons;

// integral types
alias BYTE = byte;
alias WORD = int;
alias UWORD = uint;

// sizes
alias ARG = BYTE;
enum INSTRUCTION_SIZE = WORD.sizeof; // 4-byte (WORD) instructions

enum OpCode : ARG {
    NOP = 0x00,
    ADD = 0x01,
    SUB = 0x02,
    AND = 0x03,
    ORR = 0x04,
    XOR = 0x05,
    NOT = 0x06,
    LSH = 0x07,
    ASH = 0x08,
    TCU = 0x09,
    TCS = 0x0a,
    SET = 0x0b,
    MOV = 0x0c,
    LDW = 0x0d,
    STW = 0x0e,
    LDB = 0x0f,
    STB = 0x10,
}

enum Operands {
    NONE = 0,
    K_I1 = 1 << 1,
    K_R1 = 1 << 2,
    K_I2 = 1 << 3,
    K_R2 = 1 << 4,
    K_I3 = 1 << 5,
    K_R3 = 1 << 6,
    IMM = K_I1,
    REG = K_R1,
    REG_IMM = REG | K_I2,
    REG_REG = REG | K_R2,
    REG_REG_IMM = REG_REG | K_I3,
    REG_REG_REG = REG_REG | K_R3,
}

struct Instruction {
    OpCode op;
    ARG a1, a2, a3;
}

struct InstructionInfo {
    OpCode op;
    Operands operands;
    int size; // size (in words)
}

class InstructionMetadata {
    static Nullable!InstructionInfo get_info(string mnemonic) {
        // TODO: parse op from mnemonic
        return get_info(OpCode.NOP);
    }

    static Nullable!InstructionInfo get_info(OpCode op) {
        // TODO
    }
}
