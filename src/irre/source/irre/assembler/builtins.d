module irre.assembler.builtins;

import irre.assembler.parser;
import irre.assembler.lexer;

class BuiltinMacros {
    public MacroDef MACRO_ADI;
    public MacroDef MACRO_SBI;
    public MacroDef MACRO_YEET;
    public MacroDef MACRO_CMP;
    public MacroDef MACRO_BEQ;
    public MacroDef MACRO_BNE;
    public MacroDef MACRO_BLT;
    public MacroDef MACRO_BGE;
    public MacroDef MACRO_BGT;
    public MacroDef MACRO_BLE;

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

        // - conditional stuff
        MACRO_CMP = MacroDef("cmp", [
                MacroArg(MacroArg.Type.REGISTER, "rA"),
                MacroArg(MacroArg.Type.REGISTER, "rB"),
                ], [
                SourceStatement("tcu", [Token("ad", CharType.IDENTIFIER)],
                    [Token("rA", CharType.IDENTIFIER)], [
                        Token("rB", CharType.IDENTIFIER)
                    ]),
                ]);
        MACRO_BEQ = MacroDef("beq", [MacroArg(MacroArg.Type.VALUE, "v0")],
                [
                    SourceStatement("set", [Token("at", CharType.IDENTIFIER)],
                        [Token("v0", CharType.IDENTIFIER)]),
                    SourceStatement("bve", [Token("at", CharType.IDENTIFIER)],
                        [Token("ad", CharType.IDENTIFIER)], 
                        [Token("#0", CharType.NUMERIC_CONSTANT)]),
                ]);
        MACRO_BNE = MacroDef("bne", [MacroArg(MacroArg.Type.VALUE, "v0")],
                [
                    SourceStatement("set", [Token("at", CharType.IDENTIFIER)],
                        [Token("v0", CharType.IDENTIFIER)]),
                    SourceStatement("bvn", [Token("at", CharType.IDENTIFIER)],
                        [Token("ad", CharType.IDENTIFIER)], 
                        [Token("#0", CharType.NUMERIC_CONSTANT)]),
                ]);
        MACRO_BLT = MacroDef("blt", [MacroArg(MacroArg.Type.VALUE, "v0")],
                [
                    SourceStatement("set", [Token("at", CharType.IDENTIFIER)],
                        [Token("v0", CharType.IDENTIFIER)]),
                    SourceStatement("bve", [Token("at", CharType.IDENTIFIER)],
                        [Token("ad", CharType.IDENTIFIER)], 
                        [Token("#-1", CharType.NUMERIC_CONSTANT)]),
                ]);
        MACRO_BGE = MacroDef("bge", [MacroArg(MacroArg.Type.VALUE, "v0")],
                [
                    SourceStatement("set", [Token("at", CharType.IDENTIFIER)],
                        [Token("v0", CharType.IDENTIFIER)]),
                    SourceStatement("bvn", [Token("at", CharType.IDENTIFIER)],
                        [Token("ad", CharType.IDENTIFIER)], 
                        [Token("#-1", CharType.NUMERIC_CONSTANT)]),
                ]);
        MACRO_BGT = MacroDef("bgt", [MacroArg(MacroArg.Type.VALUE, "v0")],
                [
                    SourceStatement("set", [Token("at", CharType.IDENTIFIER)],
                        [Token("v0", CharType.IDENTIFIER)]),
                    SourceStatement("bve", [Token("at", CharType.IDENTIFIER)],
                        [Token("ad", CharType.IDENTIFIER)], 
                        [Token("#1", CharType.NUMERIC_CONSTANT)]),
                ]);
        MACRO_BLE = MacroDef("ble", [MacroArg(MacroArg.Type.VALUE, "v0")],
                [
                    SourceStatement("set", [Token("at", CharType.IDENTIFIER)],
                        [Token("v0", CharType.IDENTIFIER)]),
                    SourceStatement("bvn", [Token("at", CharType.IDENTIFIER)],
                        [Token("ad", CharType.IDENTIFIER)], 
                        [Token("#1", CharType.NUMERIC_CONSTANT)]),
                ]);
    }
}
