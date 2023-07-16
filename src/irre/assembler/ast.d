module irre.assembler.ast;

import irre.assembler.lexer;
import irre.encoding.instructions;
import std.variant;

struct ValueRef {
    string label;
    int offset;
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
}

struct ProgramAst {
    AbstractStatement[] statements;
    const ubyte[] data;
}

struct LabelDef {
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
