module asmr.app;

import std.stdio;

import irre.sample;

void main() {
	auto ver = SampleInfo.get_version();
	writefln("assembler sample v: %s", ver);
}