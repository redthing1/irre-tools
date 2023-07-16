module irre.disassembler.dumper;

import irre.assembler.parser;
import irre.encoding.instructions;
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
    void dump_statements(AbstractStatement[] statements) {
        foreach (i, node; statements) {
            auto offset = i * INSTRUCTION_SIZE;
            writefln("%04x: %s", offset, format_statement(node));
        }
    }

    private string format_statement(AbstractStatement node) {
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
        builder ~= format("%04s", mnem);
        if ((info.operands & Operands.K_R1) | (info.operands & Operands.K_I1)) {
            builder ~= format(" %04s", a1);
        }
        if ((info.operands & Operands.K_R2) | (info.operands & Operands.K_I2)) {
            builder ~= format(", %04s", a2);
        }
        if ((info.operands & Operands.K_R2) | (info.operands & Operands.K_I3)) {
            builder ~= format(", %04s", a3);
        }
        return builder.data;
    }
}
