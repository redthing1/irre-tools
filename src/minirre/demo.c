#include "getopt.h"
#include "irre.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define IRRE_DEMO_MEMORY_SIZE (1024 * 64) // 64 KB
IrreState vm_state;
IRRE_UBYTE vm_memory[IRRE_DEMO_MEMORY_SIZE];

typedef enum {
  DEMO_DEVICE_PING = 0x00001000,
  DEMO_DEVICE_RANDOM = 0x00005005,
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
  case DEMO_DEVICE_PING: {
    printf("[%s] ping(%d)\n", __func__, device_data);
    return device_data;
  }
  case DEMO_DEVICE_RANDOM: {
    // random call: command=address, data=count
    IRRE_UWORD random_address = device_command;
    IRRE_UWORD random_count = device_data;
    printf("[%s] random(address=$%08x, count=%d)\n", __func__, random_address,
           random_count);
    // fill the memory with random bytes
    for (IRRE_UWORD i = 0; i < random_count; i++) {
      vm_state.m[random_address + i] = rand() % 256;
    }
    return 0;
  }
  default: {
    printf("[%s] unknown device id: $%08x\n", __func__, device_id);
    break;
  }
  }

  return 0;
}

int main(int argc, char **argv) {
  bool debug_insdump = false;
  bool debug_regdump = false;
  bool debug_memdump = false;
  char *filename = NULL;

  srand(time(NULL));

  int c;
  while ((c = getopt(argc, argv, "drmf:")) != -1) {
    switch (c) {
    case 'd':
      debug_insdump = true;
      break;
    case 'r':
      debug_regdump = true;
      break;
    case 'm':
      debug_memdump = true;
      break;
    case 'f':
      filename = optarg;
      break;
    default:
      printf("usage: %s [-d] [-r] [-m] -f <filename>\n", argv[0]);
      return 1;
    }
  }

  // validate arguments
  if (!filename) {
    printf("specify a filename with -f\n");
    return 1;
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
    if (debug_insdump) {
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

  if (debug_regdump) {
    // debug: show registers
    printf("[%s] registers:\n", __func__);
    for (int i = 0; i < IRRE_REGISTER_COUNT; i++) {
      printf("[%s]   r%d: $%08x\n", __func__, i, vm_state.r[i]);
    }
  }

  if (debug_memdump) {
    // debug: pretty dump memory
    printf("[%s] memory:\n", __func__);
    for (int i = 0; i < IRRE_DEMO_MEMORY_SIZE; i += 16) {
      printf("[%s] %08x: ", __func__, i);
      for (int j = 0; j < 16; j++) {
        printf("%02x", vm_state.m[i + j]);
        if (j % 2 == 1) {
          printf(" ");
        }
      }
      printf("\n");
    }
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
