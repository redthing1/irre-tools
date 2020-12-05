module asmr.app;

import std.stdio;
import std.getopt;
import std.conv;
import std.file;
import irre.meta;
import irre.util;
import irre.assembler.lexer;
import irre.assembler.parser;
import irre.encoding.rega;
import irre.disassembler.dumper;

string input_file;
string output_file;
bool verbose;
bool dump;
Mode mode;

enum Mode {
    exe,
    obj
}

int main(string[] args) {
    writefln("[IRRE] assembler v%s", Meta.VERSION);
    auto help = getopt(args, "verbose|v", &verbose, "dump|d", &dump, "mode|m", &mode);

    if (help.helpWanted || args.length != 3) {
        defaultGetoptPrinter("./irre-asm [OPTIONS] <input> <output>", help.options);
        return 1;
    }
    IRRE_TOOLS_VERBOSE = verbose;

    input_file = args[1];
    output_file = args[2];

    string inf_source;
    try {
        inf_source = std.file.readText(input_file);
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

        if (dump) {
            // dump the tokens
            writeln("== TOKENS ==");
            foreach (i, token; lexed.tokens) {
                writefln("%4d TOK: %10s [%10s]", i, token.content, to!string(token.kind));
            }
        }
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

        // if executable mode, then freeze symbols
        if (mode == Mode.exe) {
            parser.freeze_all_symbols();
        }

        // create an ast
        programAst = parser.to_ast();

        if (dump) {
            // dump the ast
            writeln("== AST ==");
            auto dumper = new Dumper(Dumper.Mode.Detailed);
            dumper.dump_statements(programAst);
        }

    } catch (ParserException e) {
        writefln("parser error: %s at %s", e.msg, e.info);
        return 3;
    } catch (AstBuilderException e) {
        writefln("ast builder error: %s at %s", e.msg, e.info);
        return 3;
    }

    auto encoder = new RegaEncoder();
    auto compiled_data = encoder.write(programAst);

    std.file.write(output_file, compiled_data);

    return 0;
}
