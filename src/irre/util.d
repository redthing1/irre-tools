module irre.util;

import std.array;
import std.conv;

ubyte[] datahex(string hex) {
    auto buf = appender!(ubyte[]);

    for (auto i = 0; hex[i]; i += 2) {
        buf ~= to!ubyte(hex[i]);
    }

    return buf.data;
}
