module irretool.test.asmr.tests;

import std.format;

import irretool.test.asmr.common;

@("asmr.basic.abc")
unittest {
    auto prg = PROG_BASIC;

    auto lex = lex_program(prg.source);
    auto ast = parse_lex(lex);

    assert(ast.statements.length > 0);
}

@("asmr.basic.simpleprogs")
unittest {
    ensure_programs_assemble(PROGS_SET_SIMPLE);
}

@("asmr.full.asmsyntax")
unittest {
    ensure_programs_assemble(PROGS_SET_ASMSYNTAX);
}

@("asmr.full.miscprogs")
unittest {
    auto progs = PROGS_SET_IFT;
    ensure_programs_assemble(progs);
}
