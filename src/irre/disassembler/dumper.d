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
        auto data_offset = ast.data.length;
        foreach (i, node; ast.statements) {
            auto offset = data_offset + i * INSTRUCTION_SIZE;
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
        auto maybeInfo = InstructionEncoding.get_info(node.op);
        if (maybeInfo.isNull) {
            throw new DumperException(format("could not format statement with unknown op: %s",
                    to!string(node.op)));
        }
        auto info = maybeInfo.get();
        string mnem = toLower(to!string(node.op));
        string a1, a2, a3;

        string format_imm_arg(ValueArg arg) {
            auto v = arg.peek!(ValueImm).val;
            return format("$%02x", v);
        }

        string format_reg_arg(ValueArg arg) {
            auto s = toLower(to!string(to!Register(arg.peek!(ValueImm).val)));
            return format("%s", s);
        }

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
                builder ~= format("%04s", av);
                break;
            }
        }

        append_arg(mnem, true);

        if ((info.operands & Operands.K_R1) | (info.operands & Operands.K_I1)) {
            append_arg(a1);
        }
        if ((info.operands & Operands.K_R2) | (info.operands & Operands.K_I2)) {
            append_arg(a2);
        }
        if ((info.operands & Operands.K_R2) | (info.operands & Operands.K_I3)) {
            append_arg(a3);
        }
        auto str = std.string.strip(cast (string) builder.data);
        return str;
    }

    void dump_header(RegaHeader head) {
        writefln("data size: $%04x", head.data_size);
        writefln("code size: $%04x", head.code_size);
    }
}
