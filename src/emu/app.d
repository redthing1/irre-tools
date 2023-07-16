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

int main(string[] args) {
    writefln("[IRRE] emulator v%s", Meta.VERSION);
    auto help = getopt(args, "verbose|v", &verbose);

    if (help.helpWanted || args.length != 2) {
        defaultGetoptPrinter("./irre-emu [OPTIONS] <input>", help.options);
        return 1;
    }

    input_file = args[1];

    auto compiled_data = cast(const(ubyte)[]) std.file.read(input_file);

    auto reader = new Reader();
    auto programAst = reader.read(compiled_data);

    // auto dumper = new Dumper(clean ? Dumper.Mode.Clean : Dumper.Mode.Detailed);
    // dumper.dump_statements(programAst.statements);

    return 0;
}
