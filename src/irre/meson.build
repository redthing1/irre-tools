sources = [
    'meta.d',
    'assembler/lexer.d',
    'assembler/parser.d'
]

libirre = shared_library('irre', sources,
    include_directories: include)

libirre_dep = declare_dependency(link_with: libirre)
