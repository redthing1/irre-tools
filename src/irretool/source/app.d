module app;

import std.stdio;
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
                .add(new Option("m", "mode", "the mode to assemble in")
                    .defaultValue("exe")))
        // disasm command with input argument, and clean flag
        .add(new Command("disasm", "disassemble a file")
                .add(new Argument("input", "input file"))
                .add(new Flag("c", "clean", "clean/pretty print program")))
        // emu command with only input argument, and debug, step flags
        .add(new Command("emu", "emulate a binary program")
                .add(new Argument("input", "input file"))
                .add(new Flag("d", "debug", "debug mode"))
                .add(new Flag("s", "step", "step mode")))
        .parse(raw_args);

    verbose = args.flag("verbose");
    IRRE_TOOLS_VERBOSE = verbose;
    
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

        // if (dump_lex) {
        //     // dump the tokens
        //     writeln("======== TOKENS ========");
        //     foreach (i, token; lexed.tokens) {
        //         writefln("%4d TOK: %10s [%10s]", i, token.content, to!string(token.kind));
        //     }
        // }
    } catch (LexerException e) {
        writefln("lexer error: %s at %s", e.msg, e.info);
        return 2;
    }

    Parser parser;
    ProgramAst programAst;

    try {
        // parse the tokens
        parser = new Parser();
        parser.load_lex(lexed);
        parser.parse();

        // create an ast
        programAst = parser.to_ast();

        // if executable mode, then freeze symbols
        if (mode == AssemblerMode.exe) {
            log_put("freezing all symbols in ast");
            auto freezer = new AstFreezer(programAst);
            freezer.freeze_all_symbols();
            programAst = freezer.get_frozen_ast();
        }

        // if (dump_ast) {
        if (dump) {
            // dump the ast
            writeln("\n======== AST ========");
            auto dumper = new Dumper(Dumper.DumpStyle.Detailed);
            writeln(".code --------");
            dumper.dump_statements(programAst);
            writeln(".data --------");
            dumper.dump_data(programAst);
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
            auto compiled_data = encoder.encode_exe(programAst);

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
    auto programAst = reader.read(compiled_data);

    auto dumper = new Dumper(clean ? Dumper.DumpStyle.Clean : Dumper.DumpStyle.Detailed);
    dumper.dump_statements(programAst);

    return 0;
}

int cmd_emu(ProgramArgs args) {
    auto input = args.arg("input");
    auto debug_mode = args.flag("debug");
    auto step_mode = args.flag("step");

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

    // start the emulator
    hyp.run();

    return 0;
}
