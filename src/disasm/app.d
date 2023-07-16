module disasm.app;

import std.stdio;
import std.getopt;
import std.file;
import irre.meta;
import irre.assembler.parser;
import irre.disassembler.dumper;
import irre.disassembler.reader;

string input_file;
bool verbose;
bool clean;

int main(string[] args) {
    auto help = getopt(args, "verbose|v", &verbose, "clean|c", &clean);
    if (clean) {
        write("; "); // comment
    }
    writefln("[IRRE] disassembler v%s", Meta.VERSION);

    if (help.helpWanted || args.length != 2) {
        defaultGetoptPrinter("./irre-disasm [OPTIONS] <input>", help.options);
        return 1;
    }

    input_file = args[1];

    auto compiled_data = cast(const(ubyte)[]) std.file.read(input_file);

    auto reader = new Reader();
    auto programAst = reader.read(compiled_data);

    auto dumper = new Dumper(clean ? Dumper.Mode.Clean : Dumper.Mode.Detailed);
    dumper.dump_statements(programAst);

    return 0;
}
