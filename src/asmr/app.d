module asmr.app;

import std.stdio;
import std.getopt;
import std.conv;
import std.file;
import irre.meta;
import irre.assembler.lexer;
import irre.assembler.parser;
import irre.encoding.rega;
import irre.disassembler.dumper;

string input_file;
string output_file;
bool verbose;
bool dump;

int main(string[] args) {
    writefln("[IRRE] assembler v%s", Meta.VERSION);
    auto help = getopt(args, "verbose|v", &verbose, "dump", &dump);

    if (help.helpWanted || args.length != 3) {
        defaultGetoptPrinter("./irre-asm [OPTIONS] <input> <output>", help.options);
        return 1;
    }

    input_file = args[1];
    output_file = args[2];

    string inf_source;
    try {
        inf_source = std.file.readText(input_file);
    } catch (FileException e) {
        writefln("could not read from file: %s\n%s", e.file, e.msg);
        return 2;
    }

    try {
        // - assemble the source
        auto lexer = new Lexer();
        auto lexed = lexer.lex(inf_source);

        if (dump) {
            // dump the tokens
            writeln("== TOKENS ==");
            foreach (i, token; lexed.tokens) {
                writefln("%4d TOK: %10s [%10s]", i, token.content, to!string(token.kind));
            }
        }

        auto parser = new Parser();
        auto programAst = parser.parse(lexed);

        if (dump) {
            // dump the ast
            writeln("== AST ==");
            auto dumper = new Dumper(Dumper.Mode.Detailed);
            dumper.dump_statements(programAst.statements);
        }

        auto encoder = new RegaEncoder();
        auto compiled_data = encoder.write(programAst);

        std.file.write(output_file, compiled_data);

    } catch (ParserException e) {
        writefln("parser error: %s at %s", e.msg, e.info);
    }

    return 0;
}
