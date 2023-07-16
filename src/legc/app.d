module legc.app;

import std.stdio;
import std.getopt;
import std.conv;
import std.file;
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
            auto conv_line = line;
            ou_file.writeln(conv_line);
        }
    } catch (FileException e) {
        writefln("could not read from file: %s\n%s", e.file, e.msg);
        return 2;
    }

    return 0;
}
