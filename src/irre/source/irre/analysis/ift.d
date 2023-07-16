module irre.analysis.ift;

import std.stdio;
import std.format;
import std.conv;
import std.algorithm;
import std.range;
import std.container.dlist;
import core.time : MonoTime, Duration;

import irre.util;
import irre.emulator.commit;
static import irre.encoding.instructions;

alias IrreIFTAnalysis = IFTAnalysis!(
    irre.encoding.instructions.UWORD,
    irre.encoding.instructions.BYTE,
    irre.encoding.instructions.Register,
    cast(int) irre.encoding.instructions.REGISTER_COUNT);

template IFTAnalysis(TRegWord, TMemWord, TRegSet, int register_count) {

    alias TInfoLog = InfoLog!(TRegWord, TMemWord, TRegSet, register_count);

    mixin(TInfoLog.GenAliases!("TInfoLog"));
    // alias Snapshot = TInfoLog.Snapshot;
    // alias Commit = TInfoLog.Commit;
    // alias CommitTrace = TInfoLog.CommitTrace;
    // alias InfoType = TInfoLog.InfoType;
    // alias InfoNode = TInfoLog.InfoNode;
    // alias InfoSource = TInfoLog.InfoSource;
    // alias InfoSources = TInfoLog.InfoSources;

    /** analyzer for dynamic information flow tracking **/
    class IFTAnalyzer {
        CommitTrace trace;
        Snapshot snap_init;
        Snapshot snap_final;
        Commit clobber;
        InfoSources[TRegSet] clobbered_regs_sources;
        InfoSources[TRegWord] clobbered_mem_sources;
        IFTDataType included_data = IFTDataType.All;
        bool analysis_parallelized = false;

        version(ift_log) {
            long log_visited_info_nodes;
            long log_commits_walked;
            long log_found_sources;
        }
        ulong log_analysis_time;

        enum IFTDataType {
            None = (0 << 0),
            Registers = (1 << 0),
            Memory = (1 << 1),
            Special = (1 << 2),
            All = (Registers | Memory | Special),
        }

        this(CommitTrace commit_trace) {
            trace = commit_trace;

            // sanity check the trace
            assert(trace.commits.length > 0, "trace must have at least one commit");
            assert(trace.snapshots.length == 2,
                "trace must have exactly two snapshots, initial and final");
            
            snap_init = trace.snapshots[0];
            snap_final = trace.snapshots[1];
        }

        @property long last_commit_ix() const {
            return (cast(long) trace.commits.length) - 1;
        }

        /**
        * analyze the commit trace
        * @return the analysis result
        */
        void analyze() {
            MonoTime tmr_start = MonoTime.currTime;
            
            version(ift_log) {
                log_visited_info_nodes = 0;
                log_commits_walked = 0;
                log_found_sources = 0;
            }

            // calculate diffs and clobber
            calculate_clobber();
            analyze_flows();

            MonoTime tmr_end = MonoTime.currTime;
            auto elapsed = tmr_end - tmr_start;

            log_analysis_time = elapsed.total!"usecs";
        }

        void dump_commits() {
            foreach (i, commit; trace.commits) {
                writefln("%6d %s", i, commit);
            }
        }

        void calculate_clobber() {
            // calculate the total clobber commit between the initial and final state
            // 1. reset clobber
            clobber = Commit();

            if (included_data & IFTDataType.Registers) {
                // 1. find regs that changed
                for (auto i = 0; i < register_count; i++) {
                    TRegSet reg_id = i.to!TRegSet;
                    if (snap_init.reg[reg_id] != snap_final.reg[reg_id]) {
                        // this TRegSet changed between the initial and final state
                        // store commit that clobbers this TRegSet
                        clobber.reg_ids ~= reg_id;
                        clobber.reg_values ~= snap_final.reg[reg_id];
                    }
                }
            }

            if (included_data & IFTDataType.Memory) {
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

            // 3. do a reverse pass through all commits, looking for special cases
            //    things like devices and mmio, external sources of data

            for (auto i = last_commit_ix; i >= 0; i--) {
                auto commit = trace.commits[i];
                version(ift_log) log_commits_walked++;

                // look at sources of this commit
                for (auto j = 0; j < commit.sources.length; j++) {
                    auto source = commit.sources[j];

                    if (source.type == InfoType.Device) {
                        // one of this instruction's sources is a device
                        // this means that the output nodes are clobbered

                        // there are no commands in this ISA to directly clobber memory
                        // so we'll only check registers

                        // find the registers that are clobbered by this commit
                        for (auto k = 0; k < commit.reg_ids.length; k++) {
                            auto reg_id = commit.reg_ids[k];
                            auto reg_val = commit.reg_values[k];
                            if (clobber.reg_ids.canFind(reg_id)) {
                                // this TRegSet is already clobbered
                                // so we don't need to do anything
                                continue;
                            }

                            // this TRegSet is not clobbered yet
                            // so we need to add it to the clobber list
                            clobber.reg_ids ~= reg_id;
                            clobber.reg_values ~= reg_val;
                        }
                    }
                }
            }
        }

        long find_last_commit_at_pc(TRegWord pc_val, long from_commit) {
            for (auto i = from_commit; i >= 0; i--) {
                auto commit = &trace.commits[i];
                version(ift_log) log_commits_walked++;
                if (commit.pc == pc_val) {
                    return i;
                }
            }

            return -1; // none found
        }

        long find_commit_last_touching(InfoNode node, long from_commit) {
            switch (node.type) {
            case InfoType.Register:
                // go back through commits until we find one whose results modify this TRegSet
                for (auto i = from_commit; i >= 0; i--) {
                    auto commit = &trace.commits[i];
                    version(ift_log) log_commits_walked++;
                    for (auto j = 0; j < commit.reg_ids.length; j++) {
                        if (commit.reg_ids[j] == node.data) {
                            // the TRegSet id in the commit results is the same as the reg id in the info node we are searching
                            return i;
                        }
                    }
                }

                // if we're still here, then we haven't found a commit that touches this TRegSet
                // it's possible the TRegSet wasn't touched because it was already in place before the initial snapshot
                // to check this, we'll verify if the expected TRegSet value can be found in the initial snapshot
                if (snap_init.reg[node.data] == node.value) {
                    // the expected value exists in the initial snapshot
                    // so there's no commit from it because it was before initial
                    return -1;
                }
                break;
            case InfoType.Memory:
                // go back through commits until we find one whose results modify this memory
                for (auto i = from_commit; i >= 0; i--) {
                    auto commit = &trace.commits[i];
                    version(ift_log) log_commits_walked++;
                    for (auto j = 0; j < commit.mem_addrs.length; j++) {
                        if (commit.mem_addrs[j] == node.data) {
                            // the memory address in the commit results is the same as the mem addr in the info node we are searching
                            return i;
                        }
                    }
                }
                // if we're still here, that means we haven't found a commit that touches this memory position
                // it's possible the memory wasn't touched because it was already in place before the initial snapshot
                // to check this, we'll verify if the expected memory value can be found in the initial snapshot
                if (snap_init.mem[node.data] == node.value) {
                    // the expected memory value is the same as the initial memory value
                    // this means the memory was already in place
                    return -1;
                }
                break;
            default:
                assert(0);
            }
            assert(0, format("could not find touching commit for node: %s, commit <= #%d", node, from_commit));
        }

        InfoSource[] backtrace_information_flow(InfoNode final_node) {
            // 1. get the commit corresponding to this node
            auto final_node_last_touch_ix =
                find_commit_last_touching(final_node, last_commit_ix);
            // writefln("found last touching commit (#%s) for node: %s: %s",
            //     final_node_last_touch_ix, final_node, trace.commits[final_node_last_touch_ix]);

            // 2. data structures for dfs

            struct InfoNodeWalk {
                InfoNode node;
                long commit_ix;
            }

            auto unvisited = DList!InfoNodeWalk();
            bool[InfoNodeWalk] visited;

            InfoSource[] terminal_leaves;

            pragma(inline, true) void add_info_leaf(InfoSource leaf) {
                terminal_leaves ~= leaf;
                version(ift_log) log_found_sources++;
            }

            // 3. queue our initial node
            unvisited.insertFront(InfoNodeWalk(final_node, final_node_last_touch_ix));

            // 4. iterative dfs
            while (!unvisited.empty) {
                auto curr = unvisited.front;
                unvisited.removeFront();
                visited[curr] = true;

                mixin(LOG_TRACE!(`format("  visiting: node: %s, commit pos: %s", curr.node, curr.commit_ix)`));
                version(ift_log) log_visited_info_nodes += 1;

                if (curr.node.type == InfoType.Immediate || curr.node.type == InfoType.Device) {
                    // we found raw source data, no dependencies
                    // this is a leaf source, so we want to record it
                    // all data comes from some sort of leaf source
                    auto leaf = InfoSource(curr.node, curr.commit_ix);
                    add_info_leaf(leaf);
                    mixin(LOG_TRACE!(`format("   leaf (source): %s", leaf)`));
                    continue;
                }

                // get last touching commit for this node
                auto touching_commit_ix = find_commit_last_touching(curr.node, curr.commit_ix);
                if (touching_commit_ix < 0) {
                    // this means some information was found to have been traced to the initial snapshot
                    // this counts as a leaf node

                    auto leaf = InfoSource(curr.node, -1); // the current node came from the initial snapshot
                    add_info_leaf(leaf);
                    mixin(LOG_TRACE!(`format("   leaf (pre-initial): %s", leaf)`));
                    continue;
                }

                auto touching_commit = trace.commits[touching_commit_ix];
                mixin(LOG_TRACE!(`format("   found last touching commit (#%s) for node: %s: %s",
                        touching_commit_ix, curr, touching_commit)`));

                // get all dependencies of this commit
                auto deps = touching_commit.sources.reverse;
                for (auto i = 0; i < deps.length; i++) {
                    auto dep = deps[i];
                    mixin(LOG_TRACE!(`format("    found dependency: %s", dep)`));

                    // where did this dependency's information come from?
                    // to find out we have to look for previous commits that created this dependency
                    // we have to search in commits before this one, because the dependency already had its value
                    // so we should walk through commits touching that dependency
                    // so we add it to our visit queue
                    auto dep_walk = InfoNodeWalk(dep, touching_commit_ix - 1);

                    // if we have not visited this dependency yet, add it to the unvisited list
                    if (!visited.get(dep_walk, false)) {
                        unvisited.insertFront(dep_walk);
                    }
                }
            }

            return terminal_leaves;
        }

        void analyze_flows() {
            import std.parallelism;

            // 1. backtrace all clobbered registers
            
            // queue work
            InfoNode[] reg_final_nodes;
            for (auto clobbered_i = 0; clobbered_i < clobber.reg_ids.length; clobbered_i++) {
                auto reg_id = clobber.reg_ids[clobbered_i].to!TRegSet;
                auto reg_val = clobber.reg_values[clobbered_i];

                // create an info node for this point
                auto reg_final_node = InfoNode(InfoType.Register, reg_id, reg_val);
                reg_final_nodes ~= reg_final_node;
            }

            // 2. backtrace all clobbered memory
            // queue work
            InfoNode[] mem_final_nodes;
            for (auto clobbered_i = 0; clobbered_i < clobber.mem_addrs.length; clobbered_i++) {
                auto mem_addr = clobber.mem_addrs[clobbered_i];
                auto mem_val = clobber.mem_values[clobbered_i];

                // create an info node for this point
                auto mem_final_node = InfoNode(InfoType.Memory, mem_addr, mem_val);
                mem_final_nodes ~= mem_final_node;
            }

            pragma(inline, true) void do_reg_trace(InfoNode final_node) {
                // now start backtracing
                mixin(LOG_TRACE!(`format("backtracking information flow for node: %s", final_node)`));
                auto reg_sources = backtrace_information_flow(final_node);

                // writefln("sources for reg %s: %s", reg_id, reg_sources);

                clobbered_regs_sources[cast(TRegSet)final_node.data] = reg_sources;
            }

            pragma(inline, true) void do_mem_trace(InfoNode final_node) {
                // now start backtracing
                mixin(LOG_TRACE!(`format("backtracking information flow for node: %s", final_node)`));
                auto mem_sources = backtrace_information_flow(final_node);

                // writefln("sources for mem %s: %s", mem_addr, mem_sources);

                clobbered_mem_sources[final_node.data] = mem_sources;
            }

            // select serial/parallel task
            // do work

            if (analysis_parallelized) {
                auto reg_final_nodes_work = parallel(reg_final_nodes);
                foreach (final_node; reg_final_nodes_work) {
                    do_reg_trace(final_node);   
                }
            } else {
                auto reg_final_nodes_work = reg_final_nodes;
                foreach (final_node; reg_final_nodes_work) {
                    do_reg_trace(final_node);   
                }
            }

            if (analysis_parallelized) {
                auto mem_final_nodes_work = parallel(mem_final_nodes);
                foreach (final_node; mem_final_nodes_work) {
                    do_mem_trace(final_node);
                }
            } else {
                auto mem_final_nodes_work = mem_final_nodes;
                foreach (final_node; mem_final_nodes_work) {
                    do_mem_trace(final_node);
                }
            }
        }

        void dump_clobber() {
            // 1. dump clobber commit
            writefln(" clobber (%s commits):", trace.commits.length);

            // memory
            writefln("  memory:");
            for (auto i = 0; i < clobber.mem_addrs.length; i++) {
                auto mem_addr = clobber.mem_addrs[i];
                auto mem_value = clobber.mem_values[i];
                writefln("   mem[%04x] <- $%04x", mem_addr, mem_value);
            }

            // registers
            writefln("  regs:");
            for (auto i = 0; i < clobber.reg_ids.length; i++) {
                auto reg_id = clobber.reg_ids[i].to!TRegSet;
                auto reg_value = clobber.reg_values[i];
                writefln("   reg %s <- $%04x", reg_id, reg_value);
            }
        }

        void dump_analysis() {
            import std.array: appender;

            // dump backtraces
            writefln(" backtraces:");

            // registers
            foreach (reg_id; clobbered_regs_sources.byKey) {
                writefln("  reg %s:", reg_id);
                foreach (source; clobbered_regs_sources[reg_id]) {
                    writefln("   %s", source);
                }
            }

            // memory
            foreach (mem_addr; clobbered_mem_sources.byKey) {
                writefln("  mem[%04x]:", mem_addr);
                foreach (source; clobbered_mem_sources[mem_addr]) {
                    writefln("   %s", source);
                }
            }
        }

        void dump_summary() {
            // summary
            writefln(" summary:");
            writefln("  num commits:            %8d", trace.commits.length);
            writefln("  registers traced:       %8d", clobber.reg_ids.length);
            writefln("  memory traced:          %8d", clobber.mem_addrs.length);
            version(ift_log) {
                writefln("  found sources:          %8d", log_found_sources);
                writefln("  walked info:            %8d", log_visited_info_nodes);
                writefln("  walked commits:         %8d", log_commits_walked);
            }
            writefln("  analysis time:          %7ss", (cast(double) log_analysis_time / 1_000_000));
        }
    }
}