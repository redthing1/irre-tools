module irre.encoding.rega;

import irre.util;
import irre.assembler.ast;
import irre.encoding.instructions;
import std.array;
import std.string;
import std.bitmanip;

/*
    the REGA file format
    ...
*/

enum REGA_MAGIC = "rg";

struct RegaHeader {
    ushort program_size;

    enum OFFSET = 4;
}

/** IRRE-REGA binary format encoder */
class RegaEncoder {
    ubyte[] encode_exe(ProgramAst ast) {
        auto wr = appender!(ubyte[]);
        auto data_block_size = 0;
        foreach (data_block; ast.data_blocks) {
            data_block_size += data_block.data.length;
        }
        log_put(format("writing REGA_EXE:"));

        // write header
        auto head = RegaHeader(
                cast(ushort)(data_block_size + ast.statements.length * INSTRUCTION_SIZE));
        auto head_bin = write_header(head);
        log_put(format("  writing HEADER[%d]", head_bin.length));
        wr ~= head_bin;

        // - write CODE section
        log_put(format("  writing CODE section[%d] with %d instructions",
                ast.sections[cast(int) SectionId.Code].length, ast.statements.length));
        auto code_start = ast.get_section_offset(SectionId.Code);
        auto code_offset = code_start;

        foreach (statement; ast.statements) {
            // log_put(format("   stmt: %s", statement));

            auto info = InstructionEncoding.get_info(statement.op).get();
            auto instruction = compile_statement(statement, info);

            // log_put(format("    info: %s", info));

            // write instruction word
            wr ~= instruction.op;
            wr ~= instruction.a1;
            wr ~= instruction.a2;
            wr ~= instruction.a3;

            // log_put(format("    instr: %s", instruction));

            code_offset += info.size * INSTRUCTION_SIZE;
        }

        // - write DATA section
        log_put(format("  writing DATA section[%d] with %d blocks",
                ast.sections[cast(int) SectionId.Data].length, ast.data_blocks.length));
        auto data_start = ast.get_section_offset(SectionId.Data);
        auto data_offset = data_start;
        foreach (block; ast.data_blocks) {
            wr ~= block.data;
            data_offset += block.data.length;
            log_put(format("    wrote data block[%d] @ $%04x", block.data.length, block.offset));
        }

        return wr.data;
    }

    /** compile an abstract statement to a binary-encoded instruction */
    private Instruction compile_statement(ref AbstractStatement statement, ref InstructionInfo info) {
        int get_arg_val(ValueArg arg) {
            if (arg.hasValue) {
                return arg.peek!(ValueImm).val;
            } else {
                return 0;
            }
        }

        auto op = statement.op;
        auto arg1 = get_arg_val(statement.a1);
        auto arg2 = get_arg_val(statement.a2);
        auto arg3 = get_arg_val(statement.a3);

        auto a1 = cast(ARG) arg1;
        auto a2 = cast(ARG) arg2;
        auto a3 = cast(ARG) arg3;

        // LARGE IMMs
        bool fst_imm = (info.operands & Operands.K_I1) > 0;
        bool snd_imm = (info.operands & Operands.K_I2) > 0;
        bool trd_imm = (info.operands & Operands.K_I3) > 0;
        bool big_imm16 = snd_imm && !trd_imm;
        bool big_imm24 = fst_imm && !snd_imm && !trd_imm;

        // log_put(format("     imm_types: %s %s %s, big16: %s, big24: %s",
        //     fst_imm, snd_imm, trd_imm, big_imm16, big_imm24));

        if (big_imm24) {
            a1 = cast(ARG)((arg1 >> 0) & 0xff);
            a2 = cast(ARG)((arg1 >> 8) & 0xff);
            a3 = cast(ARG)((arg1 >> 16) & 0xff);
        } else if (big_imm16) {
            a2 = cast(ARG)((arg2 >> 0) & 0xff);
            a3 = cast(ARG)((arg2 >> 8) & 0xff);
        }

        return Instruction(op, a1, a2, a3);
    }

    private ubyte[] write_header(RegaHeader head) {
        auto wr = appender!(ubyte[]);
        wr ~= cast(ubyte[]) REGA_MAGIC; // magic
        wr ~= cast(ubyte[]) nativeToLittleEndian(head.program_size);
        return wr.data;
    }
}

class RegaDecoder {
    RegaHeader read_header(const ubyte[] data) {
        auto magic = cast(string) data[0 .. 2];
        assert(magic == REGA_MAGIC); // check magic
        auto program_size_bytes = cast(ubyte[2]) data[2 .. 4];
        auto head = RegaHeader(littleEndianToNative!ushort(program_size_bytes));
        return head;
    }

    Instruction[] read_code(const ubyte[] data) {
        auto instructions = appender!(Instruction[]);
        for (int pos = 0; pos < data.length; pos += INSTRUCTION_SIZE) {
            auto op = cast(OpCode)(data[pos + 0]);
            auto a1 = cast(ARG)(data[pos + 1]);
            auto a2 = cast(ARG)(data[pos + 2]);
            auto a3 = cast(ARG)(data[pos + 3]);
            // read instruction word
            auto instruction = Instruction(op, a1, a2, a3);
            instructions ~= instruction;
        }
        return instructions.data;
    }
}
