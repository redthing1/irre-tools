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
    private bool allow_extern;

    this(ProgramAst source_ast, bool allow_extern = false) {
        this.source_ast = source_ast;
        this.allow_extern = allow_extern;
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
            auto maybe_val = arg.visit!((ValueImm imm) => Nullable!int(imm.val),
                    (ValueRef vref) => source_ast.get_label_global_offset(vref));
            if (maybe_val.isNull) {
                auto arg_as_value_ref = arg.visit!((ValueImm imm) => Nullable!ValueRef.init,
                        (ValueRef vref) => Nullable!ValueRef(vref));
                assert(!arg_as_value_ref.isNull, "arg should be either a value ref or a value imm");
                // throw new AstFreezerException(format("value arg %s could not be resolved", arg));
                throw new AstFreezerException(format("value arg %s could not be resolved. could be value ref %s",
                            arg, arg_as_value_ref));
            }
            val = maybe_val.get;
        }
        return ValueImm(val);
    }
}
