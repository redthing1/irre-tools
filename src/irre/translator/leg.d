module irre.translator.leg;

import std.stdio;
import std.algorithm.searching;
import std.range;
import std.array;
import irre.meta;
import irre.assembler.lexer;
import irre.assembler.parser;
import irre.assembler.ast;

class LegTranslator {
    string[] translate(string[] source_lines) {
        // create a lexer for tokenizing use
        auto lexer = new Lexer();
        auto parser = new Parser();

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

                    // now, tokenize the instruction
                    auto lexed = lexer.lex(instruction);
                    parser.load_lex(lexed);
                    auto source_statement = parser.take_raw_statement().get();
                    writefln("  OP %s", source_statement.mnem);
                    // rewrite certain instructions (add, sub) to (adi, sbi) when relevant

                    conv_line = instruction;
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
}
