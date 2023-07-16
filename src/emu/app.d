module disasm.app;

import std.stdio;
import std.getopt;
import std.file;
import irre.meta;
import irre.assembler.parser;
import irre.disassembler.dumper;
import irre.disassembler.reader;
import irre.emulator.vm;
import irre.emulator.hypervisor;

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

    auto vm = new VirtualMachine();
    vm.initialize();

    // load the program
    auto header = vm.load(compiled_data);
    // dump the header
    auto dumper = new Dumper(Dumper.Mode.Detailed);
    dumper.dump_header(header);

    // create a hypervisor
    auto hyp = new Hypervisor(vm);

    // start the emulator
    hyp.run();

    return 0;
}
