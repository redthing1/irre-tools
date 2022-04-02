module irre.analysis.ift;

import std.stdio;
import std.format;
import std.conv;

import irre.emulator.commit;
import irre.encoding.instructions;
import std.algorithm.mutation;

/** analyzer for dynamic information flow tracking **/
class IFTAnalyzer {
    CommitTrace trace;
    Snapshot snap_init;
    Snapshot snap_final;
    Commit clobber;

    this(CommitTrace commit_trace) {
        trace = commit_trace;
    }

    /**
     * analyze the commit trace
     * @return the analysis result
     */
    void analyze() {
        snap_init = trace.snapshots[0];
        snap_final = trace.snapshots[1];

        analyze_clobber();
    }

    void dump_commits() {
        foreach (i, commit; trace.commits) {
            writefln("%6d %s", i, commit);
        }
    }

    void dump_analysis() {
        // TODO
    }

    void analyze_clobber() {
        // calculate the total clobber commit between the initial and final state

        // 1. find regs that changed
        for (auto i = 0; i < REGISTER_COUNT; i++) {
            Register reg_id = i.to!Register;
            if (snap_init.reg[reg_id] != snap_final.reg[reg_id]) {
                // this register changed between the initial and final state
                // store commit that clobbers this register
                clobber.reg_ids ~= reg_id;
                clobber.reg_values ~= snap_final.reg[reg_id];
            }
        }

        // 2. find mem that changed
        for (auto i = 0; i < snap_init.mem.length; i++) {
            auto mem_addr = i;
            if (snap_init.mem[mem_addr] != snap_final.mem[mem_addr]) {
                // this memory changed between the initial and final state
                // store commit that clobbers this memory
                clobber.mem_addrs ~= mem_addr;
                clobber.mem_values ~= snap_final.mem[mem_addr];
            }
        }
    }
}
