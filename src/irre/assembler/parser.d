module irre.assembler.parser;

import irre.util;
import irre.assembler.lexer;
import irre.encoding.instructions;
import std.array;
import std.string;
import std.conv;
import std.stdio;
import std.variant;
import std.typecons;

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

struct SourceStatement {
    string mnem;
    Token[] a1, a2, a3;
}

struct ProgramAst {
    AbstractStatement[] statements;
    const ubyte[] data;
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
        VALUE = 0,
        REGISTER = 1,
    }

    Type type;
    string name;
}

struct MacroDef {
    string name;
    MacroArg[] args;
    SourceStatement[] statements;
}

class Parser {
    private Lexer.Result lexed;
    private int token_pos;
    private int char_pos;
    private int offset;
    private ubyte[] data;
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
            immutable auto next = peek_token();
            switch (next.kind) {
            case CharType.DIRECTIVE: {
                    immutable auto dir = expect_token(CharType.DIRECTIVE);
                    if (dir.content == "#entry") { // entrypoint directive
                        // following label has the entry point
                        expect_token(CharType.MARK);
                        immutable auto label_ref = expect_token(CharType.IDENTIFIER);
                        entry_label = label_ref.content; // store entry label
                    } else if (dir.content == "#d") { // data directive
                        expect_token(CharType.PACK_START); // eat pack start
                        // check pack type indicator
                        immutable auto pack_type_indicator = expect_token(
                                CharType.ALPHA | CharType.QUOT);
                        auto pack_len = 0uL; // size of packed data

                        switch (pack_type_indicator.kind) {
                        case CharType.ALPHA: { // byte pack (x)
                                auto pack_token = expect_token(CharType.NUMERIC_CONSTANT);
                                pack_len = pack_token.content.length;
                                if (pack_len % 2 != 0) {
                                    // odd number of half-bytes, invalid
                                    throw parser_error_token("invalid data (must be an even size)",
                                            pack_token);
                                }
                                pack_len = pack_len / 2; // divide by two because 0xff = 1 byte
                                auto pack_data = datahex(pack_token.content); // convert data from hex
                                // write the pack data to the binary
                                data ~= pack_data;
                                break;
                            }
                        case CharType.QUOT: { // data string (')
                                auto pack = take_token(); // any following token is valid
                                pack_len = pack.content.length;
                                // copy string from token to data
                                data ~= cast(ubyte[]) pack.content;
                                break;
                            }
                        default:
                            throw parser_error_token(format("unrecognized pack type %s",
                                    pack_type_indicator.content), pack_type_indicator);
                        }

                        // update offset
                        offset += pack_len;
                        // printf("data block, len: $%04x\n", cast(UWORD) pack_len);
                    }
                    break;
                }
            case CharType.IDENTIFIER: {
                    immutable auto iden = expect_token(CharType.IDENTIFIER);
                    immutable auto iden_next = peek_token();
                    if (iden_next.kind == CharType.MARK && iden_next.content == ":") { // label def (only if single mark)
                        expect_token(CharType.MARK); // eat the mark
                        define_label(iden.content); // create label
                        break;
                    } else if (iden_next.kind == CharType.BIND) { // macro def
                        expect_token(CharType.BIND); // eat the bind
                        define_macro(iden.content); // define the macro
                        break;
                    } else {
                        // instruction
                        immutable auto mnem_token = iden;
                        immutable auto mnem = mnem_token.content;
                        auto maybe_raw_statement = take_raw_statement(mnem);
                        if (!maybe_raw_statement.isNull) {
                            // standard instruction
                            auto statement = parse_statement(maybe_raw_statement.get());
                            statements ~= statement; // push statement
                            offset += INSTRUCTION_SIZE; // update code offset
                        } else {
                            // it was not an instruction, perhaps it's a macro
                            auto md = resolve_macro(mnem); // check if a matching macro exists
                            if (!md.name) {
                                // no matching macro was found
                                // this, we don't recognize this statement
                                throw parser_error_token(format("unrecognized macro: %s",
                                        mnem), mnem_token);
                            } else {
                                // expand the macro
                                // TODO: implementation
                                break;
                            }
                        }
                    }
                    break;
                }
            default:
                throw parser_error_token(format("unexpected of type: %s",
                        to!string(next.kind)), next);

            }
        }

        // check for entry point label
        if (entry_label) {
            // resolve the label and replace the entry jump
            immutable auto entry_label_def = resolve_label(entry_label);
            // since all instructions increment PC, we subtract
            auto entry_addr = entry_label_def.offset - cast(int) INSTRUCTION_SIZE;
            statements.data[0] = AbstractStatement(OpCode.SET,
                    cast(ValueArg) ValueImm(Register.PC), cast(ValueArg) ValueImm(entry_addr));
        }
        // resolve statements, rewriting them
        auto resolved_statements = resolve_statements(statements);

        auto ast = ProgramAst(resolved_statements, data);
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

    Nullable!SourceStatement take_raw_statement(string mnem) {
        immutable auto maybeInfo = InstructionEncoding.get_info(mnem);
        string a1, a2, a3;

        // get all the tokens that make up the next register arg
        Token take_register_arg_tokens() {
            return expect_token(CharType.IDENTIFIER);
        }

        // get all the tokens that make up the next value arg
        Token[] take_value_arg_tokens() {
            auto tokens = Token[].init;
            immutable auto next = peek_token();
            switch (next.kind) {
            case CharType.MARK: {
                    // this is a label reference
                    expect_token(CharType.MARK); // eat the mark
                    immutable auto label_token = expect_token(CharType.IDENTIFIER);
                    tokens ~= label_token;
                    immutable auto offset_token = peek_token();
                    if (offset_token.kind == CharType.OFFSET) {
                        // there is an offset token
                        expect_token(CharType.OFFSET);
                        tokens ~= expect_token(CharType.NUMERIC_CONSTANT);
                    }
                    // will consist of: [IDENTIFIER, NUMERIC_CONSTANT]
                    break;
                }
            case CharType.NUMERIC_CONSTANT: {
                    // this is a numeric token
                    tokens ~= expect_token(CharType.NUMERIC_CONSTANT);
                    // will consist of: [NUMERIC_CONSTANT]
                    break;
                }
            default:
                throw parser_error_token(format("unrecognized value arg for instruction '%s'",
                        mnem), next);
            }
            return tokens;
        }

        if (maybeInfo.isNull) { // didn't match standard instruction names
            return Nullable!SourceStatement.init;
        } // fill in arguments
        auto statement = SourceStatement(mnem);
        auto info = maybeInfo.get();

        // read tokens for arguments
        if ((info.operands & Operands.K_R1) > 0) {
            statement.a1 ~= take_register_arg_tokens();
        } else if ((info.operands & Operands.K_I1) > 0) {
            statement.a1 ~= take_value_arg_tokens();
        }
        if ((info.operands & Operands.K_R2) > 0) {
            statement.a2 ~= take_register_arg_tokens();
        } else if ((info.operands & Operands.K_I2) > 0) {
            statement.a2 ~= take_value_arg_tokens();
        }
        if ((info.operands & Operands.K_R3) > 0) {
            statement.a3 ~= take_register_arg_tokens();
        } else if ((info.operands & Operands.K_I3) > 0) {
            statement.a3 ~= take_value_arg_tokens();
        }

        // completed source statement
        return Nullable!SourceStatement(statement);
    }

    AbstractStatement parse_statement(SourceStatement raw_statement) {
        auto maybeInfo = InstructionEncoding.get_info(raw_statement.mnem);
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

        ValueImm read_register_arg(Token[] tokens) {
            auto register_token = tokens[0];
            return ValueImm(InstructionEncoding.get_register(register_token.content));
        }

        // read a special value arg
        ValueArg read_value_arg(Token[] tokens) {
            auto pos = 0;
            immutable auto next = tokens[pos];

            switch (next.kind) {
            case CharType.IDENTIFIER: {
                    // this is a label reference
                    immutable auto label_token = next;
                    pos++; // move to next token
                    auto offset = 0;
                    if (tokens.length > 1) {
                        // there is an offset
                        auto offset_token = tokens[pos];
                        offset = parse_numeric(offset_token.content);
                    }
                    return cast(ValueArg) ValueRef(label_token.content, offset);
                }
            case CharType.NUMERIC_CONSTANT: {
                    immutable auto num_token = next;
                    auto num = parse_numeric(num_token.content);
                    return cast(ValueArg) ValueImm(num);
                }
            default:
                throw parser_error_token(format("unrecognized token for value arg:  %s",
                        to!string(next.kind)), next);
            }
        }

        // read in args from tokens
        if ((info.operands & Operands.K_R1) > 0) {
            statement.a1 = read_register_arg(raw_statement.a1);
        } else if ((info.operands & Operands.K_I1) > 0) {
            statement.a1 = read_value_arg(raw_statement.a1);
        }
        if ((info.operands & Operands.K_R2) > 0) {
            statement.a2 = read_register_arg(raw_statement.a2);
        } else if ((info.operands & Operands.K_I2) > 0) {
            statement.a2 = read_value_arg(raw_statement.a2);
        }
        if ((info.operands & Operands.K_R3) > 0) {
            statement.a3 = read_register_arg(raw_statement.a3);
        } else if ((info.operands & Operands.K_I3) > 0) {
            statement.a3 = read_value_arg(raw_statement.a3);
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
        writefln("DEFINE_MACRO %s", name);
        auto def = new MacroDef(name);
        while (peek_token().kind != CharType.MARK) { // MARK terminates arg list
            immutable auto arg_name = expect_token(CharType.IDENTIFIER);
            MacroArg.Type get_arg_type(char arg_prefix) {
                switch (arg_prefix) {
                case 'r':
                    return MacroArg.Type.REGISTER;
                case 'v':
                    return MacroArg.Type.VALUE;
                default:
                    throw parser_error_token(format("unrecognized macro arg prefix %c on argument %d of macro %s",
                            arg_prefix, def.args.length + 1, def.name), arg_name);
                }
            }

            immutable auto arg_type = get_arg_type(arg_name.content[0]);
            immutable auto arg = MacroArg(arg_type, arg_name.content);
            def.args ~= arg;
        }
        expect_token(CharType.MARK); // eat the mark
        // read the macro body
        auto statements = appender!(AbstractStatement[]);
        // TODO: implement this
        // while (true) {
        //     immutable auto next = peek_token();
        //     if (next.kind == MARK && streq(next.cont, "::")) {
        //         expect_token(st, MARK); // end of macro def
        //         break;
        //     }
        //     // otherwise, we should have instruction statements
        //     // TODO: read statement
        //     auto iden = expect_token(st, IDENTIFIER);
        //     const char* mnem = iden.cont;
        //     InstructionInfo info = get_instruction_info(mnem);
        //     const char * a1 = NULL,  * a2 = NULL,  * a3 = NULL;
        //     if (info.type == INSTR_INV) { // not a base instruction
        //         // we don't support referencing macros within macros
        //         printf("unrecognized mnemonic: %s\n", mnem);
        //     } else {
        //         if ((info.type & (INSTR_K_R1 | INSTR_K_I1)) > 0) {
        //             a1 = take_token(st).cont;
        //         }
        //         if ((info.type & (INSTR_K_R2 | INSTR_K_I2)) > 0) {
        //             a2 = take_token(st).cont;
        //         }
        //         if ((info.type & (INSTR_K_R3 | INSTR_K_I3)) > 0) {
        //             a3 = take_token(st).cont;
        //         }
        //     }
        //     SourceStatement raw_stmt = (SourceStatement) {
        //         .mnem = mnem, .a1 = a1, .a2 = a2, .a3 = a3
        //     };
        //     buf_push_SourceStatement(&def.statements, raw_stmt);
        // }
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
            throw parser_error_token(format("expected %s but instead got %s",
                    to!string(type), to!string(token.kind)), token);
        }
    }

    private ParserException parser_error(string message) {
        return new ParserException(format("%s at charpos %d", message, char_pos));
    }

    private ParserException parser_error_token(string message, Token token) {
        return new ParserException(format("%s on line %d at token %s", message,
                token.line, token.content));
    }
}
