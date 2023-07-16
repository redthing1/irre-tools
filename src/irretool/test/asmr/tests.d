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
    auto progs = [PROG_BIGPROG, PROG_FUNC, PROG_MEM, PROG_COND_BRANCH, PROG_COND_NOBRANCH];
    
    ensure_programs_assemble(progs);    
}

@("asmr.full.asmsyntax")
unittest {
    auto progs = [PROG_ASMV5];
    ensure_programs_assemble(progs);    
}

