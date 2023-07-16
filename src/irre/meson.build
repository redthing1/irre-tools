sources = [
    'meta.d',
    'util.d',
    
    'assembler/lexer.d',
    'assembler/parser.d',

    'disassembler/dumper.d',
    'disassembler/reader.d',

    'encoding/instructions.d',
    'encoding/rega.d',
]

libirre = shared_library('irre', sources,
    include_directories: include)

libirre_dep = declare_dependency(link_with: libirre)
