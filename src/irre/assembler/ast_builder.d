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
        auto unresolved_statements = ast.statements;
        auto resolved_statements = rewrite_statements_resolved(unresolved_statements);
        // clear statements from ast and add new ones
        ast.statements = [];

        if (ast.entry_point_label) {
            // if an entry point is defined
            // resolve the label specified as entry
            immutable auto entry_label_def = resolve_label(ast.entry_point_label);
            immutable auto entry_addr = entry_label_def.offset;
            // replace the padding instruction with a jump to entry point
            resolved_statements[0] = AbstractStatement(OpCode.JMI, cast(ValueArg) ValueImm(entry_addr));
        }
        ast.statements ~= resolved_statements;
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
        foreach (macro_; ast.macros) {
            if (macro_.name == name) {
                return Nullable!MacroDef(macro_);
            }
        }
        return Nullable!MacroDef.init;
    }

    /** resolve a label */
    private LabelDef resolve_label(string name) {
        // find the label
        foreach (label; ast.labels) {
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
