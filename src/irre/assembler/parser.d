module irre.assembler.parser;

import irre.util;
import irre.assembler.lexer;
public import irre.assembler.ast;
public import irre.assembler.ast_builder;
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
    private AstBuilder ast_builder;
    private SectionId current_section = SectionId.Code;

    this() {
        ast_builder = new AstBuilder();
        // define builtins
        define_builtins();
    }

    private void define_builtins() {
        auto builtins = new BuiltinMacros();
        ast_builder.push_macro(builtins.MACRO_ADI);
        ast_builder.push_macro(builtins.MACRO_SBI);
        ast_builder.push_macro(builtins.MACRO_YEET);
        ast_builder.push_macro(builtins.MACRO_CMP);
        ast_builder.push_macro(builtins.MACRO_BEQ);
        ast_builder.push_macro(builtins.MACRO_BNE);
        ast_builder.push_macro(builtins.MACRO_BLT);
        ast_builder.push_macro(builtins.MACRO_BGE);
        ast_builder.push_macro(builtins.MACRO_BGT);
        ast_builder.push_macro(builtins.MACRO_BLE);
    }

    public void load_lex(Lexer.Result lexed) {
        this.lexed = lexed;

        // reset parse counting vars
        this.token_pos = 0;
        this.char_pos = 0;
    }

    /** given a lexer result, parse tokens into a program ast. this should only ever be called once. */
    public void parse() {
        // emit entry instruction (padding that may be replaced)
        ast_builder.push_statement(AbstractStatement(OpCode.NOP));

        // parse lex result into instruction list
        while (token_pos < lexed.tokens.length) {
            immutable auto next = peek_token();
            switch (next.kind) {
            case CharType.DIRECTIVE: {
                    auto dir_token = expect_token(CharType.DIRECTIVE);
                    auto dir_type = dir_token.content[1 .. $];
                    switch (dir_type) {
                    case "entry": {
                            // entrypoint directive
                            expect_token(CharType.MARK);
                            immutable auto label_ref_tok = expect_token(CharType.IDENTIFIER);
                            // store entry label
                            ast_builder.set_entry_label(label_ref_tok.content);
                            log_put(format("entry point label: %s", label_ref_tok.content));
                            break;
                        }
                    case "d": {
                            // data directive
                            assert(current_section == SectionId.Data,
                                    "instructions are only allowed in data sections");
                            auto packed_data = take_data_declaration();
                            DataBlock block = {data: packed_data};
                            ast_builder.push_data_block(block);
                            log_put(format("data block[%d] at offset %d",
                                    block.data.length, block.offset));
                            break;
                        }
                    case "section": {
                            // section directive
                            expect_token(CharType.MARK);
                            immutable auto section_type_tok = expect_token(CharType.IDENTIFIER);
                            auto section_type = section_type_tok.content;
                            // update current section
                            switch (section_type) {
                            case "code":
                            case "text":
                                current_section = SectionId.Code;
                                break;
                            case "data":
                            case "bss":
                                current_section = SectionId.Data;
                                break;
                            default:
                                throw parser_error_token(format("unknown section type %s",
                                        to!string(section_type)), section_type_tok);
                            }
                            break;
                        }
                    default:
                        throw parser_error_token(format("unknown directive %s",
                                to!string(dir_type)), dir_token);
                    }
                    break;
                }
            case CharType.IDENTIFIER: {
                    immutable auto peek_iden_succ = peek_token(1);
                    if (peek_iden_succ.kind == CharType.MARK && peek_iden_succ.content == ":") {
                        // label definition (only if single mark)
                        auto label_name = expect_token(CharType.IDENTIFIER);
                        expect_token(CharType.MARK); // eat the mark
                        ast_builder.define_label(current_section, label_name.content); // create label
                        break;
                    } else if (peek_iden_succ.kind == CharType.BIND) {
                        // macro definition
                        assert(current_section == SectionId.Code,
                                "macro definitions are only allowed in code sections");
                        auto macro_name = expect_token(CharType.IDENTIFIER);
                        expect_token(CharType.BIND); // eat the bind
                        // read the macro body into a MacroDef
                        auto macro_def = walk_through_macro(macro_name.content);
                        ast_builder.push_macro(macro_def);
                        break;
                    } else {
                        // this is an instruction
                        assert(current_section == SectionId.Code,
                                "instructions are only allowed in code sections");
                        auto next_statements = walk_statements();
                        foreach (statement; next_statements) {
                            ast_builder.push_statement(statement);
                        }
                    }
                    break;
                }
            default:
                CharType unexpected_type = next.kind;
                throw parser_error_token(format("unexpected of type: %s",
                        to!string(unexpected_type)), next);

            }
        }
    }

    public void freeze_all_symbols() {
        ast_builder.freeze_references();
    }

    public ProgramAst to_ast() {
        return ast_builder.build();
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

    /** read a "%d" data directive and insert data blocks */
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
                        // strip off the first char and assert that it's '$'
                        auto hex_token = pack_token.content;
                        if (hex_token[0] != '$') {
                            throw parser_error_token("invalid pack data (must be hex constant, preceded by $)",
                                    pack_token);
                        }
                        auto hex_pack = hex_token[1 .. $];
                        auto pack_len = hex_pack.length;
                        if (pack_len % 2 != 0) {
                            // odd number of half-bytes, invalid
                            throw parser_error_token("invalid data (must be an even size)",
                                    pack_token);
                        }
                        pack_len = pack_len / 2; // divide by two because 0xff = 1 byte
                        auto pack_data = datahex(hex_pack); // convert data from hex
                        // copy the pack data
                        packed_data ~= pack_data;
                        break;
                    }
                case "z": {
                        auto pack_token = expect_token(CharType.NUMERIC_CONSTANT);
                        auto byte_count = parse_numeric(pack_token.content);
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
            auto maybe_md = ast_builder.resolve_macro(macro_ref_token.content);
            if (maybe_md.isNull) {
                throw parser_error_token(format("macro could not be resolved: %s",
                        macro_ref_token.content), macro_ref_token);
            }
            auto md = maybe_md.get();
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
                    auto offset_token = tokens[++pos];
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

    /** walk through and parse a macro definition */
    private MacroDef walk_through_macro(string name) {
        // writefln("walk_through_macro %s", name);
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

        return def;
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
