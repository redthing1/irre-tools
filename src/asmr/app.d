module asmr.app;

import std.stdio;
import std.getopt;
import std.file;
import irre.meta;

string input_file;
string output_file;
bool verbose;

int main(string[] args) {
    writefln("[IRRE] assembler v%s", Meta.VERSION);
    auto help = getopt(args, "verbose|v", &verbose);

    if (help.helpWanted || args.length != 3) {
        defaultGetoptPrinter("./irre-asm [OPTIONS] <input> <output>", help.options);
        return 1;
    }

    input_file = args[1];
    output_file = args[2];

    auto inf_source = std.file.readText(input_file);
    // run assembler

    return 0;
}
