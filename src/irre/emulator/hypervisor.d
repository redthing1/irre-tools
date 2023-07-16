module irre.emulator.hypervisor;

import irre.emulator.vm;
import irre.disassembler.reader;
import irre.disassembler.dumper;
import irre.encoding.instructions;
import irre.emulator.devices.ping;
import irre.emulator.devices.terminal;
import std.stdio;
import std.conv;
import std.string;
import std.functional : toDelegate;

enum SIMPLE_REGISTER_COUNT = 6;

class Hypervisor {
    public VirtualMachine vm;
    public bool debug_mode;
    public bool onestep_mode;
    public Reader reader;
    public Dumper dumper;

    public enum DebugInterrupts {
        BREAK = 0xa0,
    }

    this(VirtualMachine vm) {
        this.vm = vm;
        reader = new Reader();
        dumper = new Dumper(Dumper.Mode.Detailed);
    }

    void add_default_devices() {
        // ping
        vm.attach_device(new PingDevice());
        // terminal
        vm.attach_device(new TerminalDevice());
    }

    void add_debug_interrupt_handlers() {
        vm.custom_interrupt_handler = &interrupt;
    }

    void interrupt(UWORD code) {
        switch (code) {
        case DebugInterrupts.BREAK:
            writefln("[int] BREAK");
            dump_registers(false); // minidump
            onestep_prompt();
            break;
        default: {
                writefln("[int] unhandled interrupt %d", code);
                break;
            }
        }
    }

    bool onestep_prompt() {
        // pause
        write("[emu]$ ");
        auto command = readln().strip();
        if (command.length > 0) {
            run_command(command);
        } else {
            return false; // stop looping
        }
        return true; // loop again
    }

    void run() {
        auto exec_st = true;
        while (exec_st) {
            // pre-instruction
            auto instr = vm.decode_instruction();
            auto statement = reader.decompile(instr);
            if (debug_mode) {
                auto statement_dump = dumper.format_statement(statement);
                writefln("[exec] %s", statement_dump);
            }
            exec_st = vm.step();
            // post-instruction
            if (debug_mode) {
                if (vm.took_branch) {
                    writefln("[dbg] took branch");
                }
                dump_registers(false); // minidump
            }
            if (onestep_mode) {
                while (onestep_prompt()) {
                }
            }
        }
        // done.

        if (debug_mode) {
            dump_registers(true); // full dump
        }
        writefln("halted after %d cycles with code $%04x.", vm.ticks, vm.reg[Register.R0]);
    }

    void dump_registers(bool full) {
        // dump registers
        void dump_register(ARG reg_id) {
            writefln("%5s: $%08x", to!Register(reg_id), vm.reg[reg_id]);
        }

        dump_register(Register.PC);

        auto dump_regs = SIMPLE_REGISTER_COUNT;
        if (full) {
            dump_regs = REGISTER_COUNT;
        }
        for (ARG i = 0; i < dump_regs; i++) {
            dump_register(i);
        }
        if (!full) { // dump special registers even in a small dump
            dump_register(Register.LR);
            dump_register(Register.AD);
            dump_register(Register.AT);
            dump_register(Register.SP);
        }
    }

    void dump_stack() {
        writefln("== stack dump ==");
        immutable UWORD sp = vm.reg[Register.SP];
        for (UWORD addr = sp; addr < vm.mem.length; addr += UWORD.sizeof) {
            immutable UWORD data = vm.mem[addr + 0] << 0 | vm.mem[addr + 1] << 8
                | vm.mem[addr + 2] << 16 | vm.mem[addr + 3] << 24;
            writef("$%04x ", data);
        }
        writefln("\n=== === ===");
    }

    void run_command(string command) {
        switch (command) {
        case "stk":
            dump_stack();
            break;
        case "s1":
            writefln("[cmd] ONESTEP = 1, DEBUG = 1");
            onestep_mode = true;
            debug_mode = true;
            break;
        case "s0":
            writefln("[cmd] ONESTEP = 0");
            onestep_mode = false;
            break;
        default:
            writefln("[cmd] command '%s' not recognized.", command);
            break;
        }
    }
}
