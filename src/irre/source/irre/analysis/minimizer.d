module irre.analysis.minimizer;

import std.stdio;
import std.format;
import std.conv;
import std.algorithm;
import std.range;
import std.container.dlist;
import core.time : MonoTime, Duration;

import irre.util;
import irre.assembler.ast;
import irre.encoding.instructions;
import irre.encoding.rega;
import irre.analysis.irre_arch;

import infoflow.analysis.ift;
import infoflow.models;

class ProgramMinimizer {
    mixin(IrreInfoLog.GenAliases!("IrreInfoLog"));
    
    ProgramAst source_program;
    IrreIFTAnalysis.IFTAnalyzer ift;
    long log_freeze1s;
    long log_freeze2s;
    long log_freeze_attempts;
    long log_nopped_instructions;
    bool[Register] log_frozen_registers;
    ulong log_analysis_time;

    this(ProgramAst program, IrreIFTAnalysis.IFTAnalyzer ift) {
        source_program = program;
        this.ift = ift;
    }

    ProgramAst create_minimized() {
        log_freeze1s = 0;
        log_freeze2s = 0;
        log_freeze_attempts = 0;
        log_nopped_instructions = 0;
        log_frozen_registers.clear();

        MonoTime tmr_start = MonoTime.currTime;

        void nop_statement(AbstractStatement* statement) {
            // set opcode to NOP
            statement.op = OpCode.NOP;
            // clear operands
            statement.a1 = statement.a2 = statement.a3 = ValueImm(0);

            log_nopped_instructions += 1;
        }

        AbstractStatement* find_statement_at_pc(ProgramAst prog, UWORD pc) {
            auto offs = 0;
            for (auto i = 0; i < prog.statements.length; i++) {
                // check
                if (offs == pc) {
                    return &prog.statements[i];
                }

                offs += INSTRUCTION_SIZE;
            }

            return null;
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
                bool is_this_freezable = source.is_deterministic;
                // another case is if it comes from the initial snapshot
                if (source.commit_id == -1) {
                    // it came from the initial snapshot
                    is_this_freezable = true;
                }
                freezable = freezable && is_this_freezable;
            }

            // blacklist
            if (reg_id == Register.PC)
                freezable = false;

            // now, if all sources were freezable
            if (freezable) {
                // then we can precompute this register's final value
                freezable_registers[reg_id] = true;
                mixin(LOG_TRACE!(`format("  we are able to freeze register %s", reg_id.to!Register)`));
            }
        }

        writefln(" reverse walk program");
        ProgramAst prog = source_program; // copy source program
        UWORD offset = (cast(UWORD) prog.statements.length) * cast(UWORD) INSTRUCTION_SIZE;
        bool[Register] frozen_registers;
        bool[UWORD] whitelisted_instructions; // these instructions will never be NOPed
        for (int i = (cast(int) prog.statements.length - 1); i >= 0; i--) {
            offset -= INSTRUCTION_SIZE;
            auto stmt = &prog.statements[i];

            // writefln("looking at: %s", *stmt);

            // nop_statement(stmt);

            // TODO: figure out if the instruction is "freezable" ??

            // find the last commit at this pc

            // this is the current commit we are searching from
            auto last_commit_here_ix = ift.find_last_commit_at_pc(offset, ift.last_commit_ix);

            if (last_commit_here_ix >= 0) {
                // we found a commit that was last at this offset
                auto last_commit_here = ift.trace.commits[last_commit_here_ix];

                mixin(LOG_TRACE!(`format("  found last commit at %04x: %s", offset, last_commit_here)`));

                // let's see if the sole result of this commit is a register
                auto commit_results = last_commit_here.effects;
                if (commit_results.length == 1
                    && commit_results[0].type == InfoType.Register) {
                        // get that single result
                        auto single_result = commit_results[0];

                        // get reg id of that single result
                        auto result_reg_id = single_result.data.to!Register;

                        // is this register already frozen?
                        if (frozen_registers.get(result_reg_id, false)) {
                            // this register's final value is frozen
                            if(!whitelisted_instructions.get(offset, false)) {
                                // and it is not whitelisted
                                // so we can nop this instruction
                                nop_statement(stmt);
                            }
                            continue; // all done here
                        }

                        mixin(LOG_TRACE!(`format("    this commit has a single register result: %s", single_result)`));
                        
                        // if this register is freezable, then can we replace this step with direct setting?
                        if (freezable_registers.get(result_reg_id, false)) {
                            // yes, we can
                            mixin(LOG_TRACE!(`format("   commit result %s is of a freezable register %s", single_result, result_reg_id)`));
                            log_freeze_attempts++;

                            auto final_reg_value = ift.snap_final.reg[result_reg_id];
                            // check if the value will fit in a single 16-bit SET instruction
                            if (final_reg_value <= 0xffff) {
                                // yes!
                                frozen_registers[result_reg_id] = true;

                                // set opcode to SET
                                stmt.op = OpCode.SET;
                                // set operands
                                stmt.a1 = ValueImm(result_reg_id);
                                // stmt.a2 = ValueImm((final_reg_value & 0x00ff)));
                                // stmt.a3 = ValueImm((final_reg_value & 0xff00) >> 8);
                                stmt.a2 = ValueImm(final_reg_value);

                                mixin(LOG_TRACE!(`format("    replacing 1-freeze SET %s=$%04x", result_reg_id, final_reg_value)`));
                                log_freeze1s++;
                            } else {
                                // this won't fit in a single SET instruction
                                // we need a SET, SUP sequence.
                                // this means we need to find the last two commits that set only this register

                                // currently we have already found one commit that set this register
                                // so we need to find the previous commit touching this register (if any) that sets it alone
                                // this is O(n^2)

                                mixin(LOG_TRACE!(`format("   only 2-instruction freeze is possible, searching for candidate prev")`));

                                auto found_prev_singleset = false;
                                auto singleset_search_last_commit_ix = last_commit_here_ix - 1;
                                
                                if (singleset_search_last_commit_ix < 0) continue;

                                while (!found_prev_singleset) {
                                    // look for the last touching commit
                                    auto prev_toucher_ix = ift.find_commit_last_touching(single_result, singleset_search_last_commit_ix);

                                    // try to verify
                                    if (prev_toucher_ix < 0) break;

                                    auto prev_toucher_commit = ift.trace.commits[prev_toucher_ix];
                                    mixin(LOG_TRACE!(`format("    checking candidate prev: %s", prev_toucher_commit)`));

                                    auto prev_toucher_results = prev_toucher_commit.effects;
                                    if (prev_toucher_results.length == 1) {
                                        // this is what we wanted

                                        assert(prev_toucher_results[0].type == InfoType.Register);
                                        assert(prev_toucher_results[0].data.to!Register == result_reg_id);

                                        // we found a second-to-last commit that set this register alone
                                        mixin(LOG_TRACE!(`format("    accepted candidate prev: %s", prev_toucher_commit)`));

                                        // find the statement there
                                        auto prev_touch_stmt = find_statement_at_pc(prog, prev_toucher_commit.pc);
                                        assert(prev_touch_stmt != null);

                                        // mark as frozen
                                        frozen_registers[result_reg_id] = true;
                                        // whitelist instruction at prev (so it isn't nopped cause its reg is frozen)
                                        whitelisted_instructions[prev_toucher_commit.pc] = true;

                                        // add the SET/SUP sequence
                                        auto val_lower = final_reg_value & 0xffff;
                                        auto val_upper = (final_reg_value & 0xffff0000) >> 16;

                                        prev_touch_stmt.op = OpCode.SET;
                                        prev_touch_stmt.a1 = ValueImm(result_reg_id);
                                        // prev_touch_stmt.a2 = ValueImm((val_lower & 0x00ff)));
                                        // prev_touch_stmt.a3 = ValueImm((val_lower & 0xff00) >> 8);
                                        prev_touch_stmt.a2 = ValueImm(val_lower);

                                        stmt.op = OpCode.SUP;
                                        stmt.a1 = ValueImm(result_reg_id);
                                        // stmt.a2 = ValueImm((val_upper & 0x00ff)));
                                        // stmt.a3 = ValueImm((val_upper & 0xff00) >> 8);
                                        stmt.a2 = ValueImm(val_upper);
                                        
                                        mixin(LOG_TRACE!(`format("    replacing 2-freeze SET/SUP %s=$%08x", result_reg_id, final_reg_value)`));
                                        log_freeze2s++;

                                        break;
                                    } else {
                                        // we failed. try again but searching before the result we got this time
                                        singleset_search_last_commit_ix = prev_toucher_ix - 1;
                                        continue;
                                    }
                                }
                            }
                        }
                    }
            } else {
                // no commit ever touched this point?
                // it's possible a branch was not taken due to leaf sources or devices however
            }
        }

        MonoTime tmr_end = MonoTime.currTime;
        auto elapsed = tmr_end - tmr_start;

        log_frozen_registers = frozen_registers.dup;

        log_analysis_time = elapsed.total!"usecs";

        return prog;
    }

    void dump_summary() {
        writefln(" summary:");
        writefln("  frozen:                 %8d (%s)", log_freeze1s + log_freeze2s, log_frozen_registers.byKey);
        writefln("  1-freezes:              %8d", log_freeze1s);
        writefln("  2-freezes:              %8d", log_freeze2s);
        writefln("  freeze attempts:        %8d", log_freeze_attempts);
        writefln("  nopped:                 %8d", log_nopped_instructions);
        writefln("  analysis time:          %7ss", (cast(double) log_analysis_time / 1_000_000));
    }
}