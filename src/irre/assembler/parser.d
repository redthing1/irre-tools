module irre.assembler.parser;

import irre.util;
import irre.assembler.lexer;
public import irre.assembler.ast;
import irre.assembler.builtins;
import irre.encoding.instructions;
import std.array;
import std.string;
import std.conv;
import std.stdio;
import std.typecons;
import std.variant;

class ParserException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

class Parser {
    private Lexer.Result lexed;
    private int token_pos;
    private int char_pos;
    private int global_offset;
    private DataBlock[] data_blocks;
    private Appender!(MacroDef[]) macros;
    private Appender!(LabelDef[]) labels;

    this() {
        // define builtins
        define_builtins();
    }

    private void define_builtins() {
        macros ~= BuiltinMacros.MACRO_ADI;
        macros ~= BuiltinMacros.MACRO_SBI;
    }

    public void load_lex(Lexer.Result lexed) {
        this.lexed = lexed;

        // reset parse counting vars
        this.token_pos = 0;
        this.char_pos = 0;
        // this.offset = 0;
    }

    ubyte[] take_data_declaration() {
        ubyte[] packed_data;
        expect_token(CharType.PACK_START); // eat pack start
        // check pack type indicator
        immutable auto pack_type_indicator = expect_token(CharType.ALPHA | CharType.QUOT);

        switch (pack_type_indicator.kind) {
        case CharType.ALPHA: { // byte pack
                // check indicator content
                switch (pack_type_indicator.content) {
                case "x": {
                        auto pack_token = expect_token(CharType.NUMERIC_CONSTANT);
                        auto pack_len = pack_token.content.length;
                        if (pack_len % 2 != 0) {
                            // odd number of half-bytes, invalid
                            throw parser_error_token("invalid data (must be an even size)",
                                    pack_token);
                        }
                        pack_len = pack_len / 2; // divide by two because 0xff = 1 byte
                        auto pack_data = datahex(pack_token.content); // convert data from hex
                        // copy the pack data
                        packed_data ~= pack_data;
                        break;
                    }
                case "z": {
                        auto pack_token = expect_token(CharType.NUMERIC_CONSTANT);
                        auto byte_count = to!int(pack_token.content);
                        auto pack_data = new ubyte[byte_count];
                        packed_data ~= pack_data;
                        break;
                    }
                default: {
                        throw parser_error_token(format("unrecognized data pack type specifier '%s'",
                                pack_type_indicator.content), pack_type_indicator);
                    }
                }
                break;
            }
        case CharType.QUOT: { // data string (')
                auto pack = take_token(); // any following token is valid
                // copy string from token to data
                packed_data ~= cast(ubyte[]) pack.content;
                break;
            }
        default:
            throw parser_error_token(format("unrecognized pack type %s",
                    pack_type_indicator.content), pack_type_indicator);
        }

        return packed_data;
    }

    /** given a lexer result, parse tokens into a program ast */
    public ProgramAst parse() {
        string entry_label;

        auto statements = appender!(AbstractStatement[]);

        // emit entry jump
        statements ~= AbstractStatement(OpCode.NOP);
        global_offset += INSTRUCTION_SIZE;

        // parse lex result into instruction list
        while (token_pos < lexed.tokens.length) {
            immutable auto next = peek_token();
            switch (next.kind) {
            case CharType.DIRECTIVE: {
                    immutable auto dir = expect_token(CharType.DIRECTIVE);
                    auto dir_type = dir.content[1 .. $];
                    if (dir_type == "entry") { // entrypoint directive
                        // following label has the entry point
                        expect_token(CharType.MARK);
                        immutable auto label_ref = expect_token(CharType.IDENTIFIER);
                        entry_label = label_ref.content; // store entry label
                    } else if (dir_type == "d") {
                        // data directive
                        auto packed_data = take_data_declaration();
                        auto block = DataBlock(global_offset, packed_data);
                        global_offset += packed_data.length;
                        data_blocks ~= block;
                        log_put(format("data block[%d] at offset %d",
                                block.data.length, block.offset));
                    }
                    break;
                }
            case CharType.IDENTIFIER: {
                    // immutable auto peek_iden = peek_token();
                    immutable auto peek_iden_succ = peek_token(1);
                    if (peek_iden_succ.kind == CharType.MARK && peek_iden_succ.content == ":") {
                        // label definition (only if single mark)
                        auto label_name = expect_token(CharType.IDENTIFIER);
                        expect_token(CharType.MARK); // eat the mark
                        define_label(label_name.content); // create label
                        break;
                    } else if (peek_iden_succ.kind == CharType.BIND) {
                        // macro definition
                        auto macro_name = expect_token(CharType.IDENTIFIER);
                        expect_token(CharType.BIND); // eat the bind
                        define_macro(macro_name.content); // define the macro
                        break;
                    } else {
                        // this is an instruction
                        auto next_statements = walk_statements();
                        statements ~= next_statements;
                        // we can get away with updating offset later
                        // because macros aren't legal in these blocks
                        global_offset += next_statements.length * INSTRUCTION_SIZE;
                    }
                    break;
                }
            default:
                CharType unexpected_type = next.kind;
                throw parser_error_token(format("unexpected of type: %s",
                        to!string(unexpected_type)), next);

            }
        }

        // check for entry point label
        if (entry_label) {
            // resolve the label and replace the entry jump
            immutable auto entry_label_def = resolve_label(entry_label);
            immutable auto entry_addr = entry_label_def.offset;
            log_put(format("entry point: (%s) %06x", entry_label, entry_addr));
            statements.data[0] = AbstractStatement(OpCode.JMI, cast(ValueArg) ValueImm(entry_addr));
            // immutable ubyte entry_addr_l8 = cast(ubyte)((entry_addr >> 0) & 0xff);
            // immutable ubyte entry_addr_m8 = cast(ubyte)((entry_addr >> 8) & 0xff);
            // immutable ubyte entry_addr_h8 = cast(ubyte)((entry_addr >> 16) & 0xff);
            // statements.data[0] = AbstractStatement(OpCode.JMI,
            //         cast(ValueArg) ValueImm(entry_addr_l8), cast(ValueArg) ValueImm(entry_addr_m8),
            //         cast(ValueArg) ValueImm(entry_addr_h8));
        }
        // resolve statements, rewriting them
        auto resolved_statements = resolve_statements(statements);

        auto ast = ProgramAst(resolved_statements, data_blocks);
        return ast;
    }

    /** convert all value references in instructions to immediate values (compute all offsets, replacing symbols) */
    private AbstractStatement[] resolve_statements(
            ref const Appender!(AbstractStatement[]) statements) {
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

    /** get all the tokens that make up the next register arg */
    private Token[] take_register_arg_tokens() {
        return [expect_token(CharType.IDENTIFIER)];
    }

    /** get all the tokens that make up the next value arg */
    private Token[] take_value_arg_tokens() {
        auto tokens = Token[].init;
        immutable auto next = peek_token();
        switch (next.kind) {
        case CharType.MARK: {
                // this is a label reference
                tokens ~= expect_token(CharType.MARK); // label ref mark
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
        case CharType.IDENTIFIER: {
                // could be a macro arg
                tokens ~= expect_token(CharType.IDENTIFIER);
                break;
            }
        default:
            throw parser_error_token(format("unrecognized value arg"), next);
        }
        return tokens;
    }

    /** walk through the tokens, parsing statements. could be a single statement or an unrolled macro. */
    private AbstractStatement[] walk_statements() {
        auto statements = appender!(AbstractStatement[]);
        auto maybe_raw_statement = take_raw_statement();
        if (!maybe_raw_statement.isNull) {
            // standard instruction
            auto statement = parse_statement(maybe_raw_statement.get());
            statements ~= statement; // push statement
        } else {
            // it was not an instruction, perhaps it's a macro
            auto macro_ref_token = expect_token(CharType.IDENTIFIER);
            auto md = resolve_macro(macro_ref_token.content);
            // expand the macro
            auto unrolled_macro = expand_macro(md);
            statements ~= unrolled_macro;
        }
        return statements.data;
    }

    public Nullable!SourceStatement take_raw_statement() {
        immutable auto mnem_token = peek_token();
        immutable auto maybeInfo = InstructionEncoding.get_info(mnem_token.content);
        string a1, a2, a3;

        if (maybeInfo.isNull) { // didn't match standard instruction names
            return Nullable!SourceStatement.init;
        }

        expect_token(CharType.IDENTIFIER); // eat the mnemonic token

        // fill in arguments
        auto statement = SourceStatement(mnem_token.content);
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

    /** interpret numeric constant */
    private int parse_numeric(string num) {
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
        case '#': {
                // interpret as base-10
                val = to!int(num_str);
                break;
            }
        default:
            // invalid numeric type (by prefix)
            throw parser_error(format("invalid numeric prefix: '%c'", pfx));
        }
        // log_put(format("parsed numeric '%s' as %d", num, val));
        return val;
    }

    public bool is_register_arg(Token[] tokens) {
        if (tokens.length < 1)
            return false;
        immutable auto next = tokens[0];
        if ((next.kind & CharType.IDENTIFIER) == 0)
            return false;
        try {
            auto reg = InstructionEncoding.get_register(next.content);
            return true;
        } catch (ConvException) {
            return false;
        }
    }

    /** parse a special register arg from tokens */
    private ValueImm parse_register_arg(Token[] tokens) {
        auto register_token = tokens[0];
        return ValueImm(InstructionEncoding.get_register(register_token.content));
    }

    /** parse a special value arg from tokens */
    private ValueArg parse_value_arg(Token[] tokens) {
        auto pos = 0;
        immutable auto next = tokens[pos];

        switch (next.kind) {
        case CharType.MARK: {
                // this is a label reference
                immutable auto label_token = tokens[++pos];
                auto offset = 0;
                if (tokens.length > 2) {
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
            throw parser_error_token(format("unrecognized value arg of type %s",
                    to!string(next.kind)), next);
        }
    }

    /** given a source statement containing tokens, parse to an AST statement */
    public AbstractStatement parse_statement(SourceStatement raw_statement) {
        auto maybeInfo = InstructionEncoding.get_info(raw_statement.mnem);
        auto info = maybeInfo.get();
        auto statement = AbstractStatement(info.op);

        // read in args from tokens
        if ((info.operands & Operands.K_R1) > 0) {
            statement.a1 = parse_register_arg(raw_statement.a1);
        } else if ((info.operands & Operands.K_I1) > 0) {
            statement.a1 = parse_value_arg(raw_statement.a1);
        }
        if ((info.operands & Operands.K_R2) > 0) {
            statement.a2 = parse_register_arg(raw_statement.a2);
        } else if ((info.operands & Operands.K_I2) > 0) {
            statement.a2 = parse_value_arg(raw_statement.a2);
        }
        if ((info.operands & Operands.K_R3) > 0) {
            statement.a3 = parse_register_arg(raw_statement.a3);
        } else if ((info.operands & Operands.K_I3) > 0) {
            statement.a3 = parse_value_arg(raw_statement.a3);
        }

        return statement;
    }

    /** resolve any references in this arg and convert it to an immediate */
    private ValueImm resolve_value_arg(const ValueArg arg) {
        auto val = 0;
        if (arg.hasValue) {
            val = arg.visit!((ValueImm imm) => imm.val,
                    (ValueRef ref_) => resolve_label(ref_.label).offset + ref_.offset);
        }
        return ValueImm(val);
    }

    /** define a label */
    private void define_label(string name) {
        labels ~= LabelDef(name, global_offset);
    }

    /** resolve a label */
    private LabelDef resolve_label(string name) {
        // find the label
        foreach (label; labels.data) {
            if (label.name == name) {
                return label;
            }
        }
        throw parser_error(format("label could not be resolved: %s", name));
    }

    /** define a macro */
    private void define_macro(string name) {
        // writefln("DEFINE_MACRO %s", name);
        auto def = MacroDef(name);
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
        auto statements = appender!(SourceStatement[]);
        while (true) {
            immutable auto next = peek_token();
            if (next.kind == CharType.MARK && next.content == "::") {
                expect_token(CharType.MARK); // end of macro def
                break;
            }
            // otherwise, we should have instruction statements
            auto maybe_raw_statement = take_raw_statement();
            // TODO: consolidate this with the standard statement reader
            // to allow calling macros from macros
            // difficult because walk_statements() returns AbstractStatement

            if (!maybe_raw_statement.isNull) {
                statements ~= maybe_raw_statement.get();
            } else {
                // unrecognized mnemonic
                auto mnem_token = expect_token(CharType.IDENTIFIER);
                throw parser_error_token(format("unrecognized mnemonic within macro '%s'",
                        name), mnem_token);
            }
        }
        def.statements = statements.data;
        macros ~= def; // append to macro list
    }

    /** resolve a macro */
    private MacroDef resolve_macro(string name) {
        // find the macro
        foreach (macro_; macros.data) {
            if (macro_.name == name) {
                return macro_;
            }
        }
        throw parser_error(format("macro could not be resolved: %s", name));
    }

    /** unroll a macro reference into a series of AST instructions */
    private AbstractStatement[] expand_macro(ref MacroDef def) {
        auto statements = appender!(AbstractStatement[]);

        Token[][string] given_args;
        // get the given args
        foreach (def_arg; def.args) {
            switch (def_arg.type) {
            case MacroArg.Type.VALUE:
                auto arg_tokens = take_value_arg_tokens();
                given_args[def_arg.name] = arg_tokens;
                break;
            case MacroArg.Type.REGISTER:
                auto arg_tokens = take_register_arg_tokens();
                given_args[def_arg.name] = arg_tokens;
                break;
            default:
                assert(0);
            }
        }

        Token[] resolve_identifiers(Token[] tokens) {
            if (tokens.length < 1)
                return tokens;
            // check first token, if it's an identifier
            auto first_token = tokens[0];
            if ((first_token.kind & CharType.IDENTIFIER) > 0) {
                // match name to args
                if (first_token.content in given_args) {
                    // the token references an argument that was passed to the macro
                    auto arg_name = first_token.content;
                    return given_args[arg_name];
                }
            }
            // untouched
            return tokens;
        }

        // iterate through statements, replacing arguments then parsing the statements
        foreach (def_statement; def.statements) {
            // resolve all identifiers
            auto resolved_statement = SourceStatement(def_statement.mnem, resolve_identifiers(def_statement.a1),
                    resolve_identifiers(def_statement.a2), resolve_identifiers(def_statement.a3));
            // parse the statement
            auto parsed_statement = parse_statement(resolved_statement);
            statements ~= parsed_statement;
        }

        return statements.data;
    }

    private Token peek_token(int offset = 0) {
        // if at end, unknown
        if (token_pos + offset >= lexed.tokens.length) {
            return Token(string.init, CharType.UNKNOWN);
        }
        return lexed.tokens[token_pos + offset];
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
        return new ParserException(format("%s on line %d at token '%s'",
                message, token.line, token.content));
    }
}
