module irre.assembler.ast;

import irre.assembler.lexer;
import irre.encoding.instructions;
import std.string;
import std.array;
import std.variant;
import std.typecons;

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

    /** calculate the global offset pointed to by a label reference */
    public Nullable!int get_label_global_offset(ValueRef label_ref) {
        // get the label definition
        immutable auto maybe_label_def = resolve_label(label_ref.label);
        if (maybe_label_def.isNull) {
            return Nullable!int.init;
        }
        auto label_def = maybe_label_def.get;
        // calculate label offset within section
        auto local_label_offset = label_def.offset + label_ref.ref_offset;
        // get the offset of section start
        auto section_offset = get_section_offset(label_def.section);
        // global offset is [SECTION_OFFSET] + [LOCAL_OFFSET]
        return Nullable!int(section_offset + local_label_offset);
    }

    /** get offset of start of section */
    public int get_section_offset(SectionId section) {
        int section_index = cast(int) section;
        int offset_above = 0;
        for (int i = 0; i < section_index; i++) {
            offset_above += sections[i].length;
        }
        return offset_above;
    }

    /** resolve a macro */
    public Nullable!MacroDef resolve_macro(string name) {
        // find the macro
        foreach (mac; macros) {
            if (mac.name == name) {
                return Nullable!MacroDef(mac);
            }
        }
        return Nullable!MacroDef.init;
    }

    /** resolve a label */
    public Nullable!LabelDef resolve_label(string name) {
        foreach (label; labels) {
            if (label.name == name) {
                return Nullable!LabelDef(label);
            }
        }
        return Nullable!LabelDef.init;
    }
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
