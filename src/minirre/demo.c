#include "irre.h"
#include <stdio.h>
#include <stdlib.h>

#define IRRE_DEMO_MEMORY_SIZE (1024 * 64) // 64 KB
IrreState vm_state;
IRRE_UBYTE vm_memory[IRRE_DEMO_MEMORY_SIZE];

typedef enum {
  DEMO_DEVICE_PING = 0x00001000,
} DemoDevice;

uint8_t *read_file(char *filename, size_t *size);

void handle_irre_interrupt(IRRE_UWORD code) {
  printf("[%s] code: %d\n", __func__, code);
}

void handle_irre_error(IrreError err) {
  vm_state.executing = false;
  printf("[%s] error: $%02x\n", __func__, err);
}

IRRE_UWORD handle_irre_device(IRRE_UWORD device_id, IRRE_UWORD device_command,
                        IRRE_UWORD device_data) {
  printf("[%s] device message: (id=$%08x, command=$%08x, data=$%08x)\n",
         __func__, device_id, device_command, device_data);

  switch (device_id) {
  case DEMO_DEVICE_PING:
    printf("[%s] ping(%d)\n", __func__, device_data);
    return device_data;
    break;
  default:
    printf("[%s] unknown device id: $%08x\n", __func__, device_id);
    break;
  }

  return 0;
}

int main(int argc, char **argv) {
  bool debug = false;
  char *filename = NULL;

  if (argc < 2) {
    printf("usage: %s <filename> [debug]\n", argv[0]);
    return 1;
  }
  filename = argv[1];
  if (argc > 2 && argv[2][0] == 'd') {
    debug = true;
  }

  // load the binary
  size_t binary_size;
  uint8_t *binary = read_file(filename, &binary_size);
  if (!binary) {
    return 1;
  }

  // check the header
  if (binary[0] != 'r' || binary[1] != 'g') {
    printf("[%s] file %s is not a valid binary\n", __func__, filename);
    return 1;
  }

  // extract the program
  size_t program_size = binary[2] | binary[3] << 8;
  uint8_t *program = binary + 4;

  // create the vm
  vm_state.m = vm_memory;
  vm_state.mem_size = IRRE_DEMO_MEMORY_SIZE;
  printf("[%s] initializing vm (memory size: %d)\n", __func__,
         IRRE_DEMO_MEMORY_SIZE);
  vm_state.interrupt_handler = handle_irre_interrupt;
  vm_state.error_handler = handle_irre_error;
  vm_state.device_handler = handle_irre_device;
  irre_init(&vm_state);

  printf("[%s] loading program (size: %zu)\n", __func__, program_size);
  irre_load(&vm_state, program, program_size);

  printf("[%s] executing\n", __func__);

  for (size_t step = 0; vm_state.executing; step++) {
    if (debug) {
      // debug: show instruction
      IRRE_UWORD pc = vm_state.r[REG_PC];
      IRRE_WORD raw_instruction = irre_fetch(&vm_state);
      IrreInstruction instruction = irre_decode(raw_instruction);
      printf("[%s] step %zu:\n", __func__, step);
      printf("[%s]   pc: $%04x\n", __func__, pc);
      printf("[%s]   raw instruction: $%08x\n", __func__, raw_instruction);
      printf("[%s]   instruction: op=$%02x a1=$%02x a2=$%02x a3=$%02x\n",
             __func__, instruction.opcode, instruction.a1, instruction.a2,
             instruction.a3);
    }
    // step
    irre_step(&vm_state);
  }

  // debug: show registers
  printf("[%s] registers:\n", __func__);
  for (int i = 0; i < IRRE_REGISTER_COUNT; i++) {
    printf("[%s]   r%d: $%08x\n", __func__, i, vm_state.r[i]);
  }

  // free the binary
  free(binary);

  return 0;
}

uint8_t *read_file(char *filename, size_t *size) {
  FILE *f = fopen(filename, "rb");
  if (!f) {
    printf("[%s] could not open file %s\n", __func__, filename);
    return NULL;
  }

  fseek(f, 0, SEEK_END);
  *size = ftell(f);
  fseek(f, 0, SEEK_SET);

  uint8_t *program_data = malloc(*size);
  fread(program_data, 1, *size, f);
  fclose(f);

  return program_data;
}
