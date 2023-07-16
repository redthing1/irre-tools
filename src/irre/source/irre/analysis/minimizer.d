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

        // 1. look at clobbers
        // registers
        foreach (reg_id; ift.clobbered_regs_sources.byKey) {
            // writefln("  reg %s:", reg_id);
            foreach (source; ift.clobbered_regs_sources[reg_id]) {
                // writefln("   %s", source);
            }
        }

        ProgramAst prog = source_program; // copy source program
        for (int i = 0; i < prog.statements.length; i++) {
            auto stmt = &prog.statements[i];

            // writefln("looking at: %s", *stmt);

            // nop_statement(stmt);

            // TODO: figure out if the instruction is "freezable" ??

        }

        return prog;
    }
}
