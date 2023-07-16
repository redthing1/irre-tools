module irre.analysis.ift;

import std.stdio;
import std.format;
import std.conv;
import irre.emulator.commit;

/** analyzer for dynamic information flow tracking **/
class IFTAnalyzer {
    CommitTrace trace;
    Snapshot snap_init;
    Snapshot snap_final;

    this(CommitTrace commit_trace) {
        trace = commit_trace;
    }

    /**
     * analyze the commit trace
     * @return the analysis result
     */
    void analyze() {
        backtrack_snapshots();
    }

    void dump_commits() {
        foreach (i, commit; trace.commits) {
            writefln("%6d %s", i, commit);
        }
    }

    void dump_analysis() {
        // TODO
    }

    void backtrack_snapshots() {
        snap_init = trace.snapshots[0];
        snap_final = trace.snapshots[1];
    }
}
