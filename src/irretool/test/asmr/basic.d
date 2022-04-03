module irretool.test.asmr.basic;

import irretool.test.asmr.common;
import irretool.test.code;

@("asmr.basic.abc")
unittest {
    auto source = PROG_BASIC;

    auto lex = lex_program(source);
    auto ast = parse_lex(lex);

    assert(ast.statements.length > 0);
}
