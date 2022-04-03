module irretool.test.asmr.common;

public {
    import irre.util;
    import irre.meta;
    import irre.assembler.lexer;
    import irre.assembler.parser;
    import irre.assembler.ast_freezer;
    import irre.encoding.rega;

    import irretool.test.code;
}

Lexer.Result lex_program(string source) {
    Lexer lexer;
    Lexer.Result lexed;

    // lex the source
    lexer = new Lexer();
    lexed = lexer.lex(source);

    return lexed;
}

ProgramAst parse_lex(Lexer.Result lexed) {
    Parser parser;
    ProgramAst program_ast;

    // parse the tokens
    parser = new Parser();
    parser.load_lex(lexed);
    parser.parse();

    // create an ast
    program_ast = parser.to_ast();

    return program_ast;
}

ubyte[] encode_ast(ProgramAst program_ast) {
    auto freezer = new AstFreezer(program_ast);
    freezer.freeze_all_symbols();
    program_ast = freezer.get_frozen_ast();

    // EXE encode
    auto encoder = new RegaEncoder();
    auto compiled_data = encoder.encode_exe(program_ast);

    return compiled_data;
}

ubyte[] compile_program(string source) {
    auto lexed = lex_program(source);
    auto program_ast = parse_lex(lexed);
    auto compiled_data = encode_ast(program_ast);

    return compiled_data;
}

ubyte[] compile_program(TestProgram prog) {
    try {
        return compile_program(prog.source);
    } catch (Exception e) {
        assert(0, format("program %s failed to compile: %s", prog.name, e));
    }
}

void ensure_programs_assemble(immutable TestProgram[] progs) {
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
