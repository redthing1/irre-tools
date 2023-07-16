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
    // basics (core set 1)
    NOP = 0x00, // nop
    ADD = 0x01, // add
    SUB = 0x02, // sub
    AND = 0x03, // and
    ORR = 0x04, // orr
    XOR = 0x05, // xor
    NOT = 0x06, // not
    LSH = 0x07, // logical shift
    ASH = 0x08, // arithmetic shift
    TCU = 0x09,
    TCS = 0x0a,
    SET = 0x0b, // set lower 16
    MOV = 0x0c, // move
    LDW = 0x0d, // load word
    STW = 0x0e, // store word
    LDB = 0x0f, // load byte
    STB = 0x10, // store byte

    JMI = 0x20, // unconditional jump (imm)
    JMP = 0x21, // unconditional jump (reg)
    BVE = 0x24, // branch if value-equal (reg)
    BVN = 0x25, // branch if value-not-equal (reg)
    CAL = 0x2a, // branch, link in LR
    RET = 0x2b, // jump to LR

    MUL = 0x30, // multiply
    DIV = 0x31, // divide
    MOD = 0x32, // modulo

    ASI = 0x40, // add shifted immediate
    SUP = 0x41, // set upper 16
    SXT = 0x42, // sign extended move

    INT = 0xf0, // interrupt
    SND = 0xfd, // send
    HLT = 0xff, // halt
}

enum REGISTER_COUNT = 37;
enum Register : ARG {
    R0 = 0x00,
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
    R29 = 0x1d,
    R30 = 0x1e,
    R31 = 0x1f,
    // - special registers
    PC = 0x20, // program counter (32)
    LR = 0x21, // return address (33)
    AD = 0x22, // temp 1 (34)
    AT = 0x23, // temp 2 (35)
    SP = 0x24, // stack pointer (36)
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
    REG_IMM_IMM = REG_IMM | K_I3,
    REG_REG_IMM = REG_REG | K_I3,
    REG_REG_REG = REG_REG | K_R3,
}

enum ImmediatePos : WORD {
    NONE = (0 << 0),
    A = (1 << 0),
    B = (1 << 1),
    C = (1 << 2),
    D = (1 << 3),
    E = (1 << 4),
    F = (1 << 5),
    G = (1 << 6),
    H = (1 << 7),

    BC = B | C,

    ABC = A | B | C,
}

/** binary-packed representation of an instruction word */
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
            case OpCode.LDW: return InstructionInfo(OpCode.LDW, Operands.REG_REG_IMM, 1);
            case OpCode.STW: return InstructionInfo(OpCode.STW, Operands.REG_REG_IMM, 1);
            case OpCode.LDB: return InstructionInfo(OpCode.LDB, Operands.REG_REG_IMM, 1);
            case OpCode.STB: return InstructionInfo(OpCode.STB, Operands.REG_REG_IMM, 1);
            
            // IRRE instruction set
            case OpCode.JMI: return InstructionInfo(OpCode.JMI, Operands.IMM, 1);
            case OpCode.JMP: return InstructionInfo(OpCode.JMP, Operands.REG, 1);
            // case OpCode.BIF: return InstructionInfo(OpCode.BIF, Operands.REG_IMM_IMM, 1);
            case OpCode.BVE: return InstructionInfo(OpCode.BVE, Operands.REG_REG_IMM, 1);
            case OpCode.BVN: return InstructionInfo(OpCode.BVN, Operands.REG_REG_IMM, 1);
            case OpCode.CAL: return InstructionInfo(OpCode.CAL, Operands.REG, 1);
            case OpCode.RET: return InstructionInfo(OpCode.RET, Operands.NONE, 1);
            case OpCode.HLT: return InstructionInfo(OpCode.HLT, Operands.NONE, 1);
            case OpCode.INT: return InstructionInfo(OpCode.INT, Operands.IMM, 1);

            // IRRE math extensions
            case OpCode.MUL: return InstructionInfo(OpCode.MUL, Operands.REG_REG_REG, 1);
            case OpCode.DIV: return InstructionInfo(OpCode.DIV, Operands.REG_REG_REG, 1);
            case OpCode.MOD: return InstructionInfo(OpCode.MOD, Operands.REG_REG_REG, 1);

            // IRRE utility extensions
            case OpCode.ASI: return InstructionInfo(OpCode.ASI, Operands.REG_IMM_IMM, 1);
            case OpCode.SUP: return InstructionInfo(OpCode.SUP, Operands.REG_IMM, 1);
            case OpCode.SXT: return InstructionInfo(OpCode.SXT, Operands.REG_REG, 1);

            // REGULAR_EXT device api
            case OpCode.SND: return InstructionInfo(OpCode.SND, Operands.REG_REG_REG, 1);
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
