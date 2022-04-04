module irre.util;

public import std.string;
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

enum Verbosity : int {
    Error,
    Warning,
    Info,
    Trace,
}
auto IRRE_TOOLS_VERBOSITY = Verbosity.Warning;

// void mixin(LOG_TRACE!(string message) {
//     if (IRRE_TOOLS_VERBOSITY) {
//         writefln("[log] %s", message);
//     }
// }

void log_put(string message) {
    if (IRRE_TOOLS_VERBOSITY >= Verbosity.Info) {
        writefln("[log] %s", message);
    }
}

template LOG_PUT(string Level, string Content) {
    enum LOG_PUT = `if (` ~ Level ~ ` <= IRRE_TOOLS_VERBOSITY)
         writefln(` ~ Content ~ `);
    `;
}

template LOG_TRACE(string Content) {
    enum LOG_TRACE = `if (IRRE_TOOLS_VERBOSITY >= Verbosity.Trace)
         writefln(` ~ Content ~ `);
    `;
}

// template LOG_INFO(string Content) {
//     string LOG_INFO = LOG_PUT("Info", Content);
// }
