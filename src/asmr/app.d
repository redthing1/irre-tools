module asmr.app;

import std.stdio;
import std.getopt;
import std.conv;
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
            writefln("%4d TOK: %10s [%10s]", i, token.content, to!string(token.kind));
        }

        auto parser = new Parser();
        auto programAst = parser.parse(lexed);

        // dump the ast
        writeln("== AST ==");
        foreach (i, node; programAst.statements) {
            writefln("4%d %s %s %s %s", i, to!string(node.op), to!string(node.a1), to!string(node.a2), to!string(node.a3));
            
        }
    } catch (ParserException e) {
        writefln("parser error: %s at %s", e.msg, e.info);
    }

    return 0;
}
