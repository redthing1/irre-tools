module irre.assembler.parser;

import assembler.lexer;

struct AbstractStatement {
    // OPCODE op;
    // ValueSource a1, a2, a3;
}

struct ProgramAst {
    AbstractStatement[] statements;
    int entry;
    byte[] data;
}

class ParserException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

class Parser {
    public ProgramAst parse(LexResult lexed) {
        throw new ParserException("parsing is not yet implemented.");
    }
}
