module irre.assembler.astbuilder;

import irre.assembler.ast;
import std.typecons;

class AstBuilderException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

class AstBuilder {
    private ProgramAst ast;
    private int global_offset;

    public ProgramAst build() {
        return ast;
    }

    public void push_statement(AbstractStatement statement) {
        ast.statements ~= statement;
        global_offset += INSTRUCTION_SIZE;
    }

    public void push_data_block(DataBlock block) {
        block.offset = global_offset;
        ast.data_blocks ~= block;
        global_offset += block.data.length;
    }

    public void push_macro(MacroDef macro_def) {
        ast.macros ~= macro_def;
    }

    public void set_entry_label(string entry_label) {
        ast.entry_point_label = entry_label;
    }

    public void freeze_references() {

    }

    /** convert all value references in instructions to immediate values (compute all offsets, replacing symbols) */
    private AbstractStatement[] rewrite_statements_resolved(AbstractStatement[] statements) {
        auto resolved_statements = appender!(AbstractStatement[]);
        foreach (unresolved; statements) {
            auto statement = AbstractStatement(unresolved.op);
            // resolve args
            statement.a1 = resolve_value_arg(unresolved.a1);
            statement.a2 = resolve_value_arg(unresolved.a2);
            statement.a3 = resolve_value_arg(unresolved.a3);
            resolved_statements ~= statement;
        }

        return resolved_statements.data;
    }

    /** resolve any references in this arg and convert it to an immediate */
    private ValueImm resolve_value_arg(const ValueArg arg) {
        auto val = 0;
        if (arg.hasValue) {
            val = arg.visit!((ValueImm imm) => imm.val,
                    (ValueRef ref_) => resolve_label(ref_.label).offset + ref_.offset);
        }
        return ValueImm(val);
    }

    /** define a label */
    public void define_label(string name) {
        ast.labels ~= LabelDef(name, global_offset);
    }

    /** resolve a macro */
    public Nullable!MacroDef resolve_macro(string name) {
        // find the macro
        foreach (macro_; macros) {
            if (macro_.name == name) {
                return Nullable!MacroDef(macro_);
            }
        }
        return Nullable!MacroDef.init;
    }

    /** resolve a label */
    private LabelDef resolve_label(string name) {
        // find the label
        foreach (label; labels.data) {
            if (label.name == name) {
                return label;
            }
        }
        throw ast_builder_error(format("label could not be resolved: %s", name));
    }

    private AstBuilderException ast_builder_error(string message) {
        return new AstBuilderException(format("%s", message));
    }
}
