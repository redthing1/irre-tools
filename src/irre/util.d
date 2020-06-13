module irre.util;

import std.stdio;
import std.array;
import std.conv;
import std.range;
import std.algorithm;

// https://stackoverflow.com/a/23741556/13240621
ubyte[] datahex(string hexstr) {
    ubyte[] bytes = (hexstr.length % 2 ? "0" ~ hexstr : hexstr).chunks(2)
        .map!(twoDigits => twoDigits.parse!ubyte(16)).array();
    return bytes;
}

bool IRRE_TOOLS_VERBOSE = false;

void log_put(string message) {
    if (IRRE_TOOLS_VERBOSE) {
        writefln("[log] %s", message);
    }
}
