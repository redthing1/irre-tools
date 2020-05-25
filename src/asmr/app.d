module asmr.app;

import std.stdio;
import std.getopt;
import std.file;
import irre.meta;
import irre.assembler.lexer;
import irre.assembler.parser;

string input_file;
string output_file;
bool verbose;

int main(string[] args) {
    writefln("[IRRE] assembler v%s", Meta.VERSION);
    auto help = getopt(args, "verbose|v", &verbose);

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

        // dump the tokens
        writeln("== TOKENS ==");
        foreach (i, token; lexed.tokens) {
            writefln("%4d TOK: %10s [%3d]\n", i, token.content, cast(int) token.kind);
        }

        auto parser = new Parser();
        auto programAst = parser.parse(lexed);
    } catch (ParserException e) {
        writefln("parser error: %s at %s", e.msg, e.info);
    }

    return 0;
}
