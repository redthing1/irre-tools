module irre.assembler.builtins;

import irre.assembler.parser;
import irre.assembler.lexer;

class BuiltinMacros {
    public static MacroDef MACRO_ADI = MacroDef("adi", [
            MacroArg(MacroArg.Type.REGISTER, "rA"),
            MacroArg(MacroArg.Type.REGISTER, "rB"),
            MacroArg(MacroArg.Type.VALUE, "v0")
            ], [
            SourceStatement("set", [Token("at", CharType.IDENTIFIER)],
                [Token("v0", CharType.IDENTIFIER)]),
            SourceStatement("add", [Token("rA", CharType.IDENTIFIER)],
                [Token("rB", CharType.IDENTIFIER)], [
                    Token("at", CharType.IDENTIFIER)
                ]),
            ]);
    public static MacroDef MACRO_SBI = MacroDef("sbi", [
            MacroArg(MacroArg.Type.REGISTER, "rA"),
            MacroArg(MacroArg.Type.REGISTER, "rB"),
            MacroArg(MacroArg.Type.VALUE, "v0")
            ], [
            SourceStatement("set", [Token("at", CharType.IDENTIFIER)],
                [Token("v0", CharType.IDENTIFIER)]),
            SourceStatement("sub", [Token("rA", CharType.IDENTIFIER)],
                [Token("rB", CharType.IDENTIFIER)], [
                    Token("at", CharType.IDENTIFIER)
                ]),
            ]);
}
