module irre.translator.leg;

import std.stdio;
import std.algorithm.searching;
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

            out_lines ~= conv_line;
        }

        return out_lines.data;
    }

    string rewrite_instruction(string raw_instruction) {
        // now, tokenize the instruction
        auto lexed = lexer.lex(raw_instruction);
        parser.load_lex(lexed);
        auto maybe_source_statement = parser.take_raw_statement();
        if (maybe_source_statement.isNull) {
            writefln("  unimplemented instruction");
            return "; UNIMPLEMENTED: " ~ raw_instruction;
        }
        auto source_statement = maybe_source_statement.get();
        writefln("  OP %s", source_statement.mnem);
        switch (source_statement.mnem) {
            case "add":
            case "sub":
                // rewrite to 'adi' and 'sbi' when A3 is imm

                break;
            default:
                break; // we don't care
        }

        auto rewritten = source_statement.dump();
        return rewritten;
    }
}
