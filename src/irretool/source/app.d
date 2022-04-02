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

void main(string[] args) {
    auto a = new Program("irretool", "0.11").summary("IRRE architecture tool")
        .author("redthing1")
        .add(new Argument("asset", "path to 3d asset (.obj or ,glb)"))
        .add(new Argument("output", "path to output spritesheet (.png)"))
        .add(new Option("d", "dimens", "render dimensions ('MxN')").defaultValue("64x64"))
        .add(new Option("w", "width", "spritesheet width (how many frames per row)").defaultValue("4"))
        .add(new Option("f", "frames", "number of frames to capture").defaultValue("16"))
        .add(new Option("l", "scale", "scale of object").defaultValue("1"))
        .add(new Option(null, "fov", "camera fov (in deg)").defaultValue("45"))
        .add(new Option("p", "pos", "position of object ('X,Y,Z')").defaultValue("0,0,0"))
        .add(new Option("r", "rot", "rotation of object ('X,Y,Z') (euler angles in deg)").defaultValue("90,0,0"))
        .add(new Option("c", "campos", "position of camera ('X,Y,Z')").defaultValue("10,10,10"))
        .add(new Option("g", "capangles", "angle range of the capture ('A,B') (in deg)").defaultValue("0,360"))
        .add(new Flag("n", "noquit", "don't close render immediately after capture"))
        .parse(args);
}
