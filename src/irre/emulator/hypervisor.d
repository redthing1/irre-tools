module irre.emulator.hypervisor;

import irre.emulator.vm;
import irre.disassembler.reader;
import irre.disassembler.dumper;
import irre.encoding.instructions;
import std.stdio;
import std.conv;

enum SIMPLE_REGISTER_COUNT = 6;

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
            auto instr = vm.decode_instruction();
            auto statement = reader.decompile(instr);
            if (debug_mode) {
                auto statement_dump = dumper.format_statement(statement);
                writefln("[EXEC] %s", statement_dump);
            }
            exec_st = vm.step();
            // post-instruction
            if (debug_mode) {
                dump(false); // minidump
            }
            if (onestep_mode) {
                // pause
                write("[emu]$ ");
                auto input = readln();
            }
        }
        // done.

        if (debug_mode) {
            writefln("execution halted after %d cycles.", vm.ticks);
            dump(true); // full dump
        }
    }

    void dump(bool full) {
        // dump registers
        void dump_register(ARG reg_id) {
            writefln("%5s: $%08x", to!Register(reg_id), vm.reg[reg_id]);
        }

        auto dump_regs = SIMPLE_REGISTER_COUNT;
        if (full) {
            dump_regs = REGISTER_COUNT;
        }
        for (ARG i = 0; i < dump_regs; i++) {
            dump_register(i);
        }
        if (!full) { // dump special registers even in a small dump
            dump_register(Register.RV);
            dump_register(Register.LR);
            dump_register(Register.AD);
            dump_register(Register.AT);
            dump_register(Register.SP);
        }
    }
}
