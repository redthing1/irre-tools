module irre.disassembler.dumper;

import irre.assembler.parser;
import irre.encoding.instructions;
import std.stdio;
import std.string;
import std.uni;
import std.conv;

class DumperException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

class Dumper {
    void dump_statements(AbstractStatement[] statements) {
        foreach (i, node; statements) {
            writefln("4%d %s", i, format_statement(node));
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
            return format("%04x", v);
        }

        string format_reg_arg(ValueArg arg) {
            auto s = toLower(to!string(to!Register(arg.peek!(ValueImm).val)));
            return format("%04s", s);
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
        return format("%04s $%04x $%04x $%04x", mnem, a1, a2, a3);
    }
}
