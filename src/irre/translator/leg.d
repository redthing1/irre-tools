module irre.translator.leg;

import std.stdio;
import std.algorithm.searching;
import std.string;
import std.conv;
import std.range;
import std.array;
import irre.meta;
import irre.assembler.lexer;
import irre.assembler.parser;
import irre.assembler.ast;

/** translates LEG assembly to IRRE assembly */
class LegTranslator {
    private Lexer lexer = new Lexer(); // create a lexer for tokenizing use
    private Parser parser = new Parser(); // use a parser to semantically understand tokens

    string[] translate(string[] source_lines) {
        auto out_lines = appender!(string[]);

        foreach (line; source_lines) {
            // convert the line
            string conv_line;
            // check if starts with tab
            if (line.startsWith('\t')) {
                // statement
                // if starts with ".", it's a directive
                auto statement = line.drop(1);
                writefln("STATEMENT: %s", statement);
                if (statement.startsWith('.')) {
                    conv_line = cast(string)("; " ~ statement);
                } else {
                    // instruction statement
                    auto instruction = cast(string) statement;

                    // strip commas
                    instruction = instruction.replace(",", "");
                    // replace imm references in set
                    instruction = instruction.replace("::#", "#");

                    auto rewritten_instruction = rewrite_instruction(instruction);
                    writefln("  T %s", rewritten_instruction);

                    conv_line = rewritten_instruction;
                }
                // re-add the tab
                conv_line = cast(string)('\t' ~ conv_line);
            } else {
                // label
                auto label = line;
                writefln("LABEL: %s", label);
                conv_line = cast(string) label;
            }

            out_lines ~= strip(conv_line, "", " ");
        }

        return out_lines.data;
    }

    string rewrite_instruction(string raw_instruction) {

        void remap_instructions(Token[] tokens) {
            auto mnem = tokens[0].content;
            switch (mnem) {
            case "b_to":
                mnem = "jmi";
                break;
            default:
                break;
            }
            if (mnem != tokens[0].content) {
                writefln("      rewrote MNEM: %s -> %s", tokens[0].content, mnem);
            }
            tokens[0].content = mnem;
        }

        /** remap register names */
        void remap_registers(Token[] tokens) {
            if (tokens.length > 0 && (tokens[0].kind & CharType.IDENTIFIER) > 0) {
                auto reg = tokens[0].content;
                // rewrite rules
                reg = reg.replace("r0", "rv");
                if (reg != tokens[0].content) {
                    writefln("      rewrote REG: %s -> %s", tokens[0].content, reg);
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
            writefln("  unimplemented instruction");
            return "; UNIMPLEMENTED: " ~ raw_instruction;
        }
        auto source_statement = maybe_source_statement.get();
        // remap registers
        remap_registers(source_statement.a1);
        remap_registers(source_statement.a2);
        remap_registers(source_statement.a3);

        writefln("  OP %s", source_statement.mnem);

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
        case "b_to":
            source_statement.mnem = "jmi";
            break;
        default:
            break; // we don't care
        }

        auto rewritten = source_statement.dump();
        return rewritten;
    }
}
