#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "irre.h"

void irre_init(IrreState *state) {
  // initialize registers
  memset(state->r, 0, sizeof(state->r));
  // initialize memory
  memset(state->m, 0, state->mem_size);
  // initialize other fields
  state->executing = false;
}

void irre_load(IrreState *state, IRRE_UBYTE *program, IRRE_UWORD size) {
  // copy the program into memory
  memcpy(state->m, program, size);
  // set the program counter
  state->r[REG_PC] = 0;
  // set the link register
  state->r[REG_LR] = 0;
  // set the stack pointer
  state->r[REG_SP] = state->mem_size - 1;
  // set the executing flag
  state->executing = true;
}

IrreInstruction irre_decode(IRRE_WORD word) {
  IrreInstruction instruction;
  instruction.opcode = (IRRE_OPCODE)(word >> 24);
  instruction.a1 = (IRRE_ARG)((word >> 16) & 0xff);
  instruction.a2 = (IRRE_ARG)((word >> 8) & 0xff);
  instruction.a3 = (IRRE_ARG)(word & 0xff);
  return instruction;
}

IRRE_WORD irre_fetch(IrreState *state) {
  IRRE_UWORD fetch_addr = state->r[REG_PC];
  if (fetch_addr + IRRE_INSTRUCTION_SIZE >= state->mem_size) {
    if (state->error_handler) {
      state->error_handler(IRRE_ERR_INVALID_MEMORY_ACCESS);
    }
    return 0;
  }
  IRRE_WORD word = state->m[fetch_addr + 0] << 24 |
                   state->m[fetch_addr + 1] << 16 |
                   state->m[fetch_addr + 2] << 8 | state->m[fetch_addr + 3];
  return word;
}

void irre_step(IrreState *state) {
  // fetch the next instruction
  IRRE_WORD raw_instruction = irre_fetch(state);

  // decode the instruction
  IrreInstruction instruction = irre_decode(raw_instruction);

  // execute the instruction
  irre_execute(state, instruction);
}

void irre_execute(IrreState *state, IrreInstruction instruction) {
  bool branch = false;
  switch (instruction.opcode) {
  case OP_NOP: {
    break;
  }
  case OP_ADD: {
    state->r[instruction.a1] =
        state->r[instruction.a2] + state->r[instruction.a3];
    break;
  }
  case OP_SUB: {
    state->r[instruction.a1] =
        state->r[instruction.a2] - state->r[instruction.a3];
    break;
  }
  case OP_AND: {
    state->r[instruction.a1] =
        state->r[instruction.a2] & state->r[instruction.a3];
    break;
  }
  case OP_ORR: {
    state->r[instruction.a1] =
        state->r[instruction.a2] | state->r[instruction.a3];
    break;
  }
  case OP_XOR: {
    state->r[instruction.a1] =
        state->r[instruction.a2] ^ state->r[instruction.a3];
  }
  case OP_NOT: {
    state->r[instruction.a1] = ~state->r[instruction.a2];
    break;
  }
  case OP_LSH: {
    IRRE_WORD shift = state->r[instruction.a3];
    if (shift >= 0) {
      state->r[instruction.a1] = state->r[instruction.a2] << shift;
    } else {
      state->r[instruction.a1] = state->r[instruction.a2] >> -shift;
    }
    break;
  }
  case OP_ASH: {
    IRRE_WORD shift = state->r[instruction.a3];
    if (shift >= 0) {
      state->r[instruction.a1] = (IRRE_WORD)state->r[instruction.a2] << shift;
    } else {
      state->r[instruction.a1] = (IRRE_WORD)state->r[instruction.a2] >> -shift;
    }
    break;
  }
  case OP_TCU: {
    IRRE_WORD sign = 0;
    if (state->r[instruction.a2] > state->r[instruction.a3]) {
      sign = 1;
    } else if (state->r[instruction.a2] < state->r[instruction.a3]) {
      sign = -1;
    }
    state->r[instruction.a1] = sign;
    break;
  }
  case OP_TCS: {
    IRRE_WORD sign = 0;
    if ((IRRE_WORD)state->r[instruction.a2] >
        (IRRE_WORD)state->r[instruction.a3]) {
      sign = 1;
    } else if ((IRRE_WORD)state->r[instruction.a2] <
               (IRRE_WORD)state->r[instruction.a3]) {
      sign = -1;
    }
    state->r[instruction.a1] = sign;
    break;
  }
  case OP_SET: {
    state->r[instruction.a1] = (instruction.a2 | (instruction.a3 << 8));
    break;
  }
  case OP_MOV: {
    state->r[instruction.a1] = state->r[instruction.a2];
    break;
  }
  case OP_LDW: {
    IRRE_UWORD addr = state->r[instruction.a2];
    IRRE_BYTE offset = instruction.a3;
    if (addr + offset + 3 >= state->mem_size) {
      if (state->error_handler) {
        state->error_handler(IRRE_ERR_INVALID_MEMORY_ACCESS);
      }
      break;
    }
    state->r[instruction.a1] =
        state->m[addr + offset + 0] << 0 | state->m[addr + offset + 1] << 8 |
        state->m[addr + offset + 2] << 16 | state->m[addr + offset + 3] << 24;
    break;
  }
  case OP_STW: {
    IRRE_UWORD addr = state->r[instruction.a2];
    IRRE_BYTE offset = instruction.a3;
    if (addr + offset + 3 >= state->mem_size) {
      if (state->error_handler) {
        state->error_handler(IRRE_ERR_INVALID_MEMORY_ACCESS);
      }
      break;
    }
    state->m[addr + offset + 0] = (state->r[instruction.a1] >> 0) & 0xff;
    state->m[addr + offset + 1] = (state->r[instruction.a1] >> 8) & 0xff;
    state->m[addr + offset + 2] = (state->r[instruction.a1] >> 16) & 0xff;
    state->m[addr + offset + 3] = (state->r[instruction.a1] >> 24) & 0xff;
    break;
  }
  case OP_LDB: {
    IRRE_UWORD addr = state->r[instruction.a2];
    IRRE_BYTE offset = instruction.a3;
    if (addr + offset >= state->mem_size) {
      if (state->error_handler) {
        state->error_handler(IRRE_ERR_INVALID_MEMORY_ACCESS);
      }
      break;
    }
    state->r[instruction.a1] = state->m[addr + offset];
    break;
  }
  case OP_STB: {
    IRRE_UWORD addr = state->r[instruction.a2];
    IRRE_BYTE offset = instruction.a3;
    if (addr + offset >= state->mem_size) {
      if (state->error_handler) {
        state->error_handler(IRRE_ERR_INVALID_MEMORY_ACCESS);
      }
      break;
    }
    state->m[addr + offset] = (IRRE_BYTE)(state->r[instruction.a1] & 0xff);
    break;
  }
  case OP_JMI: {
    IRRE_UWORD addr = (IRRE_UWORD)(instruction.a1 | (instruction.a2 << 8) |
                                   (instruction.a3 << 16));
    state->r[REG_PC] = addr;
    branch = true;
    break;
  }
  case OP_JMP: {
    IRRE_UWORD addr = state->r[instruction.a1];
    state->r[REG_PC] = addr;
    branch = true;
    break;
  }
  case OP_BVE: {
    IRRE_UWORD addr = state->r[instruction.a1];
    IRRE_WORD a = state->r[instruction.a2];
    IRRE_BYTE b = instruction.a3;
    if (a == b) {
      state->r[REG_PC] = addr;
      branch = true;
    }
    break;
  }
  case OP_BVN: {
    IRRE_UWORD addr = state->r[instruction.a1];
    IRRE_WORD a = state->r[instruction.a2];
    IRRE_BYTE b = instruction.a3;
    if (a != b) {
      state->r[REG_PC] = addr;
      branch = true;
    }
    break;
  }
  case OP_CAL: {
    IRRE_UWORD addr = state->r[instruction.a1];
    state->r[REG_LR] = state->r[REG_PC] + IRRE_INSTRUCTION_SIZE;
    state->r[REG_PC] = addr;
    branch = true;
    break;
  }
  case OP_RET: {
    IRRE_UWORD addr = state->r[REG_LR];
    if (addr == 0) { // halt
      state->executing = false;
      break;
    }
    state->r[REG_PC] = addr;
    state->r[REG_LR] = 0;
    branch = true;
    break;
  }
  case OP_MUL: {
    state->r[instruction.a1] =
        state->r[instruction.a2] * state->r[instruction.a3];
    break;
  }
  case OP_DIV: {
    state->r[instruction.a1] =
        state->r[instruction.a2] / state->r[instruction.a3];
    break;
  }
  case OP_MOD: {
    state->r[instruction.a1] =
        state->r[instruction.a2] % state->r[instruction.a3];
    break;
  }
  case OP_SIA: {
    IRRE_UWORD existing = state->r[instruction.a1];
    IRRE_BYTE val = instruction.a2;
    IRRE_BYTE shift = instruction.a3;
    if (shift >= 0 && shift < 32) {
      IRRE_UWORD shifted = val << shift;
      state->r[instruction.a1] = existing + shifted;
    }
    break;
  }
  case OP_SUP: {
    IRRE_UWORD val = (instruction.a2 | (instruction.a3 << 8));
    IRRE_UWORD shifted_val = val << 16; // upper 16 bits of a word
    IRRE_UWORD existing_data = state->r[instruction.a1];
    state->r[instruction.a1] = (existing_data & 0x0000FFFF) |
                               shifted_val; // set only upper 16 bits of a1
    break;
  }
  case OP_SXT: {
    // move value from a2 to a1, sign extend
    state->r[instruction.a1] = (IRRE_WORD)state->r[instruction.a2];
    break;
  }
  case OP_SEQ: {
    // set a1 to 1 if a2 == imm, else 0
    IRRE_BYTE val = instruction.a3;
    if (state->r[instruction.a2] == val) {
      state->r[instruction.a1] = 1;
    } else {
      state->r[instruction.a1] = 0;
    }
    break;
  }
  case OP_INT: {
    IRRE_UWORD code = (IRRE_UWORD)(instruction.a1 | (instruction.a2 << 8) |
                                   (instruction.a3 << 16));
    if (state->interrupt_handler) {
      state->interrupt_handler(code);
    }
    break;
  }
  case OP_SND: {
    IRRE_UWORD device_id = state->r[instruction.a1];
    IRRE_UWORD device_command = state->r[instruction.a2];
    IRRE_UWORD device_data = state->r[instruction.a3];

    if (state->device_handler) {
      state->device_handler(device_id, device_command, device_data);
    }

    break;
  }
  case OP_HLT: {
    state->executing = false;
    break;
  }
  default: {
    // illegal opcode
    state->executing = false;
    if (state->error_handler) {
      state->error_handler(IRRE_ERR_ILLEGAL_OPCODE);
    }
    break;
  }
  }
  // advance the program counter if no branch was taken
  if (!branch) {
    state->r[REG_PC] += IRRE_INSTRUCTION_SIZE;
  }
}
