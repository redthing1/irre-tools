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
    auto progs = [PROG_BIGPROG, PROG_FUNC, PROG_MEM];

    foreach (prg; progs) {
        try {
            auto lex = lex_program(prg.source);
            auto ast = parse_lex(lex);

            assert(ast.statements.length > 0,
                format("program: %s did not assemble correctly", prg.name));
        } catch (Exception e) {
            assert(false,
                format("program: %s failed to assemble with exception: %s", prg.name, e));
        }
    }
}
