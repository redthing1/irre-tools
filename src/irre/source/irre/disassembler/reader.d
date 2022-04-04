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

        // read statements
        auto code_start_offset = RegaHeader.OFFSET;
        auto code_data = compiled_data[code_start_offset .. $];
        auto raw_instructions = decoder.read_code(code_data);

        // TODO: if an instruction fails to decode, we should maybe throw an exception?
        // if the instructions that fail to decode are at the end, treat them as data

        // decompile all instructions
        auto statements = appender!(AbstractStatement[]);
        foreach (instruction; raw_instructions) {
            auto statement = decompile(instruction);
            statements ~= statement;
        }

        auto ast = ProgramAst(statements.data);

        // recreate guess sections
        ast.sections ~= SectionInfo(SectionId.Code, cast(int) (ast.statements.length * INSTRUCTION_SIZE));
        ast.sections ~= SectionInfo(SectionId.Data, 0);

        return ast;
    }

    AbstractStatement decompile(Instruction instruction) {
        auto statement = AbstractStatement(instruction.op, cast(ValueArg) ValueImm(instruction.a1),
                cast(ValueArg) ValueImm(instruction.a2), cast(ValueArg) ValueImm(instruction.a3));

        return statement;
    }
}
