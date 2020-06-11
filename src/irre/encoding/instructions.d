module irre.encoding.instructions;

import std.typecons;
import std.conv;
import std.uni;
import std.range;
import std.traits;
import std.algorithm.searching;
import std.stdio;

// integral types
alias BYTE = ubyte;
alias WORD = int;
alias UWORD = uint;

// sizes
alias ARG = BYTE;
enum INSTRUCTION_SIZE = WORD.sizeof; // 4-byte (WORD) instructions

enum OpCode : ARG {
    // set 1
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

    // set 2
    HLT = 0xff,
    INT = 0x71,
}

enum Register : ARG {
    // R0 = 0x00,
    PC = 0x00,
    R1 = 0x01,
    R2 = 0x02,
    R3 = 0x03,
    R4 = 0x04,
    R5 = 0x05,
    R6 = 0x06,
    R7 = 0x07,
    R8 = 0x08,
    R9 = 0x09,
    R10 = 0x0a,
    R11 = 0x0b,
    R12 = 0x0c,
    R13 = 0x0d,
    R14 = 0x0e,
    R15 = 0x0f,
    R16 = 0x10,
    R17 = 0x11,
    R18 = 0x12,
    R19 = 0x13,
    R20 = 0x14,
    R21 = 0x15,
    R22 = 0x16,
    R23 = 0x17,
    R24 = 0x18,
    R25 = 0x19,
    R26 = 0x1a,
    R27 = 0x1b,
    R28 = 0x1c,
    // R29 = 0x1d,
    AD = 0x1d,
    // R30 = 0x1e,
    AT = 0x1e,
    // R31 = 0x1f,
    SP = 0x1f,
    RX = 0xff,
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

class InstructionEncoding {
    public static Nullable!InstructionInfo get_info(string mnemonic) {
        // normalize mnemonic
        mnemonic = toUpper(mnemonic);

        // parse op from mnemonic
        auto matched_mnem = Nullable!OpCode.init;
        foreach (immutable mnem; [EnumMembers!OpCode]) {
            if (to!string(mnem) == mnemonic) {
                matched_mnem = Nullable!OpCode(mnem);
            }
        }

        if (matched_mnem.isNull) {
            return Nullable!InstructionInfo.init;
        }
        return get_info(matched_mnem.get());
    }

    public static Nullable!InstructionInfo get_info(OpCode op) {
        auto info = get_info_default(op);
        if (info.size == 0) {
            return Nullable!InstructionInfo.init; // no info
        }
        return Nullable!InstructionInfo(info);
    }

    private static get_info_default(OpCode op) {
        switch (op) {
            // dfmt off
            // REGULARVM instruction set
            case OpCode.NOP: return InstructionInfo(OpCode.NOP, Operands.NONE, 1);
            case OpCode.ADD: return InstructionInfo(OpCode.ADD, Operands.REG_REG_REG, 1);
            case OpCode.SUB: return InstructionInfo(OpCode.SUB, Operands.REG_REG_REG, 1);
            case OpCode.AND: return InstructionInfo(OpCode.AND, Operands.REG_REG_REG, 1);
            case OpCode.ORR: return InstructionInfo(OpCode.ORR, Operands.REG_REG_REG, 1);
            case OpCode.XOR: return InstructionInfo(OpCode.XOR, Operands.REG_REG_REG, 1);
            case OpCode.NOT: return InstructionInfo(OpCode.NOT, Operands.REG_REG, 1);
            case OpCode.LSH: return InstructionInfo(OpCode.LSH, Operands.REG_REG_REG, 1);
            case OpCode.ASH: return InstructionInfo(OpCode.ASH, Operands.REG_REG_REG, 1);
            case OpCode.TCU: return InstructionInfo(OpCode.TCU, Operands.REG_REG_REG, 1);
            case OpCode.TCS: return InstructionInfo(OpCode.TCS, Operands.REG_REG_REG, 1);
            case OpCode.SET: return InstructionInfo(OpCode.SET, Operands.REG_IMM, 1);
            case OpCode.MOV: return InstructionInfo(OpCode.MOV, Operands.REG_REG, 1);
            case OpCode.LDW: return InstructionInfo(OpCode.LDW, Operands.REG_REG, 1);
            case OpCode.STW: return InstructionInfo(OpCode.STW, Operands.REG_REG, 1);
            case OpCode.LDB: return InstructionInfo(OpCode.LDB, Operands.REG_REG, 1);
            case OpCode.STB: return InstructionInfo(OpCode.STB, Operands.REG_REG, 1);
            // REGULAR_AD instruction set
            case OpCode.HLT: return InstructionInfo(OpCode.HLT, Operands.NONE, 1);
            case OpCode.INT: return InstructionInfo(OpCode.INT, Operands.REG, 1);
            // dfmt on
        default:
            auto info = InstructionInfo();
            info.size = 0;
            return info;
        }
    }

    public static Register get_register(string mnemonic) {
        // normalize mnemonic
        mnemonic = toUpper(mnemonic);
        return to!Register(mnemonic);
    }
}
