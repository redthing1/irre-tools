module irre.analysis.minimizer;

import std.stdio;
import std.format;
import std.conv;
import std.algorithm;
import std.range;
import std.container.dlist;

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

        // 1. look at total clobber of mem and regs
        // essentially, for each final data node, if all its sources can be frozen,then we can precompute
        
        // registers
        bool[Register] freezable_registers;
        foreach (reg_id; ift.clobbered_regs_sources.byKey) {
            auto freezable = true;
            foreach (source; ift.clobbered_regs_sources[reg_id]) {
                // check whether this source node is freezable too
                freezable = freezable && source.is_final;
            }

            // now, if all sources were freezable
            if (freezable) {
                // then we can precompute this register's final value
                freezable_registers[reg_id] = true;
                writefln("we are able to freeze register %s", reg_id.to!Register);
            }
        }

        ProgramAst prog = source_program; // copy source program
        auto offset = 0;
        for (int i = 0; i < prog.statements.length; i++) {
            auto stmt = &prog.statements[i];

            // writefln("looking at: %s", *stmt);

            // nop_statement(stmt);

            // TODO: figure out if the instruction is "freezable" ??

            // find the last commit at this pc

            auto last_commit_here_ix = ift.find_last_commit_at_pc(offset, ift.last_commit_ix);
            
            if (last_commit_here_ix >= 0) {
                // we found a commit that was last at this offset
                auto last_commit_here = ift.trace.commits[last_commit_here_ix];

                writefln("found last commit at %04x: %s", offset, last_commit_here);
            }

            offset += INSTRUCTION_SIZE;
        }

        return prog;
    }
}
