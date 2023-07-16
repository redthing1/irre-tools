module irre.disassembler.dumper;

import irre.assembler.ast;
import irre.encoding.instructions;
import irre.encoding.rega;
import std.stdio;
import std.string;
import std.uni;
import std.conv;
import std.array;

class DumperException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

class Dumper {
    enum Mode {
        Clean,
        Detailed
    }

    private Mode mode;

    this(Mode mode) {
        this.mode = mode;
    }

    void dump_statements(ProgramAst ast) {
        auto global_offset = 0;
        foreach (i, node; ast.statements) {
            auto offset = global_offset + i * INSTRUCTION_SIZE;
            auto builder = appender!string;
            if (mode == Mode.Detailed) {
                builder ~= format("%04x: ", offset);
            }
            builder ~= format("%s", format_statement(node));
            writefln(builder.data);
        }
    }

    public string format_statement(AbstractStatement node) {
        // based on operand type, format each arg

        int imm_arg_val(ValueArg arg) {
            return arg.peek!(ValueImm).val;
        }

        string format_imm_arg(ValueArg arg) {
            auto v = imm_arg_val(arg);
            return format("$%02x", v);
        }

        string format_reg_arg(ValueArg arg) {
            auto s = toLower(to!string(to!Register(arg.peek!(ValueImm).val)));
            return format("%s", s);
        }

        auto maybeInfo = InstructionEncoding.get_info(node.op);
        if (maybeInfo.isNull) {
            return format("?? [$%02x %s %s %s]", to!ubyte(node.op),
                    format_imm_arg(node.a1), format_imm_arg(node.a2), format_imm_arg(node.a3));
            // throw new DumperException(format("could not format statement with unknown op: %s",
            //         to!string(node.op)));
        }
        auto info = maybeInfo.get();
        string mnem = toLower(to!string(node.op));
        string a1, a2, a3;

        // by default, format all as immediates
        a1 = format_imm_arg(node.a1);
        a2 = format_imm_arg(node.a2);
        a3 = format_imm_arg(node.a3);
        if ((info.operands & Operands.K_R1)) {
            a1 = format_reg_arg(node.a1);
        }
        if ((info.operands & Operands.K_R2)) {
            a2 = format_reg_arg(node.a2);
        }
        if ((info.operands & Operands.K_R3)) {
            a3 = format_reg_arg(node.a3);
        }
        auto builder = appender!string;

        // write one piece of the assembly line, formatted
        void append_arg(string av, bool first = false) {
            if (!first) {
                builder ~= " ";
            }
            switch (mode) {
            case Mode.Clean:
                builder ~= format("%s", av);
                break;
            default:
                builder ~= format("%-4s", av);
                break;
            }
        }

        append_arg(mnem, true);

        // R-args
        if ((info.operands & Operands.K_R1) > 0) {
            append_arg(a1);
        }
        if ((info.operands & Operands.K_R2) > 0) {
            append_arg(a2);
        }
        if ((info.operands & Operands.K_R3) > 0) {
            append_arg(a3);
        }
        // I-args
        // LARGE IMMs
        bool fst_imm = (info.operands & Operands.K_I1) > 0;
        bool snd_imm = (info.operands & Operands.K_I2) > 0;
        bool trd_imm = (info.operands & Operands.K_I3) > 0;
        bool big_imm16 = snd_imm && !trd_imm;
        bool big_imm24 = fst_imm && !snd_imm && !trd_imm;
        if (big_imm24) {
            auto val = imm_arg_val(node.a1) | imm_arg_val(node.a2) << 8 | imm_arg_val(node.a3) << 16;
            append_arg(format("$%06x", val));
        } else {
            if (fst_imm) {
                append_arg(a1);
            }
            if (big_imm16) {
                auto val = imm_arg_val(node.a2) | imm_arg_val(node.a3) << 8;
                append_arg(format("$%04x", val));
            } else if (snd_imm) {
                append_arg(a2);
                if (trd_imm) {
                    append_arg(a3);
                }
            }
        }

        auto str = std.string.strip(cast(string) builder.data);
        return str;
    }

    void dump_header(RegaHeader head) {
        writefln("program size: $%04x", head.program_size);
    }
}
