module app;

version (app)  : import std.stdio;
import std.format;
import std.conv;
import std.file;
import std.string;

import commandr;

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
import irre.analysis.ift;
import irre.analysis.minimizer;

enum AssemblerMode {
    exe,
    obj,
}

bool verbose = false;

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
                .add(new Flag(null, "ift", "enable ift analysis"))
                .add(new Flag(null, "iftquiet", "quiet ift analysis").full("ift-quiet"))
                .add(new Flag(null, "iftpl", "parallel ift analysis").full("ift-pl"))
                .add(new Option(null, "iftdata", "ift data types").full("ift-data"))
                .add(new Option(null, "checkpoint", "checkpoint file"))
        )
        .parse(raw_args);

    verbose = args.flag("verbose");
    IRRE_TOOLS_VERBOSITY = verbose ? Verbosity.Trace : Verbosity.Warning;
    
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
        ;
     // dfmt on
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
        if (mode == AssemblerMode.exe) {
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
            // TODO: OBJ encode
            log_put("todo: obj encode");
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
        alias IFTAnalyzer = IrreIFTAnalysis.IFTAnalyzer;

        auto ift_analyzer = new IFTAnalyzer(hyp.vm.commit_trace);
        writeln("\ncommit log");
        if (!ift_quiet) {
            ift_analyzer.dump_commits();

            // some very simple operation, to find clobber
            ift_analyzer.calculate_clobber();
            ift_analyzer.dump_clobber();
        }

        if (enable_ift) {
            writeln("\nift analysis");
            if (ift_data_types) {
                ift_analyzer.included_data = ift_data_types.to!(IFTAnalyzer.IFTDataType);
            }
            ift.analysis_parallelized = ift_parallel;
            ift_analyzer.analyze();
            if (!ift_quiet) {
                ift_analyzer.dump_analysis();
            }
            ift_analyzer.dump_summary();

            if (checkpoint_file != null) {
                // we can save a checkpoint
                // 1. read the entire binary in as a series of instructions
                auto reader = new Reader();
                auto program_ast = reader.read(compiled_data);

                // 2. create a minimizer
                auto minimizer = new ProgramMinimizer(program_ast, ift_analyzer);
                auto prog_min = minimizer.create_minimized();

                writefln("minimized program:");
                dumper.dump_statements(prog_min);

                minimizer.dump_summary();

                // 3. write checkpoint
                // EXE encode
                auto encoder = new RegaEncoder();
                auto compiled_min_prog = encoder.encode_exe(prog_min);

                std.file.write(checkpoint_file, compiled_min_prog);
            }
        }
    }

    return 0;
}
