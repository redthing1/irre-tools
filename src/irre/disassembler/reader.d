module irre.disassembler.reader;

import irre.assembler.ast;
import irre.encoding.rega;
import irre.encoding.instructions;
import std.array;

class Reader {
    ProgramAst read(const ubyte[] compiled_data) {
        auto decoder = new RegaDecoder();

        // read header
        auto head = decoder.read_header(compiled_data[0 .. RegaHeader.OFFSET]);

        // read data
        auto program_data = compiled_data[RegaHeader.OFFSET .. RegaHeader.OFFSET + head.data_size];

        // read statements
        auto code_start_offset = RegaHeader.OFFSET + head.data_size;
        auto code_data = compiled_data[code_start_offset .. $];
        auto raw_instructions = decoder.read_code(code_data);

        // decompile all instructions
        auto statements = appender!(AbstractStatement[]);
        foreach (instruction; raw_instructions) {
            auto statement = decompile(instruction);
            statements ~= statement;
        }

        auto ast = ProgramAst(statements.data, program_data);
        return ast;
    }

    AbstractStatement decompile(Instruction instruction) {
        auto statement = AbstractStatement(instruction.op, cast(ValueArg) ValueImm(instruction.a1),
                cast(ValueArg) ValueImm(instruction.a2), cast(ValueArg) ValueImm(instruction.a3));

        return statement;
    }
}
