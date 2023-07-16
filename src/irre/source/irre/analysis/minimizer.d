module irre.analysis.minimizer;

import std.stdio;
import std.format;
import std.conv;
import std.algorithm;
import std.range;
import std.container.dlist;

import irre.util;
import irre.emulator.commit;
import irre.assembler.ast;
import irre.encoding.instructions;
import irre.encoding.rega;
import irre.analysis.ift;

class ProgramMinimizer {
    ProgramAst source_program;
    IFTAnalyzer ift;

    this(ProgramAst program, IFTAnalyzer ift) {
        source_program = program;
        this.ift = ift;
    }

    ProgramAst create_minimized() {
        void nop_statement(AbstractStatement* statement) {
            // set opcode to NOP
            statement.op = OpCode.NOP;
            // clear operands
            statement.a1 = statement.a2 = statement.a3 = ValueImm(0);
        }

        writefln("minimizer");

        // 1. look at total clobber of mem and regs
        // essentially, for each final data node, if all its sources can be frozen,then we can precompute

        // registers
        writefln(" clobber analysis");
        bool[Register] freezable_registers;
        foreach (reg_id; ift.clobbered_regs_sources.byKey) {
            auto freezable = true;
            foreach (source; ift.clobbered_regs_sources[reg_id]) {
                // check whether this source node is freezable too
                freezable = freezable && source.is_final;
            }

            // blacklist
            if (reg_id == Register.PC)
                freezable = false;

            // now, if all sources were freezable
            if (freezable) {
                // then we can precompute this register's final value
                freezable_registers[reg_id] = true;
                log_put(format("  we are able to freeze register %s", reg_id.to!Register));
            }
        }

        writefln(" reverse walk program");
        ProgramAst prog = source_program; // copy source program
        UWORD offset = (cast(UWORD) prog.statements.length) * cast(UWORD) INSTRUCTION_SIZE;
        bool[Register] frozen_registers;
        for (int i = (cast(int) prog.statements.length - 1); i >= 0; i--) {
            offset -= INSTRUCTION_SIZE;
            auto stmt = &prog.statements[i];

            // writefln("looking at: %s", *stmt);

            // nop_statement(stmt);

            // TODO: figure out if the instruction is "freezable" ??

            // find the last commit at this pc

            auto last_commit_here_ix = ift.find_last_commit_at_pc(offset, ift.last_commit_ix);

            if (last_commit_here_ix >= 0) {
                // we found a commit that was last at this offset
                auto last_commit_here = ift.trace.commits[last_commit_here_ix];

                log_put(format("  found last commit at %04x: %s", offset, last_commit_here));

                // let's see if the sole result of this commit is a register
                auto commit_results = last_commit_here.as_nodes;
                if (commit_results.length == 1
                    && commit_results[0].type == InfoType.Register) {
                        // get that single result
                        auto result0 = commit_results[0];

                        log_put(format("   this commit has a single register result: %s", result0));

                        // get reg id of that single result
                        auto result_reg_id = result0.data.to!Register;

                        // is this register already frozen?
                        if (frozen_registers.get(result_reg_id, false)) {
                            // this register's final value is frozen
                            // so we can nop this instruction
                            nop_statement(stmt);
                            continue; // all done here
                        }
                        
                        // if this register is freezable, then can we replace this step with direct setting?
                        if (freezable_registers.get(result_reg_id, false)) {
                            // yes, we can
                            log_put(format("   commit result %s is of a freezable register %s", result0, result_reg_id));

                            auto final_reg_value = ift.snap_final.reg[result_reg_id];
                            // check if the value will fit in a single 16-bit SET instruction
                            if (final_reg_value <= 0xffff) {
                                // yes!
                                frozen_registers[result_reg_id] = true;

                                // set opcode to SET
                                stmt.op = OpCode.SET;
                                // set operands
                                stmt.a1 = ValueImm(result_reg_id);
                                stmt.a2 = ValueImm((final_reg_value & 0x00ff));
                                stmt.a3 = ValueImm((final_reg_value & 0xff00) >> 8);

                                log_put(format("   replacing with SET %s, %s, %s", stmt.a1, stmt.a2, stmt.a3));
                            }
                        }
                    }
            } else {
                // no commit ever touched this point?
                // it's possible a branch was not taken due to leaf sources or devices however
            }
        }

        return prog;
    }
}
