module irre.encoding.rega;

import irre.assembler.ast;
import irre.encoding.instructions;
import std.array;
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

class RegaEncoder {
    ubyte[] write(ProgramAst ast) {
        auto wr = appender!(ubyte[]);
        auto data_block_size = 0;
        foreach (data_block; ast.data_blocks) {
            data_block_size += data_block.data.length;
        }
        // write header
        auto head = RegaHeader(cast(ushort)(data_block_size + ast.statements.length * INSTRUCTION_SIZE));
        wr ~= write_header(head);

        // write program (code and data blocks
        // TODO: data block support
        auto code_offset = 0u;
        foreach (statement; ast.statements) {
            auto instruction = compile(statement);
            auto info = InstructionEncoding.get_info(instruction.op).get();

            // write instruction word
            wr ~= instruction.op;
            wr ~= instruction.a1;
            wr ~= instruction.a2;
            wr ~= instruction.a3;

            code_offset += info.size;
        }

        return wr.data;
    }

    Instruction compile(ref AbstractStatement statement) {
        auto op = statement.op;
        auto a1 = cast(ARG) statement.a1.peek!(ValueImm).val;
        auto a2 = cast(ARG) statement.a2.peek!(ValueImm).val;
        auto a3 = cast(ARG) statement.a3.peek!(ValueImm).val;

        return Instruction(op, a1, a2, a3);
    }

    ubyte[] write_header(RegaHeader head) {
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
