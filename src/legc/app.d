module legc.app;

import std.stdio;
import std.getopt;
import std.conv;
import std.file;
import std.algorithm;
import std.array;
import irre.util;
import irre.meta;
import irre.translator.leg;

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
    IRRE_TOOLS_VERBOSE = verbose;

    input_file = args[1];
    output_file = args[2];

    string[] in_lines;
    try {
        auto in_file = File(input_file);
        in_lines = in_file.byLineCopy() // read persistent lines
            .array(); // into an array
    } catch (FileException e) {
        writefln("could not read from file: %s\n%s", e.file, e.msg);
        return 2;
    }

    auto translator = new LegTranslator();
    auto out_lines = translator.translate(in_lines);

    auto ou_file = File(output_file, "w+");
    out_lines.each!(line => ou_file.writeln(line));

    return 0;
}
