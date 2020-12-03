module irre.assembler.builtins;

import irre.assembler.parser;
import irre.assembler.lexer;

class BuiltinMacros {
    public MacroDef MACRO_ADI;
    public MacroDef MACRO_SBI;
    public MacroDef MACRO_YEET;

    this() {
        MACRO_ADI = MacroDef("adi", [
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
        MACRO_SBI = MacroDef("sbi", [
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
        MACRO_YEET = MacroDef("yeet", [], [SourceStatement("nop")]);
    }
}
