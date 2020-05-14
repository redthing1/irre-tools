module asmr.app;

import std.stdio;

import libirre.sample;

void main() {
	writeln("assembler");
	auto ver = SampleInfo.get_version();
	writefln("sample v: %s", ver);
}