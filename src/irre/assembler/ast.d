module irre.assembler.ast;

import irre.assembler.lexer;
import irre.encoding.instructions;
import std.variant;
import std.string;
import std.array;

struct ValueRef {
    string label;
    int ref_offset;
}

struct ValueImm {
    int val;
}

alias ValueArg = Algebraic!(ValueImm, ValueRef);

struct AbstractStatement {
    OpCode op;
    ValueArg a1, a2, a3;
}

struct SourceStatement {
    string mnem;
    Token[] a1, a2, a3;

    string dump() {
        auto builder = appender!string;
        builder ~= format("%s ", mnem);
        void format_tokens(Token[] tokens) {
            foreach (token; tokens) {
                builder ~= format("%s", token.content);
            }
            builder ~= " ";
        }
        format_tokens(a1);
        format_tokens(a2);
        format_tokens(a3);

        return builder.data;
    }
}

struct DataBlock {
    int offset;
    ubyte[] data;
}

struct ProgramAst {
    AbstractStatement[] statements;
    DataBlock[] data_blocks;
    MacroDef[] macros;
    LabelDef[] labels;
    string entry_point_label;
    SectionInfo[] sections;
}

enum SectionId {
    Code = 0,
    Data = 1
}

struct SectionInfo {
    SectionId id;
    int length;
}

struct LabelDef {
    SectionId section;
    string name;
    int offset;
}

struct MacroArg {
    enum Type {
        VALUE = 0,
        REGISTER = 1,
    }

    Type type;
    string name;
}

struct MacroDef {
    string name;
    MacroArg[] args;
    SourceStatement[] statements;
}
