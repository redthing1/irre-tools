module irre.encoding.rega;

import irre.util;
import irre.assembler.ast;
import irre.encoding.instructions;
import std.array;
import std.string;
import std.bitmanip;
import std.exception;
import std.string;

/*
    the REGA file format
    ...
*/

enum REGA_MAGIC = "rg";

struct RegaHeader {
    ushort program_size;

    enum OFFSET = 4;
}

struct RegaSymbol {
    char[] name;
    int offset;
}

struct RegaSymbolTable {
    RegaSymbol[] symbols;
}

/** IRRE-REGA binary format encoder */
class RegaEncoder {
    ubyte[] encode_obj(ProgramAst ast) {
        log_put(format("writing REGA_OBJ:"));
        auto wr = appender!(ubyte[]);
        auto data_block_size = calc_data_block_size(ast);

        wr ~= make_header(ast, data_block_size);

        write_code_section(wr, ast);
        write_data_section(wr, ast);

        return wr.data;
    }

    ubyte[] encode_exe(ProgramAst ast) {
        log_put(format("writing REGA_EXE:"));
        auto wr = appender!(ubyte[]);
        auto data_block_size = calc_data_block_size(ast);

        wr ~= make_header(ast, data_block_size);

        write_code_section(wr, ast);
        write_data_section(wr, ast);

        return wr.data;
    }

    private void write_symbol_table(ref Appender!(ubyte[]) wr, ref ProgramAst ast) {
        import std.conv;

        auto sym_table = RegaSymbolTable();

        foreach (exp; ast.exported_symbols) {
            // calculate offset of symbol
            // do this by resolving the label to an offset
            auto label_def = ast.resolve_label(exp.name);
            enforce(!label_def.isNull, format("could not resolve symbol by label %s", exp.name));            
            auto label_offset = label_def.get.offset;
            auto sym = RegaSymbol(exp.name.to!(char[]), label_offset);

            sym_table.symbols ~= sym;
        }

        // write binary symbol table
        wr ~= encode_val(sym_table.symbols.length);
        foreach (sym; sym_table.symbols) {
            wr ~= cast(ubyte[]) sym.name;
            wr ~= encode_val(sym.offset);
        }
    }

    private void write_code_section(ref Appender!(ubyte[]) wr, ref ProgramAst ast) {
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
    }

    private void write_data_section(ref Appender!(ubyte[]) wr, ref ProgramAst ast) {
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
    }

    private ubyte[] make_header(ref ProgramAst ast, ulong data_block_size) {
        auto head = RegaHeader(
                cast(ushort)(data_block_size + ast.statements.length * INSTRUCTION_SIZE));
        auto head_bin = encode_header(head);
        return head_bin;
    }

    private ulong calc_data_block_size(ref ProgramAst ast) {
        auto res = 0;
        foreach (data_block; ast.data_blocks) {
            res += data_block.data.length;
        }
        return res;
    }

    /** compile an abstract statement to a binary-encoded instruction */
    private Instruction compile_statement(ref AbstractStatement statement, ref InstructionInfo info) {
        int get_arg_val(ValueArg arg) {
            if (arg.hasValue) {
                auto imm_val = arg.peek!(ValueImm);
                enforce(imm_val, format("expected immediate value for argument %s", arg));
                return imm_val.val;
            } else {
                return 0;
            }
        }

        auto op = statement.op;
        log_put(format("compiling statement: %s", statement));
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

    private ubyte[] encode_val(T)(T val) {
        return (cast(ubyte[]) nativeToLittleEndian(val)).dup;
    }

    private ubyte[] encode_header(RegaHeader head) {
        auto wr = appender!(ubyte[]);
        wr ~= cast(ubyte[]) REGA_MAGIC; // magic
        // wr ~= cast(ubyte[]) nativeToLittleEndian(head.program_size);
        wr ~= encode_val(head.program_size);
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
