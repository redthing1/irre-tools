module irre.util;

import std.array;
import std.conv;

byte[] datahex(string hex) {
    auto buf = appender!(byte[]);

    for (auto i = 0; hex[i]; i += 2) {
        buf ~= to!byte(hex[i]);
    }

    return buf.data;
}
