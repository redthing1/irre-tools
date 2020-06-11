sources = [
    'meta.d',
    'util.d',
    
    'assembler/lexer.d',
    'assembler/parser.d',
    'assembler/ast.d',

    'disassembler/dumper.d',
    'disassembler/reader.d',

    'emulator/vm.d',
    'emulator/hypervisor.d',

    'encoding/instructions.d',
    'encoding/rega.d',

    'translator/leg.d',
]

libirre = shared_library('irre', sources,
    include_directories: include)

libirre_dep = declare_dependency(link_with: libirre)
