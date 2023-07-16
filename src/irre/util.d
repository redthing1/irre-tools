module irre.util;

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
