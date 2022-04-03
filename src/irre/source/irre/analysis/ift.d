module irre.analysis.ift;

import std.stdio;
import std.format;
import std.conv;
import std.algorithm;
import std.range;
import std.container.dlist;

import irre.emulator.commit;
import irre.encoding.instructions;

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
        analyze_flows();
    }

    void dump_commits() {
        foreach (i, commit; trace.commits) {
            writefln("%6d %s", i, commit);
        }
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

    long find_commit_last_touching(InfoNode node, long from_commit) {
        switch (node.type) {
        case InfoType.Register:
            // go back through commits until we find one whose results modify this register
            for (auto i = from_commit; i >= 0; i--) {
                auto commit = &trace.commits[i];
                for (auto j = 0; j < commit.reg_ids.length; j++) {
                    if (commit.reg_ids[j] == node.data) {
                        // the register id in the commit results is the same as the reg id in the info node we are searching
                        return i;
                    }
                }
            }
            break;
        case InfoType.Memory:
            // go back through commits until we find one whose results modify this memory
            for (auto i = from_commit; i >= 0; i--) {
                auto commit = &trace.commits[i];
                for (auto j = 0; j < commit.mem_addrs.length; j++) {
                    if (commit.mem_addrs[j] == node.data) {
                        // the memory address in the commit results is the same as the mem addr in the info node we are searching
                        return i;
                    }
                }
            }
            break;
        default:
            assert(0);
        }
        assert(0, format("could not find touching commit for node: %s, commit <= #%d", node, from_commit));
    }

    void backtrace_information_flow(InfoNode final_node) {
        // 1. get the commit corresponding to this node
        auto final_node_last_touch_ix =
            find_commit_last_touching(final_node, (cast(long) trace.commits.length) - 1);
        // writefln("found last touching commit (#%s) for node: %s: %s",
        //     final_node_last_touch_ix, final_node, trace.commits[final_node_last_touch_ix]);

        // 2. data structures for dfs

        struct InfoNodeWalk {
            InfoNode node;
            long commit_ix;
        }

        auto unvisited = DList!InfoNodeWalk();
        bool[InfoNodeWalk] visited;

        // 3. queue our initial node
        unvisited.insertFront(InfoNodeWalk(final_node, final_node_last_touch_ix));

        // 4. iterative dfs
        while (!unvisited.empty) {
            auto curr = unvisited.front;
            unvisited.removeFront();
            visited[curr] = true;

            writefln(" visiting: node: %s, commit pos: %s", curr.node, curr.commit_ix);

            if (curr.node.type == InfoType.Immediate) {
                // we found raw source data, no dependencies
                continue;
            }

            // get last touching commit for this node
            auto touching_commit_ix = find_commit_last_touching(curr.node, curr.commit_ix);
            auto touching_commit = trace.commits[touching_commit_ix];
            writefln("  found last touching commit (#%s) for node: %s: %s",
                touching_commit_ix, curr, touching_commit);

            // get all dependencies of this commit
            auto deps = touching_commit.sources.reverse;
            for (auto i = 0; i < deps.length; i++) {
                auto dep = deps[i];
                writefln("   found dependency: %s", dep);
                auto dep_walk = InfoNodeWalk(dep, touching_commit_ix);

                // if we have not visited this dependency yet, add it to the unvisited list
                if (!visited.get(dep_walk, false)) {
                    unvisited.insertFront(dep_walk);
                }
            }
        }
    }

    void analyze_flows() {
        // for now, we'll only flow back from the R0 register
        // get the clobber node for R0
        auto find_r0_final = clobber.reg_ids.countUntil(Register.R0);
        assert(find_r0_final >= 0, "could not find R0 in clobber list");

        // create an info node for this point
        auto r0_final_node = InfoNode(InfoType.Register,
            clobber.reg_ids[find_r0_final], clobber.reg_values[find_r0_final]);

        // now start backtracing
        backtrace_information_flow(r0_final_node);
    }

    void dump_analysis() {
        // 1. dump clobber commit
        writefln(" clobber (%s commits):", trace.commits.length);

        // memory
        writefln("  memory:");
        for (auto i = 0; i < clobber.mem_addrs.length; i++) {
            auto mem_addr = clobber.mem_addrs[i];
            auto mem_value = clobber.mem_values[i];
            writefln("   mem[%04x] <- %04x", mem_addr, mem_value);
        }

        // registers
        writefln("  regs:");
        for (auto i = 0; i < clobber.reg_ids.length; i++) {
            auto reg_id = clobber.reg_ids[i].to!Register;
            auto reg_value = clobber.reg_values[i];
            writefln("   reg %s <- %04x", reg_id, reg_value);
        }
    }
}
