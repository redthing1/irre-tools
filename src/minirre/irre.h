
#ifndef _IRRE_H_
#define _IRRE_H_

#include <stdbool.h>
#include <stdint.h>

#define IRRE_INSTRUCTION_SIZE 4

#define IRRE_BYTE int8_t
#define IRRE_UBYTE uint8_t
#define IRRE_WORD int32_t
#define IRRE_UWORD uint32_t

#define IRRE_ARG IRRE_UBYTE
#define IRRE_OPCODE IRRE_UBYTE

/* OPCODE and REG definitions */

// opcodes
typedef enum {
  OP_NOP = 0x00,
  OP_ADD = 0x01,
  OP_SUB = 0x02,
  OP_AND = 0x03,
  OP_ORR = 0x04,
  OP_XOR = 0x05,
  OP_NOT = 0x06,
  OP_LSH = 0x07,
  OP_ASH = 0x08,
  OP_TCU = 0x09,
  OP_TCS = 0x0a,
  OP_SET = 0x0b,
  OP_MOV = 0x0c,
  OP_LDW = 0x0d,
  OP_STW = 0x0e,
  OP_LDB = 0x0f,
  OP_STB = 0x10,
  OP_JMI = 0x20,
  OP_JMP = 0x21,
  OP_BVE = 0x24,
  OP_BVN = 0x25,
  OP_CAL = 0x2a,
  OP_RET = 0x2b,
  OP_MUL = 0x30,
  OP_DIV = 0x31,
  OP_MOD = 0x32,
  OP_SIA = 0x40,
  OP_SUP = 0x41,
  OP_SXT = 0x42,
  OP_SEQ = 0x43,
  OP_INT = 0xf0,
  OP_SND = 0xfd,
  OP_HLT = 0xff
} IrreOpcode;

// registers
typedef enum {
  REG_R0 = 0x00,
  REG_R1 = 0x01,
  REG_R2 = 0x02,
  REG_R3 = 0x03,
  REG_R4 = 0x04,
  REG_R5 = 0x05,
  REG_R6 = 0x06,
  REG_R7 = 0x07,
  REG_R8 = 0x08,
  REG_R9 = 0x09,
  REG_R10 = 0x0a,
  REG_R11 = 0x0b,
  REG_R12 = 0x0c,
  REG_R13 = 0x0d,
  REG_R14 = 0x0e,
  REG_R15 = 0x0f,
  REG_R16 = 0x10,
  REG_R17 = 0x11,
  REG_R18 = 0x12,
  REG_R19 = 0x13,
  REG_R20 = 0x14,
  REG_R21 = 0x15,
  REG_R22 = 0x16,
  REG_R23 = 0x17,
  REG_R24 = 0x18,
  REG_R25 = 0x19,
  REG_R26 = 0x1a,
  REG_R27 = 0x1b,
  REG_R28 = 0x1c,
  REG_R29 = 0x1d,
  REG_R30 = 0x1e,
  REG_R31 = 0x1f,
  REG_PC = 0x20,
  REG_LR = 0x21,
  REG_AD = 0x22,
  REG_AT = 0x23,
  REG_SP = 0x24
} IrreRegister;
#define IRRE_REGISTER_COUNT 37

typedef struct {
  IRRE_OPCODE opcode;
  IRRE_ARG a1, a2, a3;
} IrreInstruction;

typedef enum {
  IRRE_ERR_UNKNOWN = 0x00,
  IRRE_ERR_ILLEGAL_OPCODE = 0x10,
  IRRE_ERR_INVALID_MEMORY_ACCESS = 0x20,
} IrreError;

typedef struct {
  IRRE_UWORD r[IRRE_REGISTER_COUNT]; // registers
  IRRE_UBYTE *m;                     // memory
  IRRE_UWORD mem_size;              // memory size
  void (*interrupt_handler)(IRRE_UWORD);
  void (*error_handler)(IrreError);
  void (*device_handler)(IRRE_UWORD, IRRE_UWORD, IRRE_UWORD);
  bool executing;
} IrreState;

/** initialize a new vm state */
void irre_init(IrreState *state);

/** load a program into memory */
void irre_load(IrreState *state, IRRE_UBYTE *program, IRRE_UWORD size);

/** fetch the next instruction */
IRRE_WORD irre_fetch(IrreState *state);

/** decode an instruction */
IrreInstruction irre_decode(IRRE_WORD word);

/** execute an instruction */
void irre_execute(IrreState *state, IrreInstruction instruction);

/** execute a vm step */
void irre_step(IrreState *state);

#endif // _IRRE_H_
