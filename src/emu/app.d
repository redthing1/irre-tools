module disasm.app;

import std.stdio;
import std.getopt;
import std.file;
import irre.util;
import irre.meta;
import irre.assembler.parser;
import irre.disassembler.dumper;
import irre.disassembler.reader;
import irre.emulator.vm;
import irre.emulator.hypervisor;

string input_file;
bool verbose;
bool debug_mode;
bool step_mode;

int main(string[] args) {
    writefln("[IRRE] emulator v%s", Meta.VERSION);
    auto help = getopt(args, "verbose|v", &verbose, "debug", &debug_mode, "step", &step_mode);

    if (help.helpWanted || args.length != 2) {
        defaultGetoptPrinter("./irre-emu [OPTIONS] <input>", help.options);
        return 1;
    }
    IRRE_TOOLS_VERBOSE = verbose;

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
    hyp.debug_mode = debug_mode;
    hyp.onestep_mode = step_mode;

    // add basic IO support
    hyp.add_default_devices();

    // start the emulator
    hyp.run();

    return 0;
}
