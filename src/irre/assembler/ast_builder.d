module irre.assembler.ast_builder;

import std.array;
import irre.assembler.ast;
import irre.encoding.instructions;
import std.typecons;
import std.string;
import std.variant;

class AstBuilderException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

class AstBuilder {
    private ProgramAst ast;

    this() {
        // create section entries
        ast.sections ~= SectionInfo(SectionId.Code, 0);
        ast.sections ~= SectionInfo(SectionId.Data, 0);
    }

    public ProgramAst build() {
        return ast;
    }

    private SectionInfo* get_section_info(SectionId section) {
        return &ast.sections[cast(int) section];
    }

    public void push_statement(AbstractStatement statement) {
        ast.statements ~= statement;
        (*get_section_info(SectionId.Code)).length += INSTRUCTION_SIZE;
    }

    public void push_data_block(DataBlock block) {
        auto data_section_info = *get_section_info(SectionId.Data);
        block.offset = data_section_info.length;
        ast.data_blocks ~= block;
        data_section_info.length += block.data.length;
    }

    public void push_macro(MacroDef macro_def) {
        ast.macros ~= macro_def;
    }

    public void set_entry_label(string entry_label) {
        ast.entry_point_label = entry_label;
        // replace the padding instruction with a jump to entry point
        ast.statements[0] = AbstractStatement(OpCode.JMI, cast(ValueArg) ValueRef(entry_label, 0));
    }

    /** define a label */
    public void define_label(SectionId section, string name) {
        ast.labels ~= LabelDef(section, name, (*get_section_info(section)).length);
    }

    /** resolve a macro */
    public Nullable!MacroDef resolve_macro(string name) {
        // find the macro
        foreach (macro_; ast.macros) {
            if (macro_.name == name) {
                return Nullable!MacroDef(macro_);
            }
        }
        return Nullable!MacroDef.init;
    }

    private AstBuilderException ast_builder_error(string message) {
        return new AstBuilderException(format("%s", message));
    }

}
