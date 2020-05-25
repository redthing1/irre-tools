module irre.assembler.parser;

import irre.assembler.lexer;
import std.array : Appender;

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

struct LabelDef {
    string name;
    int offset;
}

struct MacroArg {
    enum Type {
        REGISTER,
        VALUE
    }

    Type type;
    string name;
}

struct MacroDef {
    string name;
    MacroArg[] args;
    RawStatement[] statements;
}

class Parser {
    private Lexer.Result lexed;
    private int token_pos;
    private int char_pos;
    private int offset;
    private Appender!MacroDef macros;
    private Appender!LabelDef labels;

    public ProgramAst parse(Lexer.Result lexed) {
        auto ast = new ProgramAst();

        string entry_label;

        // TODO: emit entry jump
        // ast.statements ~= 

        while (token_pos < lexed.tokens.length) {
            // TODO: handle tokens
        }

        return ast;
    }

    private Token peek_token() {
        return lexed.tokens[token_pos];
    }

    private Token take_token() {
        auto token = peek_token();
        token_pos++;
        char_pos += token.content.length;
        return token;
    }

    private Token expect_token(CharType type) {
        auto token = peek_token();
        if ((token.kind & type) > 0) {
            // expected token found
            return token;
        } else {
            throw new ParserException(format("expected %s but got %s at position %d", type, token.kind, char_pos));
        }
    }
}
