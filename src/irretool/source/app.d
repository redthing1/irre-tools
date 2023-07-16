module app;

version (app)  : import std.stdio;
import std.format;
import std.conv;
import std.file;
import std.array;
import std.string;
import std.algorithm.comparison : min, max;

import commandr;
import fastlog;

import irre.util;
import irre.meta;
import irre.assembler.lexer;
import irre.assembler.parser;
import irre.assembler.ast_freezer;
import irre.disassembler.dumper;
import irre.disassembler.dumper;
import irre.disassembler.reader;
import irre.encoding.rega;
import irre.emulator.vm;
import irre.emulator.hypervisor;

import infoflow.analysis.ift;
import irre.analysis.irre_arch;
import irre.analysis.minimizer;

auto verbose = 0;

void main(string[] raw_args) {
    // dfmt off
    auto args = new Program("irretool", format("v. %s", Meta.VERSION)).summary("IRRE architecture tool")
        .author("redthing1")
        .add(new Flag("v", "verbose", "turns on more verbose output"))
        .add(new Command("asm", "assemble a file")
                .add(new Argument("input", "input file"))
                .add(new Argument("output", "output file"))
                .add(new Flag("d", "dump", "dump the program"))
                .add(new Flag("l", "lex", "dump the lex"))
                .add(new Option("m", "mode", "the mode to assemble in")
                    .defaultValue("exe"))
        )
        // disasm command with input argument, and clean flag
        .add(new Command("disasm", "disassemble a file")
                .add(new Argument("input", "input file"))
                .add(new Flag("c", "clean", "clean/pretty print program"))
        )
        // emu command with only input argument, and debug, step flags
        .add(new Command("emu", "emulate a binary program")
                .add(new Argument("input", "input file"))
                .add(new Flag("d", "debug", "debug mode"))
                .add(new Flag("s", "step", "step mode"))
                .add(new Flag(null, "commitlog", "enable commit log").full("commit-log"))
                .add(new Option(null, "savecommits", "save commits to file").full("save-commits"))
                .add(new Flag(null, "ift", "enable ift analysis"))
                .add(new Flag(null, "iftquiet", "quiet ift analysis").full("ift-quiet"))
                .add(new Flag(null, "iftpl", "parallel ift analysis").full("ift-pl"))
                .add(new Option(null, "iftdata", "ift data types").full("ift-data"))
                .add(new Option(null, "checkpoint", "checkpoint file")))
        .add(new Command("analyze", "do analysis")
                .add(new Argument("input", "input file"))
                .add(new Flag(null, "pl", "enable parallel analysis computation"))

                .add(new Flag(null, "ift", "enable ift analysis"))
                .add(new Flag(null, "iftquiet", "quiet ift analysis").full("ift-quiet"))
                .add(new Flag(null, "iftgraph", "enable ift graph").full("ift-graph"))
                .add(new Flag(null, "iftgraphanalysis", "enable ift graph analysis").full("ift-graph-analysis"))
                .add(new Option(null, "iftsavegraph", "save ift graph").full("ift-save-graph"))
                .add(new Option(null, "iftdata", "ift data types").full("ift-data"))
                .add(new Flag(null, "iftskiprevisit", "aggressively skip ift info node revisit").full("ift-skip-revisit"))

                .add(new Flag(null, "regtouch", "enable regtouch analysis"))

                .add(new Flag(null, "optim", "enable graph optimization analysis"))
                .add(new Option(null, "optimsavegraph", "save optimized graph").full("opt-save-graph"))

                .add(new Option(null, "checkpoint", "checkpoint file"))
		)
        .add(new Command("dumptrace", "dump trace")
                .add(new Argument("input", "input file"))

                .add(new Flag("c", "commits", "dump commits"))
                .add(new Flag("r", "registers", "dump registers"))
                .add(new Flag("m", "memory", "dump memory"))
        )
        .parse(raw_args);

    IRRE_TOOLS_VERBOSITY = (irre.util.Verbosity.Warning + verbose).to!(irre.util.Verbosity);
    verbose = min(args.occurencesOf("verbose"), 3);
    // logger.verbosity = to!Verbosity(Verbosity.warn.to!int + verbose); // warn, info, trace

    {
        import infoflow.util;
        INFOFLOW_VERBOSITY = to!InfoflowVerbosity(InfoflowVerbosity.error.to!int + verbose);
    }
    
    args
        .on("asm", (args) {
            cmd_asm(args);
        })
        .on("disasm", (args) {
            cmd_disasm(args);
        })
        .on("emu", (args) {
            cmd_emu(args);
        })
        .on("analyze", (args) {
            cmd_runanalyze(args);
        })
        .on("dumptrace", (args) {
            cmd_dumptrace(args);
        })
        ;
     // dfmt on
}

enum AssemblerMode {
    exe,
    obj,
}

int cmd_asm(ProgramArgs args) {
    auto input = args.arg("input");
    auto output = args.arg("output");
    auto dump = args.flag("dump");
    auto dump_lex = args.flag("lex");
    auto mode = args.option("mode").to!AssemblerMode;

    writefln("[IRRE] assembler v%s", Meta.VERSION);

    string inf_source;
    try {
        inf_source = std.file.readText(input);
    } catch (FileException e) {
        writefln("could not read from file: %s\n%s", e.file, e.msg);
        return 2;
    }

    Lexer lexer;
    Lexer.Result lexed;

    try {
        // lex the source
        lexer = new Lexer();
        lexed = lexer.lex(inf_source);

        if (dump_lex) {
            // dump the tokens
            writeln("======== TOKENS ========");
            foreach (i, token; lexed.tokens) {
                writefln("%4d TOK: %10s [%10s]", i, token.content, to!string(token.kind));
            }
        }
    } catch (LexerException e) {
        writefln("lexer error: %s at %s", e.msg, e.info);
        return 2;
    }

    Parser parser;
    ProgramAst program_ast;

    try {
        // parse the tokens
        parser = new Parser();
        parser.load_lex(lexed);
        parser.parse();

        // create an ast
        program_ast = parser.to_ast();

        // if executable mode, then freeze symbols
        if (mode == AssemblerMode.exe || mode == AssemblerMode.obj) {
            log_put("freezing all symbols in ast");
            auto freezer = new AstFreezer(program_ast);
            freezer.freeze_all_symbols();
            program_ast = freezer.get_frozen_ast();
        }

        // if (dump_ast) {
        if (dump) {
            // dump the ast
            writeln("\n======== AST ========");
            auto dumper = new Dumper(Dumper.DumpStyle.Detailed);
            writeln(".code --------");
            dumper.dump_statements(program_ast);
            writeln(".data --------");
            dumper.dump_data(program_ast);
            writeln("=====================\n");
        }

    } catch (ParserException e) {
        writefln("parser error: %s at %s", e.msg, e.info);
        return 3;
    } catch (AstBuilderException e) {
        writefln("ast builder error: %s at %s", e.msg, e.info);
        return 3;
    }

    log_put(format("output mode: %s", mode));
    // write file in specified format
    switch (mode) {
    case AssemblerMode.exe: {
            // EXE encode
            auto encoder = new RegaEncoder();
            auto compiled_data = encoder.encode_exe(program_ast);

            std.file.write(output, compiled_data);
            break;
        }
    case AssemblerMode.obj: {
            // OBJ encode
            auto encoder = new RegaEncoder();
            auto compiled_data = encoder.encode_obj(program_ast);

            std.file.write(output, compiled_data);
            break;
        }
    default:
        assert(0, "unrecognized mode");
    }

    return 0;
}

int cmd_disasm(ProgramArgs args) {
    auto input = args.arg("input");
    auto clean = args.flag("clean");

    writefln("[IRRE] disassembler v%s", Meta.VERSION);

    auto compiled_data = cast(const(ubyte)[]) std.file.read(input);

    auto reader = new Reader();
    auto program_ast = reader.read(compiled_data);

    auto dumper = new Dumper(clean ? Dumper.DumpStyle.Clean : Dumper.DumpStyle.Detailed);
    dumper.dump_statements(program_ast);

    return 0;
}

int cmd_emu(ProgramArgs args) {
    auto input = args.arg("input");
    auto debug_mode = args.flag("debug");
    auto step_mode = args.flag("step");
    auto log_commits = args.flag("commitlog");
    auto save_commits = args.option("savecommits");
    auto enable_ift = args.flag("ift");
    auto ift_quiet = args.flag("iftquiet");
    auto ift_parallel = args.flag("iftpl");
    auto ift_data_types = args.option("iftdata");
    auto checkpoint_file = args.option("checkpoint");

    writefln("[IRRE] emulator v%s", Meta.VERSION);

    auto compiled_data = cast(const(ubyte)[]) std.file.read(input);

    auto vm = new VirtualMachine();
    vm.initialize();

    // load the program
    auto header = vm.load(compiled_data);
    // dump the header
    auto dumper = new Dumper(Dumper.DumpStyle.Detailed);
    dumper.dump_header(header);

    // create a hypervisor
    auto hyp = new Hypervisor(vm);
    hyp.debug_mode = debug_mode;
    hyp.onestep_mode = step_mode;

    // add basic IO support
    hyp.add_default_devices();
    hyp.add_debug_interrupt_handlers();

    // configure
    if (log_commits) {
        hyp.enable_commit_log();
    }

    // start the emulator
    hyp.run();

    // dump commits
    if (log_commits) {
        auto commit_trace = hyp.vm.commit_trace;

        if (save_commits != null) {
            // write commits to file
            import std.zlib;
            import mir.ser.msgpack: serializeMsgpack;
            auto serialized_trace = serializeMsgpack(commit_trace);

            writefln("serialized commits: %d bytes, saving to %s", serialized_trace.length, save_commits);
            std.file.write(save_commits, compress(serialized_trace));
        }
    }

    return 0;
}

auto load_commit_trace(string filename) {
    // deserialize
    import std.zlib;
    import mir.deser.msgpack : deserializeMsgpack;
    import infoflow.models.commit;

    logger.info("loading commit trace from %s", filename);

    auto serialized_trace = cast(const(ubyte)[]) uncompress(std.file.read(filename));
    auto commit_trace = serialized_trace.deserializeMsgpack!CommitTrace();

    return commit_trace;
}

void cmd_dumptrace(ProgramArgs args) {
    auto input = args.arg("input");
    auto dump_commits = args.flag("commits");
    auto dump_registers = args.flag("registers");
    auto dump_memory = args.flag("memory");

    auto commit_trace = load_commit_trace(input);

    // show summary
    logger.info("commit trace summary:");
    logger.info("  commits: %s", commit_trace.commits.length);
    logger.info("  snapshots: %s", commit_trace.snapshots.length);

    if (dump_registers || dump_memory) {
        foreach (i, snapshot; commit_trace.snapshots) {
            writefln("snapshot #%s", i);

            if (dump_registers) {
                writefln(" registers");
                foreach (j, reg; snapshot.reg) {
                    writefln("  reg %s = $%08x", j.to!IrreRegister, reg);
                }
            }
            if (dump_memory) {
                import std.algorithm.sorting : sort;
                import std.range : array;

                writefln(" memory");

                writefln("  memory map");
                foreach (map_item; snapshot.memory_map) {
                    writefln("   section: $%08x %s (%s)", map_item.base_address, map_item.section_name, map_item
                            .type);
                }

                writefln("  memory pages");
                auto mem_page_addrs = snapshot.tracked_mem.pages.byKey.array;
                foreach (page_addr; mem_page_addrs.sort()) {
                    writefln("   page: $%08x", page_addr);

                    // dump the page
                    auto raw_mem_page = snapshot.tracked_mem.pages[page_addr].mem;

                    // pretty dump memory
                    auto memdump_sb = appender!(string);
                    enum dump_w = 48;
                    enum dump_grp = 4;

                    for (auto k = 0; k < raw_mem_page.length; k += dump_w) {
                        memdump_sb ~= "    ";
                        auto base_addr = page_addr;
                        memdump_sb ~= format("$%08x: ", k + base_addr);
                        for (auto l = 0; l < dump_w; l++) {
                            if (k + l >= raw_mem_page.length) {
                                break;
                            }
                            for (auto m = 0; m < 4; m++) {
                                if (k + l + m >= raw_mem_page.length) {
                                    break;
                                }
                                memdump_sb ~= format("%02x", raw_mem_page[k + l + m]);
                            }
                            l += dump_grp;
                            memdump_sb ~= " ";
                        }
                        memdump_sb ~= "\n";
                    }
                    memdump_sb ~= "\n";

                    if (logger.verbosity >= fastlog.Verbosity.trace) {
                        writefln("%s", memdump_sb.data);
                    }
                }
            }
        }
    }

    if (dump_commits) {
        writefln(" commits");
        foreach (j, commit; commit_trace.commits) {
            writefln("  commit #%s: %s", j, commit);
        }
    }
}

void cmd_runanalyze(ProgramArgs args) {
    import std.parallelism : totalCPUs;

    auto input = args.arg("input");
    auto enable_parallel = args.flag("pl");
    auto enable_ift = args.flag("ift");
    auto ift_quiet = args.flag("iftquiet");
    auto enable_ift_graph = args.flag("iftgraph");
    auto enable_ift_graph_analysis = args.flag("iftgraphanalysis");
    auto ift_data_types = args.option("iftdata");
    auto enable_regtouch = args.flag("regtouch");
    auto ift_save_graph = args.option("iftsavegraph");
    auto enable_ift_skip_revisit = args.flag("iftskiprevisit");
    auto enable_optim = args.flag("optim");
    auto optim_save_graph = args.option("optimsavegraph");

    auto commit_trace = load_commit_trace(input);

    // do stuff
    alias IFTAnalyzer = IrreIFTAnalysis.IFTAnalyzer;
    alias IFTDumper = IrreIFTDump.IFTDumper;

    auto ift_analyzer = new IFTAnalyzer(commit_trace, enable_parallel);
    auto ift_dumper = new IFTDumper(ift_analyzer);

    if (ift_data_types) {
        ift_analyzer.included_data = ift_data_types.to!(IFTAnalyzer.IFTDataType);
    }

    ift_analyzer.aggressive_revisit_skipping = enable_ift_skip_revisit;

    if (enable_ift) {
        if (!ift_quiet) {
            // show the commits
            ift_dumper.dump_commits();

            // show the clobber
            ift_analyzer.calculate_clobber();
            ift_dumper.dump_clobber();
        }

        writefln("\nanalysis features: "
            ~ (enable_parallel ? format("parallel x%s", totalCPUs) : "serial")
            ~ (enable_ift_graph ? " graph" : "")
            ~ (enable_ift_graph_analysis ? " graph_analysis" : "")
            ~ (enable_ift_skip_revisit ? " skip_revisit" : "")
        );

        writefln(" included data types: %s", ift_analyzer.included_data);

        ift_analyzer.enable_ift_graph = enable_ift_graph;
        ift_analyzer.enable_ift_graph_analysis = enable_ift_graph_analysis;

        ift_analyzer.analyze();
        if (!ift_quiet) {
            ift_dumper.dump_analysis();
        }

        if (enable_ift_graph) {
            if (!ift_quiet) {
                ift_dumper.dump_graph();
            }

            if (ift_save_graph) {
                ift_dumper.export_graph_to(ift_save_graph);
            }
        }

        ift_dumper.dump_summary();
    }

    if (enable_regtouch) {
        alias RegTouchAnalyzer = IrreRegTouchAnalysis.RegTouchAnalyzer;
        auto regtouch_analyzer = new RegTouchAnalyzer(commit_trace, enable_parallel);

        regtouch_analyzer.analyze();

        writefln("\nregtouch analysis");
        regtouch_analyzer.dump_analysis();
    }

    if (enable_optim) {
        writefln("\noptimizer analysis");

        alias IFTGraphOptimizer = IrreIFTOptimizer.IFTGraphOptimizer;
        auto optimizer = new IFTGraphOptimizer(ift_analyzer);
        optimizer.enable_prune_deterministic_subtrees = true;

        optimizer.optimize();

        // use the dumper to dump the optimized graph
        writefln("\noptimizer results");
        writefln(" optimized graph");
        ift_dumper.dump_graph();

        if (optim_save_graph) {
            ift_dumper.export_graph_to(optim_save_graph);
        }

        writefln(" optimizer summary");
        optimizer.dump_summary();
    }
}
