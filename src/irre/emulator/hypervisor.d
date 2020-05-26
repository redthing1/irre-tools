module irre.emulator.hypervisor;

import irre.emulator.vm;
import irre.disassembler.reader;
import irre.disassembler.dumper;
import std.stdio;

class Hypervisor {
    public VirtualMachine vm;
    public bool debug_mode;
    public bool onestep_mode;
    public Reader reader;
    public Dumper dumper;

    this(VirtualMachine vm) {
        this.vm = vm;
        reader = new Reader();
        dumper = new Dumper(Dumper.Mode.Detailed);
    }

    void run() {
        auto exec_st = true;
        while (exec_st) {
            // pre-instruction
            // print out the instruction
            auto instr = vm.decode_instruction();
            auto statement = reader.decompile(instr);
            auto statement_dump = dumper.format_statement(statement);
            writefln("[EXEC] %s", statement_dump);
            exec_st = vm.step();
            // post-instruction
        }
    }
}
