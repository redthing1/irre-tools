module irre.assembler.parser;

import irre.assembler.lexer;
import irre.encoding.instructions;
import std.array;
import std.string;
import std.conv;

struct RefValueSource {
    string label;
    int offset;
}

struct ValueSource {
    enum Kind {
        IMMEDIATE,
        REFERENCE
    }

    Kind kind;
    int val; /** immediate value */
    RefValueSource val_ref; /** ref */
}

struct AbstractStatement {
    OpCode op;
    ValueSource a1, a2, a3;
}

struct RawStatement {
    string mnem;
    string a1, a2, a3;
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
    private Appender!(MacroDef[]) macros;
    private Appender!(LabelDef[]) labels;

    public ProgramAst parse(Lexer.Result lexed) {
        string entry_label;

        auto statements = appender!(AbstractStatement[]);

        // emit entry jump
        statements ~= AbstractStatement(OpCode.NOP);
        offset += INSTRUCTION_SIZE;

        // parse lex result into instruction list
        while (token_pos < lexed.tokens.length) {
            auto next = peek_token();
            switch (next.kind) {
            case CharType.DIRECTIVE: {
                    // TODO
                    break;
                }
            case CharType.IDENTIFIER: {
                    auto iden = expect_token(CharType.IDENTIFIER);
                    auto iden_next = peek_token();
                    if (iden_next.kind == CharType.MARK && iden_next.content == ":") { // label def (only if single mark)
                        expect_token(CharType.MARK); // eat the mark
                        define_label(iden.content); // create label
                        break;
                    } else if (iden_next.kind == CharType.BIND) { // macro def
                        expect_token(CharType.BIND); // eat the bind
                        define_macro(iden.content); // define the macro
                        break;
                    } else { // instruction
                        immutable auto mnem = iden.content;
                        immutable auto maybeInfo = InstructionMetadata.get_info(mnem);
                        auto instr_size = INSTRUCTION_SIZE;
                        string a1, a2, a3;
                        if (maybeInfo.isNull) { // didn't match standard instruction names
                            auto md = resolve_macro(mnem); // check if a matching macro exists
                            if (!md.name) { // invalid mnemonic
                                throw parser_error(format("unrecognized mnemonic: %s", mnem));
                            } else {
                                // expand the macro
                                auto expanded_statements = expand_macro(md);
                                break;
                            }
                        } else { // fill in arguments
                            auto info = maybeInfo.get();
                            instr_size = info.size;
                            if ((info.operands & Operands.K_R1) > 0) {
                                a1 = expect_token(CharType.IDENTIFIER).content;
                            }
                            if ((info.operands & Operands.K_R2) > 0) {
                                a2 = expect_token(CharType.IDENTIFIER).content;
                            }
                            if ((info.operands & Operands.K_R3) > 0) {
                                a3 = expect_token(CharType.IDENTIFIER).content;
                            }
                        }
                        auto statement = read_statement(iden.content, a1, a2, a3); // read statement
                        statements ~= statement; // push statement
                        offset += instr_size; // update code offset
                    }
                    break;
                }
            default: {
                    throw parser_error(format("unexpected token %s of type: %s",
                            next.content, to!string(next.kind)));
                }
            }
        }

        auto ast = ProgramAst();
        return ast;
    }

    AbstractStatement read_statement(string mnem, string a1, string a2, string a3) {
        auto maybeInfo = InstructionMetadata.get_info(mnem);
        auto info = maybeInfo.get();
        auto statement = AbstractStatement(info.op);

        // TODO: read args

        return statement;
    }

    void define_label(string name) {
        labels ~= LabelDef(name, offset);
    }

    LabelDef resolve_label(string name) {
        // find the label
        foreach (label; labels.data) {
            if (label.name == name) {
                return label;
            }
        }
        throw parser_error(format("label could not be resolved: %s", name));
    }

    void define_macro(string name) {
        // TODO
    }

    MacroDef resolve_macro(string name) {
        // find the macro
        foreach (macro_; macros.data) {
            if (macro_.name == name) {
                return macro_;
            }
        }
        throw parser_error(format("macro could not be resolved: %s", name));
    }

    AbstractStatement[] expand_macro(ref MacroDef def) {
        // TODO
        auto statements = appender!(AbstractStatement[]);

        return statements.data;
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
            throw parser_error(format("expected %s but got %s",
                    to!string(type), to!string(token.kind)));
        }
    }

    private ParserException parser_error(string message) {
        return new ParserException(format("%s at charpos %d", message, char_pos));
    }
}
