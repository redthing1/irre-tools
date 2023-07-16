
# src level meson

subdir('libirre') # IRRE library

subdir('asmr') # assembler

# define outputs

libirre = shared_library('libirre', libirre_sources)

assembler = executable('irre-asm', asm_sources,
    dependencies: [libirre])
