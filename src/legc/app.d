module legc.app;

import std.stdio;
import std.getopt;
import std.conv;
import std.file;
import std.algorithm.searching;
import std.range;
import std.array;
import irre.meta;
import irre.assembler.lexer;
import irre.assembler.parser;
import irre.encoding.rega;
import irre.disassembler.dumper;

string input_file;
string output_file;
bool verbose;
bool dump;

int main(string[] args) {
    writefln("[IRRE] LEG converter v%s", Meta.VERSION);
    auto help = getopt(args, "verbose|v", &verbose, "dump", &dump);

    if (help.helpWanted || args.length != 3) {
        defaultGetoptPrinter("./irre-asm [OPTIONS] <input> <output>", help.options);
        return 1;
    }

    input_file = args[1];
    output_file = args[2];

    try {
        auto in_file = File(input_file);
        auto ou_file = File(output_file, "w+");
        auto in_lines = in_file.byLine();
        foreach (line; in_lines) {
            // convert the line
            string conv_line;
            // check if starts with tab
            if (line.startsWith('\t')) {
                // statement
                // if starts with ".", it's a directive
                auto statement = line.drop(1);
                writefln("STATEMENT: %s", statement);
                if (statement.startsWith('.')) {
                    conv_line = cast(string) ("; " ~ statement);
                } else {
                    // instruction statement
                    auto instruction = cast(string) statement;

                    // replace imm references in set
                    instruction = instruction.replace("::#", "#");

                    conv_line = instruction;
                }
                // re-add the tab
                conv_line = cast(string) ('\t' ~ conv_line);
            } else {
                // label
                auto label = line;
                writefln("LABEL: %s", label);
                conv_line = cast(string) label;
            }

            ou_file.writeln(conv_line);
        }
    } catch (FileException e) {
        writefln("could not read from file: %s\n%s", e.file, e.msg);
        return 2;
    }

    return 0;
}
