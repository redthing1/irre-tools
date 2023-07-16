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

void main(string[] args) {
    auto a = new Program("irretool", "0.11").summary("IRRE architecture tool")
        .author("redthing1")
        .add(new Flag("v", null, "turns on more verbose output")
                .name("verbose"))
        .add(new Command("asm", "assemble a file")
                .add(new Argument("input", "input file"))
                .add(new Argument("output", "output file"))
                .add(new Flag("d", "dump", "dump the program"))
                .add(new Option("m", "mode", "the mode to assemble in")
                    .defaultValue("exe"))
        )
        .parse(args);
}
