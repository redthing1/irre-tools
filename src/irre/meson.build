sources = [
    'meta.d',
    'util.d',
    
    'assembler/lexer.d',
    'assembler/parser.d',
    'assembler/builtins.d',
    'assembler/ast.d',
    'assembler/ast_builder.d',

    'disassembler/dumper.d',
    'disassembler/reader.d',

    'emulator/vm.d',
    'emulator/hypervisor.d',
    'emulator/device.d',
    'emulator/devices/terminal.d',
    'emulator/devices/ping.d',

    'encoding/instructions.d',
    'encoding/rega.d',
]

libirre = shared_library('irre', sources,
    include_directories: include)

libirre_dep = declare_dependency(link_with: libirre)
