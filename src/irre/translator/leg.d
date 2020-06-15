module irre.translator.leg;

import std.stdio;
import std.algorithm.searching;
import std.string;
import std.conv;
import std.range;
import std.regex;
import std.array;
import irre.util;
import irre.assembler.lexer;
import irre.assembler.parser;
import irre.assembler.ast;

/** translates LEG assembly to IRRE assembly */
class LegTranslator {
    private Lexer lexer = new Lexer(); // create a lexer for tokenizing use
    private Parser parser = new Parser(); // use a parser to semantically understand tokens

    string[] translate(string[] source_lines) {
        auto out_lines = appender!(string[]);

        // add an entry main directive
        out_lines ~= "%entry: main";

        foreach (line; source_lines) {
            // convert the line
            string conv_line;
            // check if starts with tab
            if (line.startsWith('\t')) {
                // statement
                // if starts with ".", it's a directive
                auto statement = line.drop(1); // skip the tab at the beginning
                log_put(format("STATEMENT: %s", statement));
                if (statement.startsWith('.')) {
                    auto directive = cast(string) statement;
                    auto rewritten_directive = rewrite_directive(directive);
                    conv_line = rewritten_directive;
                } else {
                    // instruction statement
                    auto instruction = cast(string) statement;

                    // strip commas
                    instruction = instruction.replace(",", "");
                    // replace imm references in set
                    instruction = instruction.replace("::#", "#");

                    auto rewritten_instruction = rewrite_instruction(instruction);
                    log_put(format("  T %s", rewritten_instruction));

                    conv_line = rewritten_instruction;
                }
                // re-add the tab
                conv_line = cast(string)('\t' ~ conv_line);
            } else {
                // label
                auto label = line;
                log_put(format("LABEL: %s", label));
                conv_line = cast(string) label;
            }

            out_lines ~= strip(conv_line, "", " ");
        }

        return out_lines.data;
    }

    string rewrite_instruction(string raw_instruction) {

        /** remap instruction mnemonics */
        void remap_instructions(ref Token[] tokens) {
            auto mnem = tokens[0].content;
            switch (mnem) {
            case "b_to":
                mnem = "jmi";
                break;
            case "brl":
                mnem = "cal";
                break;
            case "cmp":
                mnem = "tcu";
                // we rewrite CMP rA rB -> TCU ad rA rB
                tokens.insertInPlace(1, Token("ad", CharType.IDENTIFIER));
                break;
            // case "b_eq":
            //     // rewrite B_EQ v0 to BIF ad v0 #0
            //     mnem = "bif";
            //     auto tc_val = 0;
            //     tokens.insertInPlace(1, Token("ad", CharType.IDENTIFIER));
            //     tokens ~= Token("#" ~ to!string(tc_val), CharType.NUMERIC_CONSTANT);
            //     break;
            // case "b_lt":
            //     // rewrite B_LT v0 to BIF ad v0 #-1
            //     mnem = "bif";
            //     auto tc_val = -1;
            //     tokens.insertInPlace(1, Token("ad", CharType.IDENTIFIER));
            //     tokens ~= Token("#" ~ to!string(tc_val), CharType.NUMERIC_CONSTANT);
            //     break;
            // case "b_gt":
            //     // rewrite B_LT v0 to BIF ad v0 #1
            //     mnem = "bif";
            //     auto tc_val = 1;
            //     tokens.insertInPlace(1, Token("ad", CharType.IDENTIFIER));
            //     tokens ~= Token("#" ~ to!string(tc_val), CharType.NUMERIC_CONSTANT);
            //     break;
            // case "b_gt":
            //     // rewrite B_LT v0 to BIF ad v0 #1
            //     mnem = "bif";
            //     auto tc_val = 1;
            //     tokens.insertInPlace(1, Token("ad", CharType.IDENTIFIER));
            //     tokens ~= Token("#" ~ to!string(tc_val), CharType.NUMERIC_CONSTANT);
            //     break;
            default:
                break;
            }
            if (mnem != tokens[0].content) {
                log_put(format("      rewrote MNEM: %s -> %s", tokens[0].content, mnem));
            }
            tokens[0].content = mnem;
        }

        /** remap register names */
        void remap_registers(ref Token[] tokens) {
            if (tokens.length > 0 && (tokens[0].kind & CharType.IDENTIFIER) > 0) {
                auto reg = tokens[0].content;
                // rewrite rules
                // reg = reg.replace("r0", "rv");
                if (reg != tokens[0].content) {
                    log_put(format("      rewrote REG: %s -> %s", tokens[0].content, reg));
                }
                tokens[0].content = reg;
            }
        }

        // now, tokenize the instruction
        auto lexed = lexer.lex(raw_instruction);
        remap_instructions(lexed.tokens);
        parser.load_lex(lexed);
        auto maybe_source_statement = parser.take_raw_statement();
        if (maybe_source_statement.isNull) {
            log_put(format("  unimplemented instruction"));
            return "; UNIMPLEMENTED: " ~ raw_instruction;
        }
        auto source_statement = maybe_source_statement.get();
        // remap registers
        remap_registers(source_statement.a1);
        remap_registers(source_statement.a2);
        remap_registers(source_statement.a3);

        log_put(format("  OP %s", source_statement.mnem));

        switch (source_statement.mnem) {
        case "add":
            // rewrite to 'adi' when A3 is imm
            if (!parser.is_register_arg(source_statement.a3)) {
                source_statement.mnem = "adi";
            }
            break;
        case "sub":
            // rewrite to 'sbi' when A3 is imm
            if (!parser.is_register_arg(source_statement.a3)) {
                source_statement.mnem = "sbi";
            }
            break;
        case "tcu":
            // check if this is a CMP-style TCU
            // tcu R R rather than tcu R R R
            break;
        default:
            break; // we don't care
        }

        auto rewritten = source_statement.dump();
        return rewritten;
    }

    string rewrite_directive(string directive) {
        auto result = format("; %s", directive);
        // fixed rewrite rules
        if (directive.startsWith(".size\tmain")) {
            result = "hlt ;" ~ directive;
        } else if (directive.startsWith(".size\t")) {
            // generic .size directives
            auto groups = matchFirst(directive, regex(`(?:.size\W)(?P<name>\w+),\W(?P<len>[0-9]+)`));
            auto name = groups["name"];
            auto size_str = groups["len"];
            try {
                auto block_size = to!int(size_str);
                result = format("%%d \\z %d ; %s", block_size, directive);
                log_put(format("    inserted data block [%d] for '%s'", block_size, name));
            } catch (ConvException) {
                log_put(format("   unmatched: %s", directive));
            }
        }
        return result;
    }
}
