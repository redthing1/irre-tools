module irre.assembler.parser;

import irre.util;
import irre.assembler.lexer;
import irre.encoding.instructions;
import std.array;
import std.string;
import std.conv;
import std.stdio;
import std.variant;

struct ValueRef {
    string label;
    int offset;
}

struct ValueImm {
    int val;
}

alias ValueArg = Algebraic!(ValueImm, ValueRef);

struct AbstractStatement {
    OpCode op;
    ValueArg a1, a2, a3;
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
    private byte[] data;
    private Appender!(MacroDef[]) macros;
    private Appender!(LabelDef[]) labels;

    public ProgramAst parse(Lexer.Result lexer_result) {
        this.lexed = lexer_result;

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
                    auto dir = expect_token(CharType.DIRECTIVE);
                    if (dir.content == "#entry") { // entrypoint directive
                        // following label has the entry point
                        expect_token(CharType.MARK);
                        auto label_ref = expect_token(CharType.IDENTIFIER);
                        entry_label = label_ref.content; // store entry label
                    } else if (dir.content == "#d") { // data directive
                        expect_token(CharType.PACK_START); // eat pack start
                        // check pack type indicator
                        auto pack_type_indicator = expect_token(CharType.ALPHA | CharType.QUOT);
                        auto pack_len = 0uL; // size of packed data

                        switch (pack_type_indicator.kind) {
                        case CharType.ALPHA: { // byte pack
                                auto pack = expect_token(CharType.NUMERIC_CONSTANT);
                                pack_len = pack.content.length;
                                if (pack_len % 2 != 0) {
                                    // odd number of half-bytes, invalid
                                    throw parser_error("invalid data (must be an even size)");
                                }
                                pack_len = pack_len / 2; // divide by two because 0xff = 1 byte
                                auto pack_data = datahex(pack.content); // convert data from hex
                                // write the pack data to the binary
                                data ~= pack_data;
                                break;
                            }
                        case CharType.QUOT: { // data string
                                auto pack = take_token(); // any following token is valid
                                pack_len = pack.content.length;
                                // copy string from token to data
                                data ~= cast(byte[]) pack.content;
                                break;
                            }
                        default:
                            throw parser_error(format("unrecognized pack type %s",
                                    pack_type_indicator.content));
                        }

                        // update offset
                        offset += pack_len;
                        // printf("data block, len: $%04x\n", cast(UWORD) pack_len);
                    }
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
                        immutable auto maybeInfo = InstructionEncoding.get_info(mnem);
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

        // check for entry point label
        auto entry_addr = 0;
        if (entry_label) {
            // resolve the label and replace the entry jump
            auto entry_label_def = resolve_label(entry_label);
            statements.data[0] = AbstractStatement(OpCode.SET,
                    cast(ValueArg) ValueImm(Register.PC),
                    cast(ValueArg) ValueImm(entry_label_def.offset));
        }
        // resolve statements, rewriting them
        auto resolved_statements = resolve_statements(statements);

        auto ast = ProgramAst(resolved_statements, entry_addr, data);
        return ast;
    }

    AbstractStatement[] resolve_statements(ref const Appender!(AbstractStatement[]) statements) {
        auto resolved_statements = appender!(AbstractStatement[]);
        foreach (unresolved; statements.data) {
            auto statement = AbstractStatement(unresolved.op);
            // resolve args
            statement.a1 = resolve_value_arg(unresolved.a1);
            statement.a2 = resolve_value_arg(unresolved.a2);
            statement.a3 = resolve_value_arg(unresolved.a3);
            resolved_statements ~= statement;
        }

        return resolved_statements.data;
    }

    AbstractStatement read_statement(string mnem, string a1, string a2, string a3) {
        auto maybeInfo = InstructionEncoding.get_info(mnem);
        auto info = maybeInfo.get();
        auto statement = AbstractStatement(info.op);

        int parse_numeric(string num) { // interpret numeric constant
            char pfx = num[0];
            // create a new string without the prefix
            string num_str = num[1 .. $]; // convert base
            int val = 0;
            switch (pfx) {
            case '$': {
                    // interpret as base-16
                    val = to!int(num_str, 16);
                    break;
                }
            case '.': {
                    // interpret as base-10
                    val = to!int(num_str);
                    break;
                }
            default:
                // invalid numeric type (by prefix)
                throw parser_error(format("invalid numeric prefix: %c", pfx));
            }
            return val;
        }

        ValueArg read_value_arg() {
            immutable auto next = peek_token();
            if (next.kind == CharType.MARK) {
                expect_token(CharType.MARK); // eat the mark
                immutable auto label_ref_tok = expect_token(CharType.IDENTIFIER);
                auto vs = ValueRef(label_ref_tok.content, 0);
                immutable auto pk_offset = peek_token();
                if (pk_offset.kind == CharType.OFFSET) {
                    expect_token(CharType.OFFSET); // eat the offset token
                    auto num_tok = expect_token(CharType.NUMERIC_CONSTANT);
                    immutable auto offset_val = parse_numeric(num_tok.content);
                    vs.offset = offset_val;
                }
                return cast(ValueArg) vs;
            } else if (next.kind == CharType.NUMERIC_CONSTANT) {
                // interpret numeric token
                auto num_tok = expect_token(CharType.NUMERIC_CONSTANT);
                auto vs = ValueImm(parse_numeric(num_tok.content));
                return cast(ValueArg) vs;
            } else {
                throw parser_error(format("unrecognized token for value arg:  %s", next.content));
            }
        }

        // read args
        if ((info.operands & Operands.K_R1) > 0) {
            statement.a1 = ValueImm(InstructionEncoding.get_register(a1));
        }
        if ((info.operands & Operands.K_R2) > 0) {
            statement.a2 = ValueImm(InstructionEncoding.get_register(a2));
        }
        if ((info.operands & Operands.K_R3) > 0) {
            statement.a3 = ValueImm(InstructionEncoding.get_register(a3));
        }

        if ((info.operands & Operands.K_I1) > 0) {
            if (!a1.empty)
                statement.a1 = ValueImm(parse_numeric(a1));
            else
                statement.a1 = read_value_arg();
        } else if ((info.operands & Operands.K_I2) > 0) {
            if (!a2.empty)
                statement.a2 = ValueImm(parse_numeric(a2));
            else
                statement.a2 = read_value_arg();
        } else if ((info.operands & Operands.K_I3) > 0) {
            if (!a3.empty)
                statement.a3 = ValueImm(parse_numeric(a3));
            else
                statement.a3 = read_value_arg();
        }

        return statement;
    }

    ValueImm resolve_value_arg(const ValueArg arg) {
        auto val = 0;
        if (arg.hasValue) {
            val = arg.visit!((ValueImm imm) => imm.val,
                    (ValueRef ref_) => resolve_label(ref_.label).offset + offset);
        }
        return ValueImm(val);
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
        // if at end, unknown
        if (token_pos >= lexed.tokens.length) {
            return Token(string.init, CharType.UNKNOWN);
        }
        return lexed.tokens[token_pos];
    }

    private Token take_token() {
        auto token = peek_token();
        token_pos++;
        char_pos += token.content.length;
        // writefln("took token [%d]: %s", token_pos - 1, token.content);
        return token;
    }

    private Token expect_token(CharType type) {
        auto token = peek_token();
        if ((token.kind & type) > 0) {
            // expected token found
            return take_token();
        } else {
            throw parser_error(format("expected %s but got %s",
                    to!string(type), to!string(token.kind)));
        }
    }

    private ParserException parser_error(string message) {
        return new ParserException(format("%s at charpos %d", message, char_pos));
    }
}
