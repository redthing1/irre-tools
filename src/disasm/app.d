module disasm.app;

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
bool verbose;

int main(string[] args) {
    writefln("[IRRE] disassembler v%s", Meta.VERSION);
    auto help = getopt(args, "verbose|v", &verbose);

    if (help.helpWanted || args.length != 2) {
        defaultGetoptPrinter("./irre-disasm [OPTIONS] <input> <output>", help.options);
        return 1;
    }

    input_file = args[1];

    auto compiled_data = cast(const(ubyte)[]) std.file.read(input_file);

    return 0;
}
