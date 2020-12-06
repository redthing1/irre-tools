module irre.assembler.ast_freezer;

import std.array;
import irre.assembler.ast;
import irre.encoding.instructions;
import std.typecons;
import std.string;
import std.variant;

class AstFreezerException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

/** converts an ast with symbol references to an ast with absolute addresses */
class AstFreezer {
    private ProgramAst source_ast;
    private ProgramAst frozen_ast;

    this(ProgramAst source_ast) {
        this.source_ast = source_ast;
    }

    public ProgramAst get_frozen_ast() {
        return frozen_ast;
    }

    /** convert all value references in instructions to immediate values (compute all offsets, replacing symbols) */
    public void freeze_all_symbols() {
        auto resolved_statements = rewrite_statements_resolved(source_ast.statements);
        // create a new frozen ast
        frozen_ast = ProgramAst(resolved_statements, source_ast.data_blocks, source_ast.macros,
                source_ast.labels, source_ast.entry_point_label, source_ast.sections);
    }

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
                    (ValueRef ref_) => resolve_labelref_offset(ref_));
        }
        return ValueImm(val);
    }

    /** resolve a label */
    private LabelDef resolve_label(string name) {
        // find the label
        foreach (label; source_ast.labels) {
            if (label.name == name) {
                return label;
            }
        }
        throw new AstFreezerException(format("label could not be resolved: %s", name));
    }

    /** calculate the global offset pointed to by a label reference */
    private int resolve_labelref_offset(ValueRef label_ref) {
        auto label_def = resolve_label(label_ref.label); // get the label definition
        // calculate label offset within section
        auto local_label_offset = label_def.offset + label_ref.ref_offset;
        // get the offset of section start
        auto section_offset = get_section_offset(label_def.section);
        // global offset is [SECTION_OFFSET] + [LOCAL_OFFSET]
        return section_offset + local_label_offset;
    }

    /** get offset of start of section */
    private int get_section_offset(SectionId section) {
        int section_index = cast(int) section;
        int offset_above = 0;
        for (int i = 0; i < section_index; i++) {
            offset_above += source_ast.sections[i].length;
        }
        return offset_above;
    }
}
