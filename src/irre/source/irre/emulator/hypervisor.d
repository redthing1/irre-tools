module irre.emulator.hypervisor;

import irre.util;
import irre.emulator.vm;
import irre.disassembler.reader;
import irre.disassembler.dumper;
import irre.encoding.instructions;
import irre.emulator.devices;
import std.stdio;
import std.conv;
import std.string;
import std.functional : toDelegate;
import core.stdc.ctype;

enum SIMPLE_REGISTER_COUNT = 6;

class Hypervisor {
    public VirtualMachine vm;
    public bool debug_mode;
    public bool onestep_mode;
    public bool full_regdump = false;
    public bool print_commits = false;
    public string runto_instruction = null;
    public Reader reader;
    public Dumper dumper;

    this(VirtualMachine vm) {
        this.vm = vm;
        reader = new Reader();
        dumper = new Dumper(Dumper.DumpStyle.Detailed);
    }

    void add_default_devices() {
        vm.attach_device(new PingDevice());
        vm.attach_device(new TerminalDevice());
        vm.attach_device(new RandomDevice());
    }

    void add_debug_interrupt_handlers() {
        vm.custom_interrupt_handler = &interrupt_handler;
        vm.custom_halt_handler = &halt_handler;
        vm.custom_commit_handler = &commit_handler;
    }

    void interrupt_handler(UWORD code) {
        switch (code) {
        case VirtualMachine.DebugInterrupts.BREAK:
            writefln("[int] BREAK");
            dump_registers(full_regdump); // minidump
            debug_prompt_loop();
            break;
        case VirtualMachine.DebugInterrupts.MEMORY_FAULT:
            writefln("[int] MEMORY_FAULT");
            dump_registers(true); // full dump
            // dump_stack();
            debug_prompt_loop();
            break;
        case VirtualMachine.DebugInterrupts.ILLEGAL_INSTRUCTION:
            writefln("[int] ILLEGAL INSTRUCTION");
            dump_registers(true); // full dump
            // dump_stack();
            debug_prompt_loop();
            break;
        case VirtualMachine.DebugInterrupts.UNKNOWN_DEVICE:
            writefln("[int] UNKNOWN DEVICE");
            dump_registers(true); // full dump
            // dump_stack();
            debug_prompt_loop();
            break;
        default: {
                writefln("[int] unhandled interrupt %d", code);
                break;
            }
        }
    }

    void halt_handler(UWORD code) {
        writefln("[halt] code %d", code);
        dump_registers(true); // full dump
    }

    void commit_handler(Commit commit) {
        if (print_commits) {
            writefln("[commit] %s", commit);
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

    void debug_prompt_loop() {
        while (onestep_prompt()) {
        }
    }

    void run(long until = 0) {
        auto exec_st = true;
        while (exec_st) {
            // pre-instruction
            auto instr = vm.decode_instruction();
            auto statement = reader.decompile(instr);
            if (debug_mode) {
                auto statement_dump = dumper.format_statement(statement);
                writefln("[exec] %s", statement_dump);
            }
            if (debug_mode) {
                // check runto instruction
                if (runto_instruction != null) {
                    if (statement.op.to!string.toLower == runto_instruction) {
                        writefln("[dbg] runto hit instruction '%s'", runto_instruction);
                        runto_instruction = null;
                        // break
                        debug_prompt_loop();
                    }
                }
            }
            exec_st = vm.step();
            // post-instruction
            if (debug_mode) {
                // print branch state
                switch (vm.last_branch_status) {
                case VirtualMachine.BranchStatus.TAKEN:
                    writefln("[dbg] branch TAKEN");
                    break;
                case VirtualMachine.BranchStatus.NOT_TAKEN:
                    writefln("[dbg] branch NOT TAKEN");
                    break;
                default:
                    break;
                }
                dump_registers(full_regdump); // minidump
            }
            if (onestep_mode) {
                debug_prompt_loop();
            }

            // check until condition
            if (until > 0) {
                if (vm.ticks >= until) {
                    break;
                }
            }
        }
        // done.

        if (debug_mode) {
            dump_registers(true); // full dump
        }
        log_put(format("halted after %d cycles with code $%04x (#%04d).",
                vm.ticks, vm.reg[Register.R0], vm.reg[Register.R0]));
        // add a final snapshot
        vm.commit_snapshot();
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

    void dump_memory_at(UWORD addr, UWORD size) {
        writefln("== memory dump ==");
        // show this as a per-byte hexdump
        // 00000000: abcd ef12 3456 789a
        // etc.
        for (UWORD i = 0; i < size; i += 16) {
            writef("%08x: ", addr + i);
            for (UWORD j = 0; j < 16; j += 2) {
                immutable BYTE b1 = vm.mem[addr + i + j];
                immutable BYTE b2 = vm.mem[addr + i + j + 1];
                writef("%02x%02x ", b1, b2);
            }
            writefln("");
        }
        writefln("\n=== === ===");
    }

    void run_command(string command) {
        // split command
        auto cmd = command.split(" ");
        auto cmd_name = cmd[0];
        switch (cmd_name) {
        case "stk":
            dump_stack();
            break;
        case "reg":
            dump_registers(true);
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
        case "mem":
            // expect: mem <addr> <size>
            if (cmd.length < 3) {
                writefln("[cmd] mem <$addr> <size>");
                break;
            }
            auto addr = (cmd[1].replace("$", "")).to!UWORD(16);
            auto size = cmd[2].to!UWORD();
            dump_memory_at(addr, size);
            break;
        case "rti":
            runto_instruction = cmd[1];
            writefln("[cmd] will break on instruction '%s'", runto_instruction);
            // disable onestep mode
            onestep_mode = false;
            break;
        default:
            writefln("[cmd] command '%s' not recognized.", command);
            break;
        }
    }

    void enable_commit_log() {
        vm.log_commits = true;
        // add an initial snapshot
        vm.commit_snapshot();
    }
}
